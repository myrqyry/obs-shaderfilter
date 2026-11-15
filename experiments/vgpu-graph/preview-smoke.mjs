import assert from 'node:assert/strict';
import { mkdtemp, readFile, readdir, rm } from 'node:fs/promises';
import { join } from 'node:path';
import os from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';
import { preview } from 'vite';

const dir=await mkdtemp(join(os.tmpdir(),'vgpu-preview-'));
const fixture=fileURLToPath(new URL('../../data/textures/giraffe.png',import.meta.url));
let server,browser;
try{
  server=await preview({preview:{host:'127.0.0.1',port:0,strictPort:true}});
  browser=await puppeteer.launch({
    executablePath:process.env.BROWSER_BIN||'/usr/bin/google-chrome-beta',
    headless:false,
    args:['--no-sandbox','--disable-dev-shm-usage','--enable-unsafe-webgpu','--use-angle=vulkan','--enable-features=Vulkan'],
  });
  const page=await browser.newPage(),errors=[],external=[];
  await page.setViewport({width:1000,height:800});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('response',r=>{if(r.status()>=400)errors.push(r.status()+' '+r.url())});
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
  page.on('request',r=>{if(!r.url().startsWith('http://127.0.0.1:')&&!r.url().startsWith('blob:')&&!r.url().startsWith('data:'))external.push(r.url())});
  const cdp=await page.createCDPSession();
  await cdp.send('Page.setDownloadBehavior',{behavior:'allow',downloadPath:dir});
  const port=server.httpServer.address().port;
  await page.goto('http://127.0.0.1:'+port);
  const adapter=await page.evaluate(async()=>{
    const a=await navigator.gpu.requestAdapter();
    return {vendor:a?.info.vendor,architecture:a?.info.architecture};
  });
  console.log('Browser adapter:',adapter);
  const waitFrame=t=>page.waitForFunction(n=>document.querySelector('#status').textContent.endsWith('frame '+n),{timeout:20000},t);
  const save=async(label)=>{
    await page.click('#export');
    await page.waitForFunction(()=>!document.querySelector('#export').disabled,{timeout:20000});
    for(let i=0;i<100;i++){
      const files=await readdir(dir);
      const png=files.find(n=>n.endsWith('.png'));
      if(png){
        const p=join(dir,png);
        const bytes=await readFile(p);
        const rgba=execFileSync('convert',[p,'-alpha','on','-depth','8','rgba:-']);
        assert.equal(rgba.length,306*322*4,label);
        assert.equal(bytes.subarray(1,4).toString(),'PNG');
        await rm(p);
        return rgba;
      }
      await new Promise(r=>setTimeout(r,100));
    }
    throw Error('Missing export: '+label);
  };
  await (await page.$('#image')).uploadFile(fixture);
  await waitFrame(1);
  assert.deepEqual(await page.$eval('canvas',c=>[c.width,c.height]),[306,322]);
  const before=await page.$eval('canvas',c=>c.getBoundingClientRect().width);
  assert.ok(before>100);
  const screenshot1=await (await page.$('canvas')).screenshot();
  const first=await save('seed');
  await page.click('#step');await waitFrame(2);
  const second=await save('feedback');
  const screenshot2=await (await page.$('canvas')).screenshot();
  assert.notDeepEqual(screenshot1,screenshot2,'visible canvas must change');
  assert.ok(first.some((v,i)=>i%4!==3&&Math.abs(v-second[i])>1));
  await page.click('#reset');await waitFrame(1);
  assert.deepEqual(await save('reset'),first,'reset restores first frame');
  assert.deepEqual(errors,[]);
  assert.deepEqual(external,[]);
  console.log('PASS real browser file input, GPU canvas, feedback, reset and PNG export; no external requests');
}finally{
  await browser?.close();
  if(server)await new Promise((resolve,reject)=>server.httpServer.close(e=>e?reject(e):resolve()));
  await rm(dir,{recursive:true,force:true});
}
