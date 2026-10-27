#!/usr/bin/env python3
"""Compile curated Shaderfilter template shaders via native libobs, then real plugin pixels."""
from pathlib import Path
import shlex
import subprocess
import tempfile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT / "tests"))
import verify_stdlib
from test_curated_shader_ports import EXPECTED,BASE

def run(cmd):
    print("RUN", ' '.join(map(str,cmd)),flush=True)
    return subprocess.run(cmd, check=True, text=True)

def main():
    shaderlist = [BASE / p for p in EXPECTED]
    flags = shlex.split(subprocess.check_output(["pkg-config","--cflags","--libs","libobs"],text=True))
    module = Path.home()/".config/obs-studio/plugins/obs-shaderfilter/bin/64bit/obs-shaderfilter.so"
    data = Path.home()/".config/obs-studio/plugins/obs-shaderfilter/data"
    assert module.is_file() and data.is_dir()
    with tempfile.TemporaryDirectory(prefix="curated-shader-native-") as tmp:
        dest=Path(tmp)
        native=dest/"native-compile"
        run(["cc","-O2",str(ROOT/"tests/native_stdlib_compile.c"),"-o",str(native),*flags])
        for shader in shaderlist:
            full=("#define OPENGL 1\n"+verify_stdlib.template('begin')+
                  verify_stdlib.expand_includes(shader).replace("[loop]","")+
                  "\n"+verify_stdlib.template('end'))
            source=dest/(shader.stem+".effect")
            source.write_text(full)
            run(["xvfb-run","-a","-s","-screen 0 1280x720x24",str(native),str(source)])
            print("NATIVE_COMPILE_PASS",shader.name,flush=True)
        plugin_test=dest/"plugin-test"
        run(["g++","-std=gnu++20","-O2",
             "-I"+subprocess.check_output(["pkg-config","--variable=includedir","libobs"],text=True).strip()+"/obs",
             str(ROOT/"tests/verify_curated_ports_plugin.cpp"),
             "-o",str(plugin_test),*shlex.split(subprocess.check_output(["pkg-config","--libs","libobs"],text=True))])
        run(["xvfb-run","-a","-s","-screen 0 1280x720x24",
             "timeout","90",str(plugin_test),str(module),str(data),*map(str,shaderlist)])
    print("CURATED_SHADER_PORTS_FULL_PASS=1",flush=True)

if __name__=="__main__":
    main()
