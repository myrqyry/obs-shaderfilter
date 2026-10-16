#!/usr/bin/env python3
"""Compile every shipped stdlib header with native libobs OpenGL.

Reproduce Shaderfilter's relative include expansion using the real source
wrapper, then compile with installed OBS (not a generic GLSL compiler).
"""
from pathlib import Path
import re
import shlex
import os
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
NATIVE_BINARY=None
SOURCE=(ROOT/'obs-shaderfilter.c').read_text()
LIB=ROOT/'data/stdlib'
HEADERS=('math', 'colors', 'noise', 'animation', 'blur', 'printmaking', 'oklab')


def template(name):
    start=f'static const char *effect_template_{name} = "'
    assert SOURCE.count(start)==1
    literal=SOURCE.split(start,1)[1].split('";',1)[0]
    return literal.replace('\\\n','').replace('\\n','\n')


def expand_includes(path,stack=()):
    # Shaderfilter resolves #include relative to the including file.
    real=path.resolve()
    if real in stack:
        raise RuntimeError('cyclic include: '+str(path))
    return expand_text(real.read_text(),real,stack)


def expand_text(text,virtual_path,stack=()):
    real=virtual_path.resolve()
    lines=[]
    for line in text.splitlines():
        match=re.match(r'^#include\s+"([^"]+)"\s*$',line)
        if match:
            target=(real.parent/match.group(1)).resolve(strict=True)
            lines.append(expand_includes(target,stack+(real,)))
        else:
            lines.append(line)
    return '\n'.join(lines)+'\n'


def compile_case(name,body,virtual_shader=None):
    with tempfile.TemporaryDirectory(prefix='shader-stdlib-') as tmp:
        root=Path(tmp)
        # Treat the synthetic shader as though it lives in data/examples:
        # this exercises the exact documented ../stdlib/... relative paths.
        if virtual_shader is None:
            virtual_shader=ROOT/'data/examples/_stdlib-smoke.shader'
        src=('#define OPENGL 1\n'+template('begin')+
             expand_text(body,virtual_shader).replace('[loop]','')+'\n'+template('end'))
        effect=root/'combined.effect';effect.write_text(src)
        result=subprocess.run([str(NATIVE_BINARY),str(effect)],text=True,capture_output=True)
        if result.returncode!=0:
            lines=(result.stdout+'\n'+result.stderr).splitlines()
            raise RuntimeError(f'{name} (exit {result.returncode}): '+ '\n'.join(lines[-20:]))
        print(f'PASS {name}',flush=True)


def checks():
    # Regression against the original cellular distance bug: compare feature
    # positions to global p, never to frac(p)+cell offsets.
    noise=(LIB/'noise.glsl').read_text()
    assert noise.count('float2 diff = cellPos - p;') == 2
    assert noise.count('float3 diff = cellPos - p;') == 1
    assert '(f + float2(x, y))' not in noise
    assert '(f + float3(x, y, z))' not in noise
    assert noise.count('i < min(max(octaves, 0), 8); i++') >= 8
    blur=(LIB/'blur.glsl').read_text()
    assert 'radius = clamp(radius, 0, 8);' in blur
    assert 'samples = clamp(samples, 1, 32);' in blur
    # Source-contract guards for the review's numerical edge cases.
    # These supplement native effect compilation; they are NOT GPU pixel tests.
    colors=(LIB/'colors.glsl').read_text()
    animation=(LIB/'animation.glsl').read_text()
    math=(LIB/'math.glsl').read_text()
    assert 'data/stdlib' in (ROOT/'CMakeLists.txt').read_text().split('install(DIRECTORY ',1)[1].split('DESTINATION',1)[0]
    assert 'if (l <= 0.0) return float3(0.0, 0.0, 0.0);' in colors
    assert 'if (l >= 1.0) return float3(1.0, 1.0, 1.0);' in colors
    assert '(l / (l - mn))' in colors and '((1.0 - l) / (mx - l))' in colors
    assert 'saturate(color) * intervals + 0.5' in colors
    assert 'animationModPositive(time, period * 2.0)' in animation
    assert 'animationModPositive(time, totalDuration)' in animation
    assert 'mod(time' not in animation
    assert 'if (lenSq <= 0.0) return length(pa);' in math
    assert 'exp(-max(speed, 0.0))' in math
    assert 'if (limit == 0.0) return x;' in math
    assert 'if (b <= 0.0 || b >= 1.0) return t;' in math
    assert 'if (g <= 0.0 || g >= 1.0) return t;' in math
    assert 'float period = abs(m);' in math
    assert 'if (period == 0.0) return x;' in math
    assert 'resolution.y != 0.0 ? resolution.x / resolution.y : 1.0' in math
    assert 'if (sigma <= 0.0001) return x == 0.0 ? 1.0 : 0.0;' in blur
    assert 'if (samples == 1) return image.Sample(textureSampler, uv);' in blur
    assert 'return curlDirection(' in noise and 'if (lenSq <= 1.0e-12)' in noise
    assert 'if (octaves <= 0 || abs(eps) <= 1.0e-6)' in noise
    assert 'dot(a, hash22(i) * 2.0 - 1.0)' in noise
    assert 'abs(2.0 * perlinNoise(p) - 1.0)' in noise
    assert 'abs(2.0 * perlinNoise3D(p) - 1.0)' in noise
    assert 'float3(x, y, p.z) * 2.0 + 100.0;' in noise
    assert 'p.z * 2.0) * 2.0' not in noise
    assert 'float3 c = a - o2 + 2.0 * G;' in noise
    assert 'float3 d = a - ONE + 3.0 * G;' in noise
    assert 'float4(dot(a, a), dot(b, b), dot(c, c), dot(d, d))' in noise

    # All six strict coordinate orderings must reach consecutive simplex vertices.
    from itertools import permutations
    for order in permutations(range(3)):
        a=[0.0,0.0,0.0]
        for rank,axis in enumerate(order): a[axis]=float(rank)
        g=[float(a[k]>=a[(k+1)%3]) for k in range(3)]
        lo=[1.0-v for v in g]
        first=[min(g[k],lo[(k+2)%3]) for k in range(3)]
        second=[max(g[k],lo[(k+2)%3]) for k in range(3)]
        assert sum(first)==1.0 and sum(second)==2.0
        assert all(first[k]<=second[k] for k in range(3))
    print('STDLIB_STATIC_CONTRACT_PASS=1')
    for name in HEADERS:
        case='#include "../stdlib/'+name+'.glsl"\n'
        if name=='blur':
            main='float4 mainImage(VertData v_in) : TARGET {return boxBlur(v_in.uv,uv_pixel_interval,1);}'
        elif name=='math':
            main='float4 mainImage(VertData v_in) : TARGET {return float4(smootherstep(0.0,1.0,v_in.uv.x),luma(float3(0.2,0.4,0.6)),0.0,1.0);}'
        elif name=='colors':
            main='float4 mainImage(VertData v_in) : TARGET {return float4(blendOverlay(float3(0.1,0.2,0.3),hsv2rgb(rgb2hsv(float3(0.8,0.7,0.1)))),1.0);}'
        elif name=='noise':
            main='float4 mainImage(VertData v_in) : TARGET {float v=fbm(v_in.uv,3);return float4(v,v,v,1.0);}'
        elif name=='printmaking':
            main='float4 mainImage(VertData v_in) : TARGET {float2 p=v_in.uv*uv_size;float4 c=printNearestCell(p/8.0,0.5,2.0);float v=printHatchField(p,0.5,16.0,2.0)+printValueNoise(c.xy,1.0);return float4(v,v,v,1.0);}'
        elif name=='oklab':
            main='float4 mainImage(VertData v_in) : TARGET {float3 l=pfOklabToLch(pfLinearToOklab(pfSrgbToLinear(float3(v_in.uv,0.5))));return float4(pfLinearToSrgb(pfOklabToLinear(pfLchToOklab(l))),1.0);}'
        else:
            main='float4 mainImage(VertData v_in) : TARGET {float v=easeInOutCubic(v_in.uv.x)+pingPong(elapsed_time,3.0);return float4(v,v,v,1.0);}'
        compile_case(name,case+main)
    includes='\n'.join('#include "../stdlib/'+name+'.glsl"' for name in HEADERS) + '\n#include "../stdlib/math.glsl"'
    compile_case('all',includes+'\nfloat4 mainImage(VertData v_in) : TARGET {float n=fbm(v_in.uv,3)+worley(v_in.uv).x+worley3D(float3(v_in.uv,0.5)).x;float3 c=tonemapACES(rgb2lab(float3(n,n,n)));float w=loopWithHold(elapsed_time,1.0,0.5);return gaussianBlur1D(v_in.uv,uv_pixel_interval,float2(1.0,0.0),2.0,3)*float4(c,1.0)*easeInOutSine(w);}')
    # Exercise the reviewed functions as real libobs shader expressions,
    # including their boundary inputs. This verifies compilation, not pixels.
    cases='\n'.join('#include "../stdlib/'+name+'.glsl"' for name in HEADERS)
    edge_main = '''float4 mainImage(VertData v_in) : TARGET {
        float2 p = v_in.uv * 2.0;
        float3 q = float3(p, 0.25);
        float2 curl = curlNoise(p, 0.0) + curlFbm(p, 0, 0.01);
        float3 col = blendColor(float3(0.0,0.0,0.0), float3(1.0,0.0,0.0))
            + blendLuminosity(float3(1.0,0.0,0.0), float3(1.0,1.0,1.0))
            + posterize(float3(1.0,0.5,0.0), 3.0);
        float n = simplexNoise(p) + simplexNoise3D(q)
            + fbm3D(q, 2) + ridgeNoise3D(q, 2)
            + billowNoise3D(q, 2) + bumpNoise3D(q, 2)
            + ridgeNoise(p, 2) + billowNoise(p, 2) + bumpNoise(p, 2)
            + distToSegment(p, p, p)
            + softClamp(1.0, 0.0) + bias(0.5, 0.0) + bias(0.5, 1.0)
            + gain(0.5, 0.0) + gain(0.5, 1.0)
            + modPositive(-0.5, -2.0) + modPositive(1.0, 0.0)
            + aspectCorrect(p, float2(1920.0, 0.0)).x
            + expSmooth(0.0, 1.0, -1.0)
            + pingPong(-0.5, 1.0) + loopWithHold(-0.5, 1.0, 0.5)
            + gaussian1D(1.0, 0.0);
        float4 blurred = gaussianBlur1D(v_in.uv, uv_pixel_interval,
            float2(1.0,0.0), 0.0, 3)
            + directionalBlur(v_in.uv, uv_pixel_interval, 0.0, 10.0, 1);
        return float4(col * 0.01 + n * 0.01 + curl.x, blurred.g);
    }'''
    compile_case('edge-expressions', cases+'\n'+edge_main)
    # Compile the complete shipped shader files with their UI annotations
    # and nested relative include paths, not just synthetic calls.
    for name in ('ink_hatching', 'jittered_pointillism'):
        shader=ROOT/'data/examples/fork/printmaking'/f'{name}.shader'
        compile_case('printmaking/'+name,shader.read_text(),shader)
    print('STDLIB_NATIVE_OBS_PASS=1')


def main():
    global NATIVE_BINARY
    with tempfile.TemporaryDirectory(prefix='stdlib-native-compile-') as temp:
        NATIVE_BINARY=Path(temp)/'verify-effect'
        flags=shlex.split(subprocess.check_output(['pkg-config','--cflags','--libs','libobs'],text=True))
        subprocess.run(['cc','-O2','-Wall','-Wextra',str(ROOT/'tests/native_stdlib_compile.c'),'-o',str(NATIVE_BINARY),*flags],check=True)
        checks()

if __name__=='__main__':main()
