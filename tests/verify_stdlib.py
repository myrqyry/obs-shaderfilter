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
HEADERS=('math', 'colors', 'noise', 'animation', 'blur')


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


def compile_case(name,body):
    with tempfile.TemporaryDirectory(prefix='shader-stdlib-') as tmp:
        root=Path(tmp)
        # Treat the synthetic shader as though it lives in data/examples:
        # this exercises the exact documented ../stdlib/... relative paths.
        virtual_shader=ROOT/'data/examples/_stdlib-smoke.shader'
        src=('#define OPENGL 1\n'+template('begin')+
             expand_text(body,virtual_shader).replace('[loop]','')+'\n'+template('end'))
        effect=root/'combined.effect';effect.write_text(src)
        result=subprocess.run([str(NATIVE_BINARY),str(effect)],text=True,capture_output=True)
        if result.returncode!=0:
            lines=[line for line in result.stdout.splitlines() if 'error' in line.lower() or 'PASS=' in line]
            raise RuntimeError(f'{name}: '+ '\n'.join(lines[-12:]))
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
        else:
            main='float4 mainImage(VertData v_in) : TARGET {float v=easeInOutCubic(v_in.uv.x)+pingPong(elapsed_time,3.0);return float4(v,v,v,1.0);}'
        compile_case(name,case+main)
    includes='\n'.join('#include "../stdlib/'+name+'.glsl"' for name in HEADERS) + '\n#include "../stdlib/math.glsl"'
    compile_case('all',includes+'\nfloat4 mainImage(VertData v_in) : TARGET {float n=fbm(v_in.uv,3)+worley(v_in.uv).x+worley3D(float3(v_in.uv,0.5)).x;float3 c=tonemapACES(rgb2lab(float3(n,n,n)));float w=loopWithHold(elapsed_time,1.0,0.5);return gaussianBlur1D(v_in.uv,uv_pixel_interval,float2(1.0,0.0),2.0,3)*float4(c,1.0)*easeInOutSine(w);}')
    print('STDLIB_NATIVE_OBS_PASS=1')


def main():
    global NATIVE_BINARY
    with tempfile.TemporaryDirectory(prefix='stdlib-native-compile-') as temp:
        NATIVE_BINARY=Path(temp)/'verify-effect'
        flags=shlex.split(subprocess.check_output(['pkg-config','--cflags','--libs','libobs'],text=True))
        subprocess.run(['cc','-O2','-Wall','-Wextra',str(ROOT/'tests/native_stdlib_compile.c'),'-o',str(NATIVE_BINARY),*flags],check=True)
        checks()

if __name__=='__main__':main()
