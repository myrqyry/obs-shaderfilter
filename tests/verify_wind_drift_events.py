#!/usr/bin/env python3
"""Static and native libobs Shaderfilter validation, without touching the running OBS UI."""
from pathlib import Path
import shlex
import struct
import zlib
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
SHADER=ROOT/'data/examples/myrqyry/wind-drift-events.shader'
SRC=ROOT/'obs-shaderfilter.c'
LICENSE=ROOT/'docs/shaders/wind-drift-events/LICENSE-MIT.txt'
NATIVE=ROOT/'tests/obs_wind_native_compile.c'


def check_contract(s: str):
    assert s.count('float4 mainImage(VertData v_in) : TARGET') == 1
    assert s.count('image.Sample(textureSampler,uv)') == 1
    assert 'for (int i=0;i<24;i++)' in s and 'if (i>=Wind_Count) break;' in s
    assert 'int maximum=24;' in s
    assert 'elapsed_time_enable' in s and 'Wind_Mode==0' in s
    assert 'age=t-delay' in s and 'age>life' in s
    assert 'Wind_Mode==0' in s and 'frac((t*fall/max(duration,1.0))+h0)' in s
    assert 'if (Wind_OverlayOnly)' in s and 'return float4(colorSum,alpha)' in s
    assert 'original.rgb*original.a*(1.0-alpha)' in s and 'original.a*(1.0-alpha)' in s
    assert 'uniform bool Wind_OverlayOnly<' in s and '> = false;' in s
    assert s.count('Wind_Style==')>=1 and 'windSilhouette(' in s
    assert 'texture2d image' not in s and 'technique Draw' not in s
    assert 'uniform texture2d ' not in s
    assert len(list((ROOT/'data/examples/myrqyry').glob('wind-drift-events.*'))) == 1
    assert chr(92)+'n' not in s, 'Literal backslash-n escaped into shader source'
    assert 'float styleFall=' in s and 'float styleSpin=' in s
    assert 'elapsed_time_enable' in s and 'Wind_Mode==0' in s
    img=(ROOT/'docs/shaders/wind-drift-events/transparent-1920x1080.png').read_bytes()
    assert img[:8] == bytes((137,80,78,71,13,10,26,10))
    assert struct.unpack('>II',img[16:24])==(1920,1080)
    assert img[25] == 6, 'Expected 8-bit RGBA PNG'
    rgba=zlib.decompress(img[41:-16])
    assert len(rgba) == 1080*(1+1920*4)
    assert not any(rgba), 'Expected a truly transparent all-zero source'
    assert 'MIT License' in LICENSE.read_text()
    assert 'Copyright (c) 2026 Profesor Shader' in LICENSE.read_text()
    print('WIND_DRIFT_STATIC_CONTRACT_PASS=1')


def decode_template(source: str, name: str)->str:
    start=f'static const char *effect_template_{name} = "'
    assert source.count(start)==1, 'Shaderfilter template signature changed'
    body=source.split(start,1)[1].split('";',1)[0]
    return body.replace('\\\n','').replace('\\n','\n')


def main():
    shader=SHADER.read_text();check_contract(shader)
    src=SRC.read_text()
    combined=('#define OPENGL 1\n'+decode_template(src,'begin')+
              shader.replace('[loop]','')+'\n'+decode_template(src,'end'))
    assert combined.count('technique Draw')==1
    with tempfile.TemporaryDirectory(prefix='obs-wind-') as directory:
        t=Path(directory)
        effect=t/'wind-drift.effect';effect.write_text(combined)
        binary=t/'native-compile'
        flags=shlex.split(subprocess.check_output(['pkg-config','--cflags','--libs','libobs'],text=True))
        subprocess.run(['cc','-Wall','-Wextra','-O2',str(NATIVE),'-o',str(binary),*flags],check=True)
        result=subprocess.run([str(binary),str(effect)],text=True,capture_output=True)
        if result.returncode:
            raise RuntimeError(f'Native libobs error ({result.returncode}):\n{result.stdout}\n{result.stderr}')
        assert 'NATIVE_OBS_SHADER_COMPILE_PASS=1' in result.stdout
        print(result.stdout.strip());print('WIND_DRIFT_NATIVE_OBS_PASS=1')

if __name__=='__main__':main()
