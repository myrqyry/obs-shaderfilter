import { init, effect, frame, pingPong, target } from 'vgpu/node';
import { prepareShader } from '@vgpu/wgsl/prepare';

const firstWGSL = `
@fragment fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  return vec4f(uv.x, uv.y, 0.25, 1.0);
}`;
const feedbackWGSL = `
@group(0) @binding(0) var previous: texture_2d<f32>;
@fragment fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let size = textureDimensions(previous);
  let xy = min(vec2u(uv * vec2f(size)), size - vec2u(1));
  let old = textureLoad(previous, vec2i(xy), 0);
  return vec4f(old.rgb * 0.7 + vec3f(0.08, 0.02, 0.0), 1.0);
}`;
const gpu = await init();
try {
  const buffers = pingPong(gpu, 64, 64, {format: 'rgba8unorm'});
  const initial = effect(gpu, prepareShader(firstWGSL), {label:'probe.gradient'});
  const accumulate = effect(gpu, prepareShader(feedbackWGSL), {label:'probe.feedback'});
  const checksums = [];
  const samples = [];
  for(let tick=0;tick<4;tick++) {
    frame(gpu, f => {
      if(tick===0)f.pass({target:buffers.write}, initial);
      else {
        accumulate.set({previous:buffers.read});
        f.pass({target:buffers.write}, accumulate);
      }
    });
    buffers.swap();
    const rgba=await buffers.read.color.read({mipLevel:0,region:'all'});
    let checksum=0; for(const b of rgba)checksum+=b;
    const off=(32*64+32)*4;
    checksums.push(checksum);
    samples.push([...rgba.slice(off,off+4)]);
    console.log(`GPU_FRAME tick=${tick} checksum=${checksum} center=${samples.at(-1).join(',')}`);
  }
  if(new Set(checksums).size!==4)throw new Error('No changing feedback frames');
  if(samples[0][3]!==255)throw new Error('Invalid alpha');
  console.log('VGPU_NATIVE_RENDER_AND_FEEDBACK_PASS=1');
  // Resize a standalone target; verify the actual new pixel size, not a mock.
  const out=target(gpu,{size:[10,12],format:'rgba8unorm'});
  out.resize([32,24]);
  frame(gpu,f=>f.pass({target:out},initial));
  const resized=await out.color.read({mipLevel:0,region:'all'});
  console.log('VGPU_RESIZE_READBACK',JSON.stringify({size:out.size,bytes:resized.length}));
  if(out.size[0]!==32 ||out.size[1]!==24 ||resized.length!==32*24*4)throw new Error('Resize mismatch');
  console.log('VGPU_RESIZE_PASS=1');
}finally{gpu.dispose();}
