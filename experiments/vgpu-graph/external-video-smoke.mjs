import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { join } from 'node:path';
import os from 'node:os';
import { execFileSync } from 'node:child_process';
import puppeteer from 'puppeteer-core';
import { createServer } from 'vite';

const dir=await mkdtemp(join(os.tmpdir(),'vgpu-external-'));
let server,browser;
try{
  const clip=join(dir,'pattern.webm');
  execFileSync('ffmpeg',['-v','error','-f','lavfi','-i','testsrc2=s=318x182:r=30:d=2','-c:v','libvpx-vp9','-deadline','realtime','-cpu-used','8','-threads','4','-y',clip]);
  server=await createServer({server:{host:'127.0.0.1',port:5497,strictPort:false},logLevel:'error'});
  await server.listen();
  browser=await puppeteer.launch({executablePath:process.env.BROWSER_BIN||'/usr/bin/google-chrome-beta',headless:false,args:['--no-sandbox','--disable-dev-shm-usage','--enable-unsafe-webgpu','--use-angle=vulkan','--enable-features=Vulkan']});
  const page=await browser.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
  await page.goto('http://127.0.0.1:'+server.httpServer.address().port);
  await page.evaluate(()=>{document.body.innerHTML='<input id="fixture" type="file"><video muted playsinline controls></video>'});
  await (await page.$('#fixture')).uploadFile(clip);
  const results=await page.evaluate(async()=>{
    const {init,createExternalVideoGraph}=await import('/external-video.mjs');
    const {createImageFeedbackGraph}=await import('/image-feedback.mjs');
    const gpu=await init(),errors=[],off=gpu.onError(e=>errors.push(String(e)));
    const video=document.querySelector('video');
    video.src=URL.createObjectURL(document.querySelector('#fixture').files[0]);
    const graph=createImageFeedbackGraph(gpu);
    const external=createExternalVideoGraph(gpu);
    const fusedCopy=createImageFeedbackGraph(gpu,{fused:true});
    const fusedExternal=createImageFeedbackGraph(gpu,{videoInput:'external',fused:true});
    const receipts=[],fusion=[];
    const compare=(a,b)=>{
      let max=0,alpha=0;
      for(let n=0;n<a.length;n++){
        const diff=Math.abs(a[n]-b[n]);max=Math.max(max,diff);
        if(n%4===3)alpha=Math.max(alpha,diff);
      }
      return {max,alpha,bytes:b.length};
    };
    try{
      await video.play();
      await new Promise((resolve,reject)=>video.requestVideoFrameCallback(()=>{
        video.pause();
        // Both imports must happen in the callback task, before awaiting
        // either completion; the native external texture is task-scoped.
        const copy=graph.renderVideo(video);
        // Separate graphs share the device; finish the copy before trying
        // the external input in a later presented frame.
        copy.then(async out=>{
          const data=await out.color.read({mipLevel:0,region:'all'});
          receipts.push({copyBytes:data.length});
          resolve();
        },reject);
      }));
      graph.reset();
      // Compare three successive feedback outputs of the same paused
      // decoded frame, in separate GPU scopes.
      for(let i=0;i<3;i++){
        const copy=await graph.renderVideo(video);
        const a=await copy.color.read({mipLevel:0,region:'all'});
        const b=await (await external.renderVideo(video)).color.read({mipLevel:0,region:'all'});
        // Reset before comparison of independent inputs on first iteration.
        let max=0,sum=0;
        for(let n=0;n<a.length;n++){const d=Math.abs(a[n]-b[n]);max=Math.max(max,d);sum+=d;}
        receipts.push({max,mean:sum/a.length,bytes:b.length});
        const c=await (await fusedCopy.renderVideo(video)).color.read({mipLevel:0,region:'all'});
        const d=await (await fusedExternal.renderVideo(video)).color.read({mipLevel:0,region:'all'});
        fusion.push({copy:compare(a,c),external:compare(b,d)});
      }
      let rejected=false;
      try{await external.renderVideo(video,()=>{throw Error('injected presentation failure')});}
      catch(e){if(e.message!=='injected presentation failure')throw e;rejected=true;}
      const a=await (await graph.renderVideo(video)).color.read({mipLevel:0,region:'all'});
      const b=await (await external.renderVideo(video)).color.read({mipLevel:0,region:'all'});
      let max=0;for(let n=0;n<a.length;n++)max=Math.max(max,Math.abs(a[n]-b[n]));
      let fusedRejected=false;
      try{await fusedExternal.renderVideo(video,()=>{throw Error('injected fused presentation failure')});}
      catch(e){if(e.message!=='injected fused presentation failure')throw e;fusedRejected=true;}
      const c=await (await fusedCopy.renderVideo(video)).color.read({mipLevel:0,region:'all'});
      const d=await (await fusedExternal.renderVideo(video)).color.read({mipLevel:0,region:'all'});
      fusion.push({copy:compare(a,c),external:compare(b,d)});
      return {receipts,errors,rejected,retryMax:max,fusion,fusedRejected};
    }finally{graph.dispose();external.dispose();fusedCopy.dispose();fusedExternal.dispose();off();gpu.dispose();URL.revokeObjectURL(video.src);}
  });
  console.log(JSON.stringify(results));
  assert.deepEqual(errors,[]);
  assert.deepEqual(results.errors,[]);
  assert.ok(results.receipts.slice(1).every(r=>r.bytes===318*182*4&&r.max<=1),JSON.stringify(results));
  assert.equal(results.rejected,true);
  assert.equal(results.fusedRejected,true);
  assert.equal(results.fusion.length,4);
  for(const row of results.fusion)for(const r of [row.copy,row.external]){
    assert.equal(r.bytes,318*182*4);
    assert.equal(r.alpha,0);
    assert.ok(r.max<=1,JSON.stringify(r));
  }
  assert.ok(results.retryMax<=1,'failed frame must not advance history');
}finally{await browser?.close();await server?.close();await rm(dir,{recursive:true,force:true})}
