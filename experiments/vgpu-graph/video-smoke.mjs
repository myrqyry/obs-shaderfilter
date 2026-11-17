import assert from 'node:assert/strict';
import { mkdtemp, rm, readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import os from 'node:os';
import { execFileSync } from 'node:child_process';
import puppeteer from 'puppeteer-core';
import { preview } from 'vite';

const dir=await mkdtemp(join(os.tmpdir(),'vgpu-video-'));
const clip=join(dir,'test.webm');
const inputMode=process.env.VIDEO_INPUT||'copy';
const depth=Number(process.env.VIDEO_QUEUE||1);
const fused=process.env.VIDEO_FUSED==='1';
assert.ok([1,2,3].includes(depth));
assert.ok(['copy','external'].includes(inputMode));
let server,browser;
try{
  execFileSync('ffmpeg',['-v','error','-f','lavfi','-i','color=red:s=1920x1080:r=30:d=4','-f','lavfi','-i','color=blue:s=1920x1080:r=30:d=2','-filter_complex','[0:v][1:v]concat=n=2:v=1:a=0','-c:v','libvpx-vp9','-deadline','realtime','-cpu-used','8','-threads','4','-y',clip]);
  server=await preview({preview:{host:'127.0.0.1',port:0,strictPort:true}});
  browser=await puppeteer.launch({executablePath:process.env.BROWSER_BIN||'/usr/bin/google-chrome-beta',headless:false,args:['--no-sandbox','--disable-dev-shm-usage','--enable-unsafe-webgpu','--use-angle=vulkan','--enable-features=Vulkan']});
  const page=await browser.newPage(),errors=[],external=[];
  await page.setViewport({width:1000,height:800});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
  page.on('response',r=>{if(r.status()>=400)errors.push(r.status()+' '+r.url())});
  page.on('request',r=>{if(!/^(http:\/\/127\.0\.0\.1:|blob:|data:)/.test(r.url()))external.push(r.url())});
  await page.evaluateOnNewDocument(()=>{
    window.receipts={copies:0,imports:0,readbacks:0,pixels:0,fences:0,passes:0,submits:0};
    const begin=GPUCommandEncoder.prototype.beginRenderPass;
    GPUCommandEncoder.prototype.beginRenderPass=function(...args){window.receipts.passes++;return begin.apply(this,args)};
    const submit=GPUQueue.prototype.submit;
    GPUQueue.prototype.submit=function(...args){window.receipts.submits++;return submit.apply(this,args)};
    const nativeImport=GPUDevice.prototype.importExternalTexture;
    GPUDevice.prototype.importExternalTexture=function(options){
      if(options.source instanceof HTMLVideoElement)window.receipts.imports++;
      return nativeImport.call(this,options);
    };
    const copy=GPUQueue.prototype.copyExternalImageToTexture;
    GPUQueue.prototype.copyExternalImageToTexture=function(src,...args){
      if(src.source instanceof HTMLVideoElement||src.source instanceof VideoFrame)window.receipts.copies++;
      return copy.call(this,src,...args);
    };
    const fence=GPUQueue.prototype.onSubmittedWorkDone;
    GPUQueue.prototype.onSubmittedWorkDone=function(...args){window.receipts.fences++;return fence.apply(this,args)};
    const read=GPUBuffer.prototype.mapAsync;
    GPUBuffer.prototype.mapAsync=function(mode,...args){
      if(mode===GPUMapMode.READ)window.receipts.readbacks++;
      return read.call(this,mode,...args);
    };
    const get=CanvasRenderingContext2D.prototype.getImageData;
    CanvasRenderingContext2D.prototype.getImageData=function(...args){window.receipts.pixels++;return get.apply(this,args)};
    const off=OffscreenCanvasRenderingContext2D.prototype.getImageData;
    OffscreenCanvasRenderingContext2D.prototype.getImageData=function(...args){window.receipts.pixels++;return off.apply(this,args)};
  });
  const cdp=await page.createCDPSession();
  await cdp.send('Page.setDownloadBehavior',{behavior:'allow',downloadPath:dir});
  await page.goto('http://127.0.0.1:'+server.httpServer.address().port);
  assert.ok(await page.$('#video-file'),'video source input must exist');
  await page.select('#video-input',inputMode);
  if(fused){assert.ok(await page.$('#video-passes'),'fusion selector missing');await page.select('#video-passes','fused');}
  if(depth>1){assert.ok(await page.$('#video-queue'),'queue selector missing');await page.select('#video-queue',String(depth));}
  await (await page.$('#video-file')).uploadFile(clip);
  try{await page.waitForFunction(()=>Number(document.querySelector('#output').dataset.frames)>=1,{timeout:8000});}catch(e){console.log('initial failure',await page.evaluate(()=>({status:document.querySelector('#status').textContent,ready:document.querySelector('#video').readyState,error:document.querySelector('#video').error?.message,receipts:window.receipts})),errors);throw e;}
  assert.deepEqual(await page.$eval('#output',c=>[c.width,c.height]),[1920,1080]);
  await page.evaluate(()=>document.querySelector('#video').pause());
  await page.waitForFunction(()=>!document.querySelector('#export').disabled);
  const stats=await page.evaluate(async()=>{
    const v=document.querySelector('#video'),c=document.querySelector('#output');
    const start=performance.now(),n=Number(c.dataset.frames),before={...window.receipts};
    let peakPending=0;
    const observer=new MutationObserver(()=>{peakPending=Math.max(peakPending,Number(c.dataset.pending)||0)});
    observer.observe(c,{attributes:true,attributeFilter:['data-pending']});
    await v.play();
    await new Promise(r=>setTimeout(r,3000));
    v.pause();observer.disconnect();
    return {peakPending,seconds:(performance.now()-start)/1000,frames:Number(c.dataset.frames)-n,mediaTime:v.currentTime,receipts:Object.fromEntries(Object.entries(window.receipts).map(([k,v])=>[k,v-before[k]]))};
  });
  // Correctness gate, not a guaranteed frame-rate target on arbitrary hardware.
  assert.ok(stats.frames>=10,JSON.stringify(stats));
  if(depth>1)assert.equal(stats.peakPending,depth,'actual full queue required');
  assert.ok(stats.peakPending<=depth,'queue exceeded bound');
  assert.equal(stats.receipts.readbacks,0);
  assert.equal(stats.receipts.pixels,0);
  if(inputMode==='external'){assert.ok(stats.receipts.imports>=stats.frames);assert.equal(stats.receipts.copies,0);}
  else{assert.ok(stats.receipts.copies>=stats.frames);assert.equal(stats.receipts.imports,0);}
  assert.equal(await page.$eval('#output',c=>c.dataset.videoInput),inputMode);
  assert.equal(await page.$eval('#output',c=>c.dataset.effectPasses),fused?'1':'2');
  console.log('1080p '+inputMode+' '+(fused?'fused':'split')+' video playback receipt',JSON.stringify(stats));
  assert.equal(stats.receipts.passes,stats.receipts.submits*(fused?2:3),'actual encoded passes including display');
  assert.ok(stats.receipts.fences<=stats.frames+depth+1,'one graph completion fence per frame: '+JSON.stringify(stats));
  await page.waitForFunction(()=>!document.querySelector('#export').disabled);
  const old=await page.$eval('#output',c=>Number(c.dataset.frames));
  await page.evaluate(()=>{document.querySelector('#video').currentTime=5;});
  await page.waitForFunction(n=>Number(document.querySelector('#output').dataset.frames)>n&&document.querySelector('#output').dataset.history==='seed'&&!document.querySelector('#export').disabled,{timeout:20000},old);
  const save=async()=>{
    await page.click('#export');
    for(let i=0;i<100;i++){
      const png=(await readdir(dir)).find(n=>n.endsWith('.png'));
      if(png){
        const path=join(dir,png),bytes=await readFile(path);
        const rgb=execFileSync('convert',[path,'-crop','1x1+960+540','-depth','8','rgb:-']);
        await rm(path);
        await page.waitForFunction(()=>!document.querySelector('#export').disabled);
        return {bytes,rgb};
      }
      await new Promise(r=>setTimeout(r,100));
    }
    throw Error('PNG export missing');
  };
  const seeded=await save(),rgb=seeded.rgb;
  // The decoded YUV video need not map to ideal [0,0,255]. A red
  // history leak would be visible in R; compare with a clean seed too.
  assert.ok(rgb[2]>=240&&rgb[0]<=8&&rgb[1]<=24,'seek must seed blue without red history: '+[...rgb]);
  await page.click('#reset');
  await page.waitForFunction(()=>document.querySelector('#status').textContent.endsWith('frame 1')&&!document.querySelector('#export').disabled);
  assert.deepEqual((await save()).bytes,seeded.bytes,'seek and explicit reset must export identical pixels');
  const stopped=await page.$eval('#output',c=>c.dataset.frames);
  await new Promise(r=>setTimeout(r,250));
  assert.equal(await page.$eval('#output',c=>c.dataset.frames),stopped,'paused video must not keep advancing');
  if(depth>1){
    const redStart=await page.$eval('#output',c=>Number(c.dataset.frames));
    await page.evaluate(()=>{document.querySelector('#video').currentTime=1});
    await page.waitForFunction(n=>Number(document.querySelector('#output').dataset.frames)>n&&document.querySelector('#output').dataset.history==='seed'&&!document.querySelector('#export').disabled,{timeout:20000},redStart);
    const interrupted=await page.evaluate(async limit=>{
      const v=document.querySelector('#video'),c=document.querySelector('#output');
      let observer,timeout;
      try{
        return await new Promise((resolve,reject)=>{
          timeout=setTimeout(()=>reject(Error('No full queue for seek stress')),5000);
          observer=new MutationObserver(()=>{
            if(Number(c.dataset.pending)!==limit)return;
            const frames=Number(c.dataset.frames);
            const pending=Number(c.dataset.pending);
            v.pause();v.currentTime=4.3;v.currentTime=5;
            resolve({frames,pending});
          });
          observer.observe(c,{attributes:true,attributeFilter:['data-pending']});
          void v.play().catch(reject);
        });
      }finally{clearTimeout(timeout);observer?.disconnect();}
    },depth);
    assert.equal(interrupted.pending,depth);
    await page.waitForFunction(n=>Number(document.querySelector('#output').dataset.frames)>n&&document.querySelector('#output').dataset.history==='seed'&&document.querySelector('#output').dataset.pending==='0'&&!document.querySelector('#export').disabled,{timeout:20000},interrupted.frames);
    assert.deepEqual((await save()).bytes,seeded.bytes,'rapid seek with full queue must not publish stale history');
    console.log('PASS rapid paused seek at full queue',interrupted);
  }
  assert.deepEqual(errors,[]);
  assert.deepEqual(external,[]);
  console.log('PASS paused seek resets history and exports blue seed', [...rgb]);
}finally{
  await browser?.close();
  if(server)await new Promise((resolve,reject)=>server.httpServer.close(e=>e?reject(e):resolve()));
  await rm(dir,{recursive:true,force:true});
}
