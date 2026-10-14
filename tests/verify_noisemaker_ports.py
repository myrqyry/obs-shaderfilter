#!/usr/bin/env python3
"""Real libobs/OpenGL pixel tests of all shipped Noisemaker filter ports.

The C++ probe creates an actual image texture, renders the actual effect, and
reads the rendered pixels back. Does not assert WebGL2 reference parity.
"""
from pathlib import Path
import sys, subprocess, tempfile, re
import verify_stdlib as t
repo=Path(__file__).resolve().parents[1]
root=repo / 'data/examples/noisemaker-ports'
probes={
'channel':('channel',0,2),
'chroma':('targetHue',0.0,0.5),
'chromaticAberration':('aberrationAmt',0,100),
'colorReplace':('colorMix',0,1),
'deriv':('amount',0,5),
'directionalBlur':('blurDistance',0,64),
'glowingEdge':('alpha',0,1),
'invert':('mode',0,1),
'pixels':('size',1,16),
'posterize':('levels',2,10),
'repeat':('x',1,3),
'reverb':('alpha',0,1),
'ridge':('level',0.1,0.9),
'scale':('scaleX',0.5,1.8),
'scroll':('x',0,0.5),
'seamless':('blend',0,0.5),
'sharpen':('amount',0,2),
'simpleAberration':('displacement',0,0.08),
'sine':('amount',0,10),
'smoothstep':('edge1',0.4,0.9),
'sobel':('alpha',0,1),
'threshold':('level',0.2,0.8),
'translate':('x',0,0.35),
'vignette':('alpha',0,1),
'clouds':('scale',0.25,3),
'craquelure':('spacing',5,40),
'edge':('amount',0,1),
'emboss':('amount',0.2,4),
'flipMirror':('flipMode',0,1),
'lens':('lensDisplacement',0,1),
'lensFlare':('brightness',0,1),
'patchwork':('squareSize',5,30),
'polar':('polarMode',0,1),
'prismaticAberration':('aberrationAmt',0,100),
'step':('threshold',0.2,0.8),
'tint':('alpha',0,1),
'tunnel':('scale',0.5,2),
'wind':('strength',0,100),
}
assert len(probes)==38
shipped={p.stem.removeprefix('nm_') for p in root.glob('nm_*.shader')}
assert shipped==set(probes),f'Untested/missing effect files: {shipped ^ set(probes)}'
assert (root/'NOISEMAKER-LICENSE.txt').is_file()
for item in root.glob('nm_*.shader'):
    shader=item.read_text()
    assert 'Noise Factor LLC' in shader and 'noisefactorllc/noisemaker' in shader
    assert 'float4 mainImage(VertData v_in)' in shader
    assert shader.count('image.Sample(textureSampler,')==1
    assert 'nmSample(' in shader
bad=[]
with tempfile.TemporaryDirectory(prefix='nm-real-pixel-') as dir:
    probe=Path(dir)/'native-pixel-probe'
    inc=subprocess.check_output(['pkg-config','--variable=includedir','libobs'],text=True).strip()
    libs=subprocess.check_output(['pkg-config','--libs','libobs'],text=True).split()
    subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra',
        '-I'+str(Path(inc)/'obs'),str(repo/'tests/native_shader_pixel_probe.cpp'),
        '-o',str(probe),*libs],check=True)
    for name,(control,a,b) in probes.items():
       p=(root/f'nm_{name}.shader').resolve()
       text='#define OPENGL 1\n'+t.template('begin')+t.expand_text(p.read_text(),p).replace('[loop]','')+'\n'+t.template('end')
       effect=Path(dir)/f'{name}.effect';effect.write_text(text)
       proc=subprocess.run([str(probe),str(effect),control,str(a),str(b)],capture_output=True,text=True,timeout=15)
       m=re.search(r'GPU_READBACK_PASS=1 CONTROL=\S+ CHANGED=(\d+) CHANGED_FROM_INPUT=(\d+) ALPHA_CHANGED=(\d+) RGB_SUM=(\d+)',proc.stdout)
       if m:
          changed,changedInput,alpha,summap=map(int,m.groups())
          status='PASS' if changed>20 and summap>0 and alpha==0 else 'FLAT_OR_ALPHA_BROKEN'
          if status!='PASS':bad.append((name,status))
          print(name,status,'changed=',changed,'input_delta=',changedInput,'alpha_delta=',alpha,'rgb=',summap,flush=True)
       else:
          err=(proc.stderr or proc.stdout)[-900:]
          bad.append((name,err))
          print(name,'FAIL',err.replace('\n',' ')[:500],flush=True)
print('NOISEMAKER_REAL_GPU_PASS=',int(not bad),'GPU_BATCH_TOTAL',len(probes),'PASSED',len(probes)-len(bad),'FAILED',len(bad))
for name,e in bad:print('FAIL_CASE',name,e)
if bad:sys.exit(1)
