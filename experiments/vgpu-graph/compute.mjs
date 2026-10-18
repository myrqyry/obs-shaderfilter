import {init, compute, storage} from 'vgpu/node';
import {prepareShader} from '@vgpu/wgsl/prepare';
const gpu=await init();
try {
 const buffer=storage(gpu, 16);
 buffer.write(new Float32Array([1,2,3,4]));
 const shader=compute(gpu,prepareShader(`
@group(0) @binding(0) var<storage,read_write> values: array<f32>;
@compute @workgroup_size(4)
fn cs_main(@builtin(global_invocation_id) id: vec3u) {
 if(id.x<4u){values[id.x]=values[id.x]*3.0+1.0;}
}`),{set:{values:buffer}});
 shader.dispatch(1);
 const out=[...new Float32Array(await buffer.read())];
 console.log('VGPU_NATIVE_COMPUTE_OUTPUT',JSON.stringify(out));
 if(JSON.stringify(out)!=='[4,7,10,13]')throw new Error('Compute did not transform all buffer elements');
 console.log('VGPU_NATIVE_COMPUTE_PASS=1');
} finally {gpu.dispose();}
