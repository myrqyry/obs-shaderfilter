import { effect, frame, pingPong, target, texture } from 'vgpu';
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
// Render returns a borrowed output target, valid until a later render,
// resize or dispose. Read it before issuing another render if needed.
export function createImageFeedbackGraph(gpu){
  const spatial=effect(gpu,spatialShader,{label:'image.spatial'});
  const seed=effect(gpu,seedShader,{label:'image.seed'});
  const feedback=effect(gpu,feedbackShader,{label:'image.feedback'});
  let resources,hasHistory=false,busy=false,disposed=false;
  function release(r){
    if(!r)return;
    r.input?.destroy();
    r.spatial?.destroy();
    r.history?.read.destroy();
    r.history?.write.destroy();
  }
  function checkIdle(){
    if(disposed)throw Error('Image graph disposed');
    if(busy)throw Error('Image render already in progress');
  }
  function size(w,h){
    if(resources?.w===w&&resources?.h===h)return;
    const next={w,h};
    try{
      next.input=texture(gpu,{kind:'2d',size:[w,h],format:'rgba8unorm',usage:['copy_dst','texture_binding'],label:'image.upload'});
      next.spatial=target(gpu,{size:[w,h],format:'rgba8unorm',label:'image.spatial'});
      next.history=pingPong(gpu,w,h,{format:'rgba8unorm',label:'image.history'});
    }catch(e){release(next);throw e;}
    const old=resources;
    resources=next;hasHistory=false;
    release(old);
  }
  return {
    async render(rgba,w,h){
      checkIdle();
      if(!Number.isSafeInteger(w)||!Number.isSafeInteger(h)||w<1||h<1||
         w>gpu.gpu.limits.maxTextureDimension2D||h>gpu.gpu.limits.maxTextureDimension2D||
         !(rgba instanceof Uint8Array)||rgba.byteLength!==w*h*4)
        throw new RangeError('Invalid RGBA image dimensions or length');
      busy=true;
      const errors=[],unsubscribe=gpu.onError(e=>errors.push(e));
      const device=gpu.gpu;
      device.pushErrorScope('validation');
      let failure;
      try{
        size(w,h);
        const r=resources;
        device.queue.writeTexture({texture:r.input.gpu},rgba,{bytesPerRow:w*4},[w,h]);
        spatial.set({source:r.input});
        const pass=hasHistory?feedback:seed;
        pass.set(hasHistory?{source:r.spatial,previous:r.history.read}:{source:r.spatial});
        const submitted=frame(gpu,f=>{
          f.pass({target:r.spatial},spatial);
          f.pass({target:r.history.write},pass);
        });
        await submitted.done;
        await gpu.settled();
      }catch(e){failure=e;}
      finally{
        try{
          const validation=await device.popErrorScope();
          if(validation&&!failure)failure=Error(validation.message);
        }finally{unsubscribe();busy=false;}
      }
      if(failure)throw failure;
      if(errors.length)throw errors[0];
      resources.history.swap();
      hasHistory=true;
      return resources.history.read;
    },
    reset(){checkIdle();hasHistory=false;},
    dispose(){
      if(disposed)return;
      checkIdle();
      disposed=true;
      spatial.dispose();seed.dispose();feedback.dispose();
      release(resources);resources=undefined;
    },
  };
}
