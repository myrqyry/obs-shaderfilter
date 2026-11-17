import { init, effect, frame, surface, timer } from 'vgpu';
import { prepareShader } from '@vgpu/wgsl/prepare';
import { createImageFeedbackGraph } from './image-feedback.mjs';

const input=document.querySelector('#image'),videoFile=document.querySelector('#video-file');
const videoInput=document.querySelector('#video-input'),videoQueue=document.querySelector('#video-queue'),videoPasses=document.querySelector('#video-passes');
const video=document.querySelector('#video'),canvas=document.querySelector('#output'),status=document.querySelector('#status');
const step=document.querySelector('#step'),reset=document.querySelector('#reset'),download=document.querySelector('#export');
const profiling=new URLSearchParams(location.search).get('profile')==='1';
let passTimer;
let gpu,graph,videoGraph,screen,present,image,output,mode='image',videoUrl,ticks=0,total=0,busy=false,failed=false;
let callback=null,needsSeed=true,needsFrame=false,epoch=0,inFlight=0,sourceSize='',pausedSeek=false,fallbackEpoch=null;
const displayShader=prepareShader(`
@group(0) @binding(0) var source: texture_2d<f32>;
@fragment fn fs_main(@builtin(position) pixel: vec4f) -> @location(0) vec4f {
  let rgba=textureLoad(source,vec2i(pixel.xy),0);
  return vec4f(rgba.rgb*rgba.a,rgba.a);
}`);
function controls(){
  input.disabled=videoFile.disabled=videoInput.disabled=videoQueue.disabled=videoPasses.disabled=busy||inFlight>0||failed;
  const playing=mode==='video'&&!video.paused&&!video.ended;
  step.disabled=busy||inFlight>0||failed||!output||mode==='video';
  reset.disabled=download.disabled=busy||inFlight>0||failed||!output||playing||video.seeking;
}
async function initialize(){
  if(gpu)return;
  if(!navigator.gpu)throw Error('WebGPU unavailable in this browser');
  gpu=await init(profiling?{requiredFeatures:['timestamp-query']}:undefined);
  if(profiling){
    passTimer=timer(gpu);
    passTimer.onResults(spans=>canvas.dispatchEvent(new CustomEvent('vgpu-timing',{detail:spans})));
    canvas.dataset.profiling='enabled';
    canvas.dataset.adapter=JSON.stringify({vendor:gpu.gpu.adapterInfo?.vendor,architecture:gpu.gpu.adapterInfo?.architecture});
  }
  graph=createImageFeedbackGraph(gpu);
  screen=surface(gpu,canvas,{size:[1,1],autoResize:false,alphaMode:'premultiplied',dpr:1});
  present=effect(gpu,displayShader);
  gpu.onError(error=>fail(error));
  gpu.lost.then(()=>fail('GPU device lost. Reload to retry.'));
}
function fail(error){failed=true;video.pause();cancel();status.textContent=String(error);controls()}
function cancel(){
  if(callback!==null){video.cancelVideoFrameCallback(callback);callback=null;}
}
function clearVideo(){
  cancel();video.pause();video.removeAttribute('src');video.load();video.hidden=true;
  if(videoUrl)URL.revokeObjectURL(videoUrl);
  videoGraph?.dispose();videoGraph=undefined;
  videoUrl=undefined;epoch++;needsFrame=false;needsSeed=true;sourceSize='';pausedSeek=false;mode='image';
}
function invalidate(){epoch++;needsSeed=true;needsFrame=true;output=null;cancel();controls()}
function submitVideo(){
  if(mode!=='video'||failed||busy||video.seeking||video.readyState<2||inFlight>=videoGraph.maxInFlight)return;
  const dimensions=video.videoWidth+'x'+video.videoHeight;
  if(video.videoWidth>2048||video.videoHeight>2048){
    invalidate();needsFrame=false;video.pause();status.textContent='Video exceeds 2048 × 2048';return;
  }
  if(sourceSize!==dimensions){if(inFlight){invalidate();return;}sourceSize=dimensions;needsSeed=true;}
  if(needsSeed&&inFlight)return;
  needsFrame=false;pausedSeek=false;
  const e=epoch;
  inFlight++;canvas.dataset.pending=String(inFlight);controls();
  void paint(needsSeed).catch(error=>{
    if(e===epoch){invalidate();needsFrame=false;video.pause();status.textContent=String(error);}
  }).finally(()=>{
    inFlight--;canvas.dataset.pending=String(inFlight);controls();schedule();
  });
  schedule();
}
function schedule(){
  if(mode!=='video'||!videoGraph||failed||busy||inFlight>=videoGraph.maxInFlight||(needsSeed&&inFlight))return;
  if(!needsFrame&&(video.paused||video.ended))return;
  if(callback===null)callback=video.requestVideoFrameCallback(()=>{
    callback=null;
    if(video.seeking||video.readyState<2){schedule();return;}
    submitVideo();
  });
  if(pausedSeek&&needsFrame&&!inFlight&&video.paused&&!video.seeking&&video.readyState>=2&&fallbackEpoch!==epoch){
    const e=epoch;fallbackEpoch=e;
    requestAnimationFrame(()=>requestAnimationFrame(()=>{
      if(fallbackEpoch===e)fallbackEpoch=null;
      if(mode==='video'&&epoch===e&&pausedSeek&&needsFrame&&!busy&&!inFlight&&!video.seeking&&video.paused){
        cancel();submitVideo();
      }
    }));
  }
}
async function paint(reseed=false){
  const currentEpoch=epoch;
  const active=mode==='video'?videoGraph:graph;
  if(reseed){active.reset();ticks=0;needsSeed=false;}
  output=null;
  const isVideo=mode==='video';
  if(isVideo)screen.resize([video.videoWidth,video.videoHeight]);
  const next=isVideo?await active.renderVideo(video,(f,target)=>{
    present.set({source:target});
    f.pass({target:screen,timer:passTimer?.span("display")},present);
  }):await graph.render(image.data,image.w,image.h);
  if(currentEpoch!==epoch)return;
  const [w,h]=next.size;
  if(!isVideo){
    screen.resize([w,h]);present.set({source:next});
    await frame(gpu,f=>f.pass({target:screen},present)).done;
  }
  if(failed)throw Error('GPU rendering failed');
  if(currentEpoch!==epoch)return;
  output=next;ticks++;total++;
  canvas.dataset.frames=String(total);
  canvas.dataset.history=reseed?'seed':'feedback';
  canvas.dataset.videoInput=isVideo?videoGraph.videoInput:'image';
  canvas.dataset.effectPasses=String(active.passCount);
  status.textContent=`${w} × ${h} · WebGPU${isVideo?' · '+videoGraph.videoInput:''} · frame ${ticks}`;
}
async function perform(action){
  if(busy||inFlight||failed)return;
  busy=true;controls();
  try{await action()}catch(error){
    if(mode==='video'){video.pause();needsFrame=false;needsSeed=true;}
    status.textContent=String(error);
  }finally{busy=false;controls();schedule()}
}
async function ensureGPU(){try{await initialize()}catch(error){fail(error);throw error}}
input.addEventListener('change',()=>perform(async()=>{
  const file=input.files?.[0];if(!file)return;
  const bitmap=await createImageBitmap(file);
  try{
    if(bitmap.width>2048||bitmap.height>2048)throw Error('Image exceeds 2048 × 2048');
    const scratch=new OffscreenCanvas(bitmap.width,bitmap.height),ctx=scratch.getContext('2d');
    ctx.drawImage(bitmap,0,0);
    const raw=ctx.getImageData(0,0,bitmap.width,bitmap.height);
    await ensureGPU();clearVideo();
    image={w:raw.width,h:raw.height,data:new Uint8Array(raw.data.buffer,raw.data.byteOffset,raw.data.byteLength)};
    await paint(true);
  }finally{bitmap.close()}
}));
videoFile.addEventListener('change',()=>perform(async()=>{
  const file=videoFile.files?.[0];if(!file)return;
  if(typeof video.requestVideoFrameCallback!=='function')throw Error('Decoded video frame callbacks unavailable');
  await ensureGPU();clearVideo();
  videoGraph=createImageFeedbackGraph(gpu,{videoInput:videoInput.value,maxInFlight:Number(videoQueue.value),fused:videoPasses.value==="fused",passTimer});
  mode='video';invalidate();
  videoUrl=URL.createObjectURL(file);video.src=videoUrl;video.hidden=false;video.load();
  status.textContent='Loading local video…';
}));
video.addEventListener('loadeddata',()=>{
  if(mode==='video'){schedule();void video.play().catch(error=>{status.textContent='Press play to begin: '+String(error)})}
});
video.addEventListener('play',()=>{controls();schedule()});
video.addEventListener('pause',()=>{cancel();controls();if(needsFrame)schedule()});
video.addEventListener('ended',()=>{cancel();controls()});
video.addEventListener('seeking',()=>{if(mode==='video'){pausedSeek=false;invalidate();schedule()}});
video.addEventListener('seeked',()=>{if(mode==='video'){pausedSeek=true;schedule()}});
video.addEventListener('error',()=>{if(mode==='video'){invalidate();needsFrame=false;video.pause();status.textContent='Could not decode local video';controls()}});
step.addEventListener('click',()=>perform(()=>paint()));
reset.addEventListener('click',()=>perform(()=>paint(true)));
download.addEventListener('click',()=>perform(async()=>{
  const [w,h]=output.size;
  const raw=await output.color.read({mipLevel:0,region:'all'});
  const scratch=new OffscreenCanvas(w,h);
  scratch.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(raw),w,h),0,0);
  const blob=await scratch.convertToBlob({type:'image/png'});
  const url=URL.createObjectURL(blob),link=document.createElement('a');
  link.href=url;link.download='vgpu-feedback.png';link.click();
  setTimeout(()=>URL.revokeObjectURL(url),1000);
}));
