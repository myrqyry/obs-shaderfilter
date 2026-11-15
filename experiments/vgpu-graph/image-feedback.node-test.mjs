import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { init } from 'vgpu/node';
import { createImageFeedbackGraph } from './image-feedback.mjs';

function reference(input,w,h,previous){
  const spatial=new Uint8Array(input.length),output=new Uint8Array(input.length);
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){
    const i=(y*w+x)*4,left=(y*w+Math.max(0,x-1))*4,right=(y*w+Math.min(w-1,x+1))*4;
    for(let c=0;c<3;c++)spatial[i+c]=Math.round((input[left+c]+2*input[i+c]+input[right+c])/4);
    spatial[i+3]=input[i+3];
    for(let c=0;c<3;c++)output[i+c]=previous?Math.round(spatial[i+c]*.5+previous[i+c]*.375):spatial[i+c];
    output[i+3]=spatial[i+3];
  }
  return output;
}
function compare(actual,expected,label){
  assert.equal(actual.length,expected.length);
  let max=0;
  for(let i=0;i<actual.length;i++){
    max=Math.max(max,Math.abs(actual[i]-expected[i]));
    if(i%4===3)assert.equal(actual[i],expected[i],label+' alpha '+i);
  }
  console.log(label,'max channel error',max);
  assert.ok(max<=1,label+' max error '+max);
}
async function withGraph(fn){
  const gpu=await init();
  const errors=[],off=gpu.onError(e=>errors.push(e));
  const graph=createImageFeedbackGraph(gpu);
  try{
    console.log('Adapter:',gpu.adapter);
    await fn(graph);
    await gpu.settled();
    assert.deepEqual(errors,[]);
  }finally{graph.dispose();off();gpu.dispose()}
}
const fixture=(w,h,shift=0)=>Uint8Array.from({length:w*h*4},(_,i)=>(i*19+Math.floor(i/4/w)*31+shift)%256);
const pixels=out=>out.color.read({mipLevel:0,region:'all'});

test('odd-width RGBA, temporal recurrence, reset and resize',()=>withGraph(async graph=>{
  const a=fixture(17,9),b=fixture(17,9,47);
  const first=await pixels(await graph.render(a,17,9));
  compare(first,reference(a,17,9), 'seed');
  const second=await pixels(await graph.render(b,17,9));
  compare(second,reference(b,17,9,first),'feedback');
  assert.ok(second.some((v,i)=>i%4!==3&&Math.abs(v-reference(b,17,9)[i])>1),'feedback is visible');
  graph.reset();
  const reset=await pixels(await graph.render(b,17,9));
  compare(reset,reference(b,17,9),'explicit reset');
  const c=fixture(9,17,91);
  compare(await pixels(await graph.render(c,9,17)),reference(c,9,17),'resize seed');
  compare(await pixels(await graph.render(a,17,9)),reference(a,17,9),'return to original size');
  const next=graph.render(b,17,9);
  await assert.rejects(graph.render(a,17,9),/in progress/);
  assert.throws(()=>graph.reset(),/in progress/);
  const committed=await pixels(await next);
  compare(committed,reference(b,17,9,first),'overlap does not corrupt history');
  await assert.rejects(graph.render(new Uint8Array(3),17,9),/RGBA/);
  const after=await pixels(await graph.render(a,17,9));
  compare(after,reference(a,17,9,committed),'invalid upload preserves history');
}));

test('real tracked PNG, all pixels compared',()=>withGraph(async graph=>{
  const image=fileURLToPath(new URL('../../data/textures/giraffe.png',import.meta.url));
  const input=execFileSync('convert',[image,'-alpha','on','-depth','8','rgba:-']);
  const w=306,h=322;
  assert.equal(input.length,w*h*4);
  const first=await pixels(await graph.render(input,w,h));
  compare(first,reference(input,w,h),'real image spatial');
  const second=await pixels(await graph.render(input,w,h));
  compare(second,reference(input,w,h,first),'real image feedback');
  assert.ok(second.some((v,i)=>i%4!==3&&Math.abs(v-first[i])>1));
  graph.dispose();
  await assert.rejects(graph.render(input,w,h),/disposed/);
}));
