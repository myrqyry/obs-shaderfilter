import { init, effect, frame, surface } from 'vgpu';
import { prepareShader } from '@vgpu/wgsl/prepare';
import { createImageFeedbackGraph } from './image-feedback.mjs';

const input=document.querySelector('#image');
const canvas=document.querySelector('#output');
const status=document.querySelector('#status');
const step=document.querySelector('#step'),reset=document.querySelector('#reset'),download=document.querySelector('#export');
let gpu, graph, screen, present, image, output, ticks=0, busy=false, failed=false;
const displayShader=prepareShader(`
@group(0) @binding(0) var source: texture_2d<f32>;
@fragment fn fs_main(@builtin(position) pixel: vec4f) -> @location(0) vec4f {
  let rgba=textureLoad(source,vec2i(pixel.xy),0);
  return vec4f(rgba.rgb*rgba.a,rgba.a);
}`);
function controls(){
  input.disabled=busy||failed;
  for(const button of [step,reset,download])button.disabled=busy||failed||!output;
}
async function initialize(){
  if(gpu)return;
  if(!navigator.gpu)throw Error('WebGPU unavailable in this browser');
  gpu=await init();
  graph=createImageFeedbackGraph(gpu);
  screen=surface(gpu,canvas,{size:[1,1],autoResize:false,alphaMode:'premultiplied',dpr:1});
  present=effect(gpu,displayShader);
  gpu.onError(error=>{failed=true;status.textContent=String(error);controls()});
  gpu.lost.then(()=>{failed=true;status.textContent='GPU device lost. Reload to retry.';controls()});
}
async function paint(reseed=false){
  if(reseed){graph.reset();ticks=0;}
  output=null;
  output=await graph.render(image.data,image.w,image.h);
  screen.resize([image.w,image.h]);
  present.set({source:output});
  await frame(gpu,f=>f.pass({target:screen},present)).done;
  if(failed)throw Error('GPU rendering failed');
  ticks++;
  status.textContent=`${image.w} × ${image.h} · WebGPU · frame ${ticks}`;
}
async function perform(action){
  if(busy||failed)return;
  busy=true;controls();
  try{await action()}catch(error){status.textContent=String(error)}
  finally{busy=false;controls()}
}
input.addEventListener('change',()=>perform(async()=>{
  const file=input.files?.[0];if(!file)return;
  const bitmap=await createImageBitmap(file);
  try{
    if(bitmap.width>2048||bitmap.height>2048)throw Error('Image exceeds 2048 × 2048');
    const scratch=new OffscreenCanvas(bitmap.width,bitmap.height);
    const ctx=scratch.getContext('2d');
    ctx.drawImage(bitmap,0,0);
    const raw=ctx.getImageData(0,0,bitmap.width,bitmap.height);
    try{await initialize()}catch(error){failed=true;throw error}
    image={w:raw.width,h:raw.height,data:new Uint8Array(raw.data.buffer,raw.data.byteOffset,raw.data.byteLength)};
    await paint(true);
  }finally{bitmap.close()}
}));
step.addEventListener('click',()=>perform(()=>paint()));
reset.addEventListener('click',()=>perform(()=>paint(true)));
download.addEventListener('click',()=>perform(async()=>{
  const raw=await output.color.read({mipLevel:0,region:'all'});
  const scratch=new OffscreenCanvas(image.w,image.h);
  scratch.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(raw),image.w,image.h),0,0);
  const blob=await scratch.convertToBlob({type:'image/png'});
  const url=URL.createObjectURL(blob),link=document.createElement('a');
  link.href=url;link.download='vgpu-feedback.png';link.click();
  setTimeout(()=>URL.revokeObjectURL(url),1000);
}));
