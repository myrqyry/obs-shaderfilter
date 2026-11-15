import { draw, effect, frame, pingPong, target, texture } from 'vgpu';
import { prepareShader } from '@vgpu/wgsl/prepare';

const spatialShader=prepareShader(`
@group(0) @binding(0) var source: texture_2d<f32>;
@fragment fn fs_main(@builtin(position) pixel: vec4f) -> @location(0) vec4f {
  let p=vec2i(pixel.xy);
  let hi=vec2i(textureDimensions(source))-vec2i(1);
  let center=textureLoad(source,p,0);
  let left=textureLoad(source,max(p-vec2i(1,0),vec2i(0)),0);
  let right=textureLoad(source,min(p+vec2i(1,0),hi),0);
  return vec4f((left.rgb+2.0*center.rgb+right.rgb)*0.25,center.a);
}`);
const externalSpatialShader=prepareShader(`
@group(0) @binding(0) var source: texture_external;
@vertex fn vs_main(@builtin(vertex_index) i:u32) -> @builtin(position) vec4f {
  return vec4f(array<vec2f,3>(vec2f(-1,-1),vec2f(3,-1),vec2f(-1,3))[i],0,1);
}
@fragment fn fs_main(@builtin(position) pixel: vec4f) -> @location(0) vec4f {
  let p=vec2i(pixel.xy);
  let hi=vec2i(textureDimensions(source))-vec2i(1);
  let center=textureLoad(source,p);
  let left=textureLoad(source,max(p-vec2i(1,0),vec2i(0)));
  let right=textureLoad(source,min(p+vec2i(1,0),hi));
  // Preserve the RGBA8 conversion boundary of the copy-based path.
  let c=round(clamp(center,vec4f(0),vec4f(1))*255.0)/255.0;
  let l=round(clamp(left,vec4f(0),vec4f(1))*255.0)/255.0;
  let r=round(clamp(right,vec4f(0),vec4f(1))*255.0)/255.0;
  return vec4f((l.rgb+2.0*c.rgb+r.rgb)*0.25,c.a);
}`);
const seedShader=prepareShader(`
@group(0) @binding(0) var source: texture_2d<f32>;
@fragment fn fs_main(@builtin(position) pixel: vec4f) -> @location(0) vec4f {
  return textureLoad(source,vec2i(pixel.xy),0);
}`);
const feedbackShader=prepareShader(`
@group(0) @binding(0) var source: texture_2d<f32>;
@group(0) @binding(1) var previous: texture_2d<f32>;
@fragment fn fs_main(@builtin(position) pixel: vec4f) -> @location(0) vec4f {
  let p=vec2i(pixel.xy);
  let current=textureLoad(source,p,0);
  let old=textureLoad(previous,p,0);
  return vec4f(current.rgb*0.5+old.rgb*0.375,current.a);
}`);

// Owns its image/targets/effects, but borrows the caller's GPU.
// Render returns a borrowed output target. With pipelining, drain the
// queue and consume the latest output before any new render/reset/resize/
// dispose; earlier receipts can refer to a reused ping-pong texture.
export function createImageFeedbackGraph(gpu,{videoInput="copy",maxInFlight=1}={}){
  if(videoInput!=="copy"&&videoInput!=="external")throw Error("Invalid video input mode");
  if(maxInFlight!==1&&maxInFlight!==2)throw RangeError("maxInFlight must be 1 or 2");
  const external=videoInput==="external"?draw(gpu,{shader:externalSpatialShader,label:"video.external-spatial"}):null;
  const spatial=effect(gpu,spatialShader,{label:'image.spatial'});
  const seed=effect(gpu,seedShader,{label:'image.seed'});
  const feedback=effect(gpu,feedbackShader,{label:'image.feedback'});
  let resources,hasHistory=false,pending=0,disposed=false,poisoned=false,tail=Promise.resolve();
  function release(r){
    if(!r)return;
    r.input?.destroy();
    r.spatial?.destroy();
    r.history?.read.destroy();
    r.history?.write.destroy();
  }
  function checkIdle(){
    if(disposed)throw Error('Image graph disposed');
    if(pending)throw Error('Image render already in progress');
  }
  function size(w,h){
    if(resources?.w===w&&resources?.h===h)return;
    const next={w,h};
    try{
      if(!external)next.input=texture(gpu,{kind:'2d',size:[w,h],format:'rgba8unorm',usage:['copy_dst','texture_binding','render_attachment'],label:'image.upload'});
      next.spatial=target(gpu,{size:[w,h],format:'rgba8unorm',label:'image.spatial'});
      next.history=pingPong(gpu,w,h,{format:'rgba8unorm',label:'image.history'});
    }catch(e){release(next);throw e;}
    const old=resources;
    resources=next;hasHistory=false;
    release(old);
  }
  async function renderFrame(w,h,upload,presentOutput,video){
      if(disposed)throw Error('Image graph disposed');
      if(poisoned)throw Error('Image history invalid; drain and reset required');
      if(pending>=maxInFlight)throw Error('Image render capacity reached; work in progress');
      if(pending&&(resources?.w!==w||resources?.h!==h))throw Error('Resize while image render in progress');
      if(!Number.isSafeInteger(w)||!Number.isSafeInteger(h)||w<1||h<1||
         w>gpu.gpu.limits.maxTextureDimension2D||h>gpu.gpu.limits.maxTextureDimension2D)
        throw new RangeError('Invalid RGBA image dimensions');
      pending++;
      const errors=[],unsubscribe=gpu.onError(e=>errors.push(e));
      const device=gpu.gpu;
      try {
        device.pushErrorScope('validation');
        let submitted, failure, result;
        try {
          size(w,h);
          const r=resources;
          if(video&&external){
            const native=device.importExternalTexture({source:video});
            external.group(0,device.createBindGroup({layout:external.layout(0),entries:[{binding:0,resource:native}]}));
          }else{
            upload(device.queue,r.input.gpu);
            spatial.set({source:r.input});
          }
          const pass=hasHistory?feedback:seed;
          pass.set(hasHistory?{source:r.spatial,previous:r.history.read}:{source:r.spatial});
          submitted=frame(gpu,f=>{
            f.pass({target:r.spatial},video&&external?external:spatial);
            f.pass({target:r.history.write},pass);
            presentOutput?.(f,r.history.write);
          });
          result=r.history.write;
          // Queue order protects input, spatial and alternating history
          // textures. Speculative history is encoded in submission order.
          // The result is not published until ordered validation completes.
          r.history.swap();
          hasHistory=true;
        }catch(e){failure=e;}
        // vGPU 0.6.0 frame.done already includes a queue fence and
        // claimed-bind-group validation delivery. Pop our scope now and
        // await both; a second global gpu.settled() would fence again.
        const validation=Promise.allSettled([device.popErrorScope(),submitted?.done]);
        const previous=tail;
        const receipt=previous.then(async()=>{
          const [scope,completion]=await validation;
          if(failure)throw failure;
          const problem=scope.status==='rejected'?scope.reason:
            completion.status==='rejected'?completion.reason:
            scope.value?Error(scope.value.message):errors[0];
          if(problem){poisoned=true;throw problem;}
          if(poisoned)throw Error('Image history invalid; drain and reset required');
          return result;
        });
        tail=receipt.then(()=>undefined,()=>undefined);
        return await receipt;
      }finally{unsubscribe();pending--;}
  }
  return {
    videoInput,maxInFlight,
    get pending(){return pending;},
    async render(rgba,w,h){
      if(external)throw Error("External video graph requires a video source");
      if(!(rgba instanceof Uint8Array)||rgba.byteLength!==w*h*4)
        throw new RangeError('Invalid RGBA image length');
      return renderFrame(w,h,(queue,destination)=>queue.writeTexture({texture:destination},rgba,{bytesPerRow:w*4},[w,h]));
    },
    async renderVideo(video,presentOutput){
      if(typeof HTMLVideoElement==='undefined'||!(video instanceof HTMLVideoElement)||video.readyState<2||video.seeking)
        throw Error('Video frame unavailable');
      const w=video.videoWidth,h=video.videoHeight;
      return renderFrame(w,h,(queue,destination)=>queue.copyExternalImageToTexture({source:video},{texture:destination,premultipliedAlpha:false},[w,h]),presentOutput,video);
    },
    reset(){checkIdle();hasHistory=false;poisoned=false;},
    dispose(){
      if(disposed)return;
      checkIdle();
      disposed=true;
      external?.dispose();spatial.dispose();seed.dispose();feedback.dispose();
      release(resources);resources=undefined;
    },
  };
}
