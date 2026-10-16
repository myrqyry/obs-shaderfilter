#!/usr/bin/env python3
"""Prove migrated filters work with real libobs/OpenGL native GPU readbacks."""
from pathlib import Path
import re
import subprocess
import tempfile
import verify_stdlib as obs

root=Path(__file__).resolve().parents[1]
fx=root/'data/examples/myrqyry'
# The pass-through setting MUST produce source pixels. Active rendering MUST
# change output RGB without silently altering alpha, including partial alpha.
CASES={
    'psx/psx_analog_hybrid.shader':'Mix',
    'psx/psx_color_grade.shader':'Mix',
    'psx/psx_dither_quantize.shader':'Mix',
    'psx/psx_instability.shader':'Mix',
    'retro_ursc/ursc_n64_three_point.shader':'Effect_Mix',
    'retro_ursc/ursc_shiny_glimmer.shader':'Effect_Mix',
    'shader_effects/se_engraving.shader':'Effect_Mix',
    'shader_effects/se_watercolor.shader':'Effect_Mix',
    'retro_capture/retrocapture_cmyk_print.shader':'Effect_Mix',
    'composite_signal.shader':'signal_amount',
    'soft_register.shader':'print_mix',
}
PRESETS={
    'psx/psx_analog_hybrid.shader': {'Color_Bits':5, 'Pixel_Softness':0.3, 'Chroma_Split':0.6},
    'psx/psx_color_grade.shader': {'Color_Bits':5, 'Gamma':1, 'Contrast':1.08,
                                    'Saturation':0.9, 'Dither_Amount':0.65},
    'psx/psx_dither_quantize.shader': {'Color_Bits':5, 'Dither_Amount':0.75},
    'psx/psx_instability.shader': {'Pixel_Cell':4, 'Jitter_Pixels':1.0, 'Line_Jog':0.7,
                                  'Band_Height':12, 'Chroma_Pixels':0.5},
    'retro_ursc/ursc_n64_three_point.shader': {'Virtual_Width':48, 'Virtual_Height':36},
    'retro_ursc/ursc_shiny_glimmer.shader': {'Brightness_Levels':8},
    'shader_effects/se_watercolor.shader': {'Brush_Radius':3, 'Paper_Grain':0.0},
    'shader_effects/se_engraving.shader': {'Lines':80, 'Contrast':1},
}
# UV displacement/three-point resampling deliberately alters alpha, including
# texture-grid edge behavior. These aren't flat color grading operations.
ALPHA_DISPLACES={'psx/psx_analog_hybrid.shader','psx/psx_instability.shader',
                 'retro_ursc/ursc_n64_three_point.shader'}
PATTERN=re.compile(r'GPU_READBACK_PASS=1 CONTROL=\S+ CHANGED=(\d+) CHANGED_FROM_INPUT=(\d+) ALPHA_CHANGED=(\d+) RGB_SUM=(\d+)')

def main():
    assert all((fx/path).is_file() for path in CASES)
    with tempfile.TemporaryDirectory(prefix='obs-additional-effects-') as tmp:
        wd=Path(tmp)
        inc=subprocess.check_output(['pkg-config','--variable=includedir','libobs'],text=True).strip()
        libs=subprocess.check_output(['pkg-config','--libs','libobs'],text=True).split()
        probe=wd/'probe'
        subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra','-I'+str(Path(inc)/'obs'),
                        str(root/'tests/native_shader_pixel_probe.cpp'),'-o',str(probe),*libs],check=True)
        fail=[]
        for path,control in CASES.items():
            shader=fx/path
            src='#define OPENGL 1\n'+obs.template('begin')+obs.expand_text(shader.read_text(),shader).replace('[loop]','')+'\n'+obs.template('end')
            effect=wd/'port.effect';effect.write_text(src)
            for partial in (False,True):
                argv=[str(probe),str(effect),control,'0','1']
                if partial:argv.append('partial-alpha')
                argv.extend(f'{name}={value}' for name,value in PRESETS.get(path,{}).items())
                run=subprocess.run(argv,capture_output=True,text=True,timeout=25)
                match=PATTERN.search(run.stdout)
                if match:
                    changed,identity,alpha,rgbsum=map(int,match.groups())
                    ok=(changed>20 and identity==0 and (alpha==0 or path in ALPHA_DISPLACES) and rgbsum>0 and run.returncode==0)
                else:ok=False
                print('PASS' if ok else 'FAIL',path,'partial' if partial else 'opaque',
                      match.groups() if match else (run.stdout+run.stderr)[-900:],flush=True)
                if not ok:fail.append((path,partial))
        print(f'ADDITIONAL_EFFECTS_REAL_GPU_PASS={int(not fail)} CASES={2*len(CASES)} FAILED={len(fail)}',flush=True)
        if fail:raise SystemExit(1)

if __name__=='__main__':main()
