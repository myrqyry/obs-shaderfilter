#!/usr/bin/env python3
"""Native GPU tests for frame-difference matte. Real libobs/OpenGL readback."""
from pathlib import Path
import subprocess
import tempfile
import verify_stdlib as std

root = Path(__file__).resolve().parents[1]
shader = root/'data/examples/myrqyry/imweb-ports/motion_matte.shader'

def main():
    assert shader.is_file(), 'Motion Matte shader not yet implemented'
    text=shader.read_text()
    assert 'uniform texture2d previous_image;' in text
    assert 'float4 mainImage(VertData v_in) : TARGET' in text
    with tempfile.TemporaryDirectory(prefix='obs-motion-native-') as temp:
        work=Path(temp)
        effect=work/'motion.effect'
        effect.write_text('#define OPENGL 1\n'+std.template('begin')+
                          std.expand_text(text, shader).replace('[loop]', '')+
                          '\n'+std.template('end'))
        inc=subprocess.check_output(['pkg-config','--variable=includedir','libobs'],text=True).strip()
        libs=subprocess.check_output(['pkg-config','--libs','libobs'],text=True).split()
        binary=work/'probe'
        subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra',
                        '-I'+str(Path(inc)/'obs'),
                        str(root/'tests/native_motion_matte_probe.cpp'),
                        '-o',str(binary),*libs],check=True)
        result=subprocess.run([str(binary),str(effect)],capture_output=True,text=True,timeout=30)
        if result.returncode or 'MOTION_MATTE_REAL_GPU_PASS=1' not in result.stdout:
            raise RuntimeError(f'Real GPU motion matte failed ({result.returncode}):\n'
                               +result.stdout+'\n'+result.stderr)
        print(result.stdout.strip())

if __name__=='__main__':main()
