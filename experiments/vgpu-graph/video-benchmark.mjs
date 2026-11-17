import assert from 'node:assert/strict';
import {mkdtemp,rm} from 'node:fs/promises';
import {join} from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import puppeteer from 'puppeteer-core';
import {preview} from 'vite';

const seconds=Number(process.env.BENCH_SECONDS||12);
assert.ok(Number.isInteger(seconds)&&seconds>=8&&seconds<=60);
const dir=await mkdtemp(join(os.tmpdir(),'vgpu-bench-'));
let server,browser;
try{
  const clip=join(dir,'motion.webm');
  execFileSync('ffmpeg',['-v','error','-f','lavfi','-i','testsrc2=s=1920x1080:r=30:d='+(seconds+5),'-c:v','libvpx-vp9','-deadline','realtime','-cpu-used','8','-threads','4','-y',clip]);
  server=await preview({preview:{host:'127.0.0.1',port:0,strictPort:true}});
  browser=await puppeteer.launch({executablePath:process.env.BROWSER_BIN||'/usr/bin/google-chrome-beta',headless:false,args:['--no-sandbox','--disable-dev-shm-usage','--enable-unsafe-webgpu','--use-angle=vulkan','--enable-features=Vulkan']});
  const diagnostics=process.env.BENCH_DIAGNOSTIC==='1';
  const cases=diagnostics?[
    {input:'copy',fused:false,profile:false,depth:1},
    {input:'copy',fused:false,profile:false,depth:2},
    {input:'external',fused:false,profile:false,depth:2},
  ]:[
    {input:'copy',fused:false,profile:false},
    {input:'copy',fused:true,profile:false},
    {input:'copy',fused:false,profile:true},
    {input:'copy',fused:true,profile:true},
    {input:'external',fused:true,profile:true},
  ];
  for(const config of cases){
    const page=await browser.newPage(),errors=[],external=[];
    try{
      await page.setViewport({width:1000,height:800});
      page.on('pageerror',e=>errors.push(e.message));
      page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
      page.on('response',r=>{if(r.status()>=400)errors.push(r.status()+' '+r.url())});
      page.on('request',r=>{if(!/^(http:\/\/127\.0\.0\.1:|blob:|data:)/.test(r.url()))external.push(r.url())});
      await page.evaluateOnNewDocument(()=>{
        window.metrics=null;
        // Keep the independent observer out of the application callback counts.
        const request=HTMLVideoElement.prototype.requestVideoFrameCallback;
        window.observeSource=(video,cb)=>request.call(video,cb);
        HTMLVideoElement.prototype.requestVideoFrameCallback=function(cb){
          return request.call(this,(now,meta)=>{
            const state=window.metrics,start=performance.now();
            if(state){
              state.appPresented.push(meta.presentedFrames);
              state.stages.callbackLead.push(meta.expectedDisplayTime-start);
              state.stages.processing.push(meta.processingDuration*1000);
            }
            try{return cb(now,meta)}finally{
              if(state)state.stages.callback.push(performance.now()-start);
            }
          });
        };
        const wrap=(prototype,key,label,accept=()=>true)=>{
          const original=prototype[key];
          prototype[key]=function(...args){
            const state=window.metrics,start=performance.now();
            try{return original.apply(this,args)}
            finally{if(state&&accept(args))state.stages[label].push(performance.now()-start);}
          };
        };
        wrap(GPUQueue.prototype,'copyExternalImageToTexture','copy',args=>args[0].source instanceof HTMLVideoElement);
        wrap(GPUDevice.prototype,'importExternalTexture','import');
        wrap(GPUQueue.prototype,'submit','submit');
        wrap(GPUDevice.prototype,'createBindGroup','bindGroup');
        wrap(GPUCanvasContext.prototype,'getCurrentTexture','canvas');
        wrap(GPUCanvasContext.prototype,'configure','configure');
        const fence=GPUQueue.prototype.onSubmittedWorkDone;
        GPUQueue.prototype.onSubmittedWorkDone=function(...args){
          const state=window.metrics,start=performance.now(),result=fence.apply(this,args);
          if(state){state.submits++;result.then(()=>{if(window.metrics===state)state.fences.push(performance.now()-start)},()=>{});}
          return result;
        };
        const begin=GPUCommandEncoder.prototype.beginRenderPass;
        GPUCommandEncoder.prototype.beginRenderPass=function(...args){if(window.metrics)window.metrics.passes++;return begin.apply(this,args)};
        const map=GPUBuffer.prototype.mapAsync;
        GPUBuffer.prototype.mapAsync=function(mode,...args){if(window.metrics&&mode===GPUMapMode.READ)window.metrics.maps++;return map.call(this,mode,...args)};
      });
      await page.goto('http://127.0.0.1:'+server.httpServer.address().port+(config.profile?'/?profile=1':'/'));
      await page.select('#video-input',config.input);
      await page.select('#video-queue',String(config.depth??2));
      await page.select('#video-passes',config.fused?'fused':'split');
      await (await page.$('#video-file')).uploadFile(clip);
      await page.waitForFunction(()=>Number(document.querySelector('#output').dataset.frames)>=3,{timeout:15000});
      const result=await page.evaluate(async duration=>{
        const v=document.querySelector('#video'),c=document.querySelector('#output');
        // Warm up, then sample a continuous moving-source interval.
        await new Promise(r=>setTimeout(r,1000));
        const m={submits:0,passes:0,maps:0,fences:[],timings:[],buckets:[],appPresented:[],stages:Object.fromEntries(["callback","callbackLead","processing","copy","import","submit","bindGroup","canvas","configure"].map(n=>[n,[]]))};
        let firstPresented,lastPresented,callback,peakPending=0,sourceCallbacks=0;
        const count=(now,meta)=>{sourceCallbacks++;firstPresented??=meta.presentedFrames;lastPresented=meta.presentedFrames;callback=window.observeSource(v,count)};
        callback=window.observeSource(v,count);
        const listen=e=>m.timings.push({...e.detail});
        c.addEventListener('vgpu-timing',listen);
        const q0=v.getVideoPlaybackQuality(),n0=Number(c.dataset.frames),t0=performance.now(),media0=v.currentTime;
        let prev=n0;
        window.metrics=m;
        for(let i=0;i<duration;i++){
          await new Promise(r=>setTimeout(r,1000));
          const count=Number(c.dataset.frames);
          m.buckets.push(count-prev);prev=count;
          peakPending=Math.max(peakPending,Number(c.dataset.pending));
        }
        const elapsed=(performance.now()-t0)/1000,completed=Number(c.dataset.frames)-n0,media=v.currentTime-media0,q1=v.getVideoPlaybackQuality();
        window.metrics=null;
        v.cancelVideoFrameCallback(callback);
        c.removeEventListener('vgpu-timing',listen);
        v.pause();
        const summary=values=>{
          const sorted=[...values].sort((a,b)=>a-b);
          return sorted.length?{n:sorted.length,p50:sorted[Math.floor((sorted.length-1)*.5)],p95:sorted[Math.floor((sorted.length-1)*.95)],mean:sorted.reduce((a,b)=>a+b,0)/sorted.length}:null;
        };
        const timings=Object.fromEntries([...new Set(m.timings.flatMap(Object.keys))].map(name=>[name,summary(m.timings.map(x=>x[name]).filter(Number.isFinite))]));
        timings.total=summary(m.timings.map(x=>Object.values(x).reduce((a,b)=>a+b,0)));
        return {stages:Object.fromEntries(Object.entries(m.stages).map(([name,values])=>[name,summary(values.filter(Number.isFinite))])),sourceCallbacks,appCallbacks:m.appPresented.length,appGaps:m.appPresented.slice(1).reduce((sum,n,i)=>sum+Math.max(0,n-m.appPresented[i]-1),0),elapsed,media,completed,fps:completed/elapsed,presented:firstPresented===undefined?null:lastPresented-firstPresented+1,videoFrames:q1.totalVideoFrames-q0.totalVideoFrames,videoDroppedFrames:q1.droppedVideoFrames-q0.droppedVideoFrames,peakPending,buckets:m.buckets,submits:m.submits,passes:m.passes,maps:m.maps,fence:summary(m.fences),timings,adapter:c.dataset.adapter,profiling:c.dataset.profiling||'off'};
      },seconds);
      await page.waitForFunction(()=>document.querySelector('#output').dataset.pending==='0'&&!document.querySelector('#export').disabled,{timeout:15000});
      console.log(JSON.stringify({config,...result}));
      assert.ok(result.completed>=seconds*10);
      assert.ok(result.media>=seconds*.9);
      assert.equal(result.passes,result.submits*(config.fused?2:3));
      if(diagnostics){
        assert.ok(result.stages?.callback?.n>=result.completed-2,'missing actual application callback receipts');
        assert.ok(result.stages?.[config.input==='copy'?'copy':'import']?.n>=result.completed-2,'missing video ingest receipts');
        assert.ok(result.stages?.submit?.n>=result.completed-2,'missing native submit receipts');
        assert.ok(result.sourceCallbacks>=result.completed-2,'missing independent source observer');
      }
      if(config.profile){
        assert.equal(result.profiling,'enabled');
        assert.ok(result.timings.total?.n>=result.completed*.7,'insufficient timestamp receipts');
        assert.ok(result.timings.display?.n);
        assert.ok(result.timings[config.fused?'fused':'spatial']?.n);
      }else assert.equal(result.maps,0);
      assert.deepEqual(errors,[]);
      assert.deepEqual(external,[]);
    }finally{await page.close();}
  }
  console.log('PASS sustained video benchmark');
}finally{
  await browser?.close();
  if(server)await new Promise((resolve,reject)=>server.httpServer.close(e=>e?reject(e):resolve()));
  await rm(dir,{recursive:true,force:true});
}
