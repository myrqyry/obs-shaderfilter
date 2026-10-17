"""PR #13 correctness and license regressions, alongside native GPU probes."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
SHADERS=ROOT/'data/examples/myrqyry'

class ReviewedShaderContracts(unittest.TestCase):
    def test_watercolor_blend_uses_unwarped_input(self):
        src=(SHADERS/'shader_effects/se_watercolor.shader').read_text()
        self.assertIn('lerp(src.rgb,painted,saturate(Effect_Mix))',src)
        self.assertIn('return float4(saturate(color),src.a)',src)
        self.assertNotIn('lerp(source.rgb,painted,saturate(Effect_Mix))',src)

    def test_wind_background_is_premultiplied(self):
        src=(SHADERS/'wind-drift-events.shader').read_text()
        self.assertIn('original.rgb*original.a*(1.0-alpha)',src)
        self.assertIn('alpha+original.a*(1.0-alpha)',src)

    def test_motion_warmup_restarts_when_filter_reenabled(self):
        src=(SHADERS/'imweb-ports/motion_matte.shader').read_text()
        runtime=(ROOT/'obs-shaderfilter.c').read_text()
        self.assertIn('motion *= saturate(elapsed_time_enable / warmup_seconds)',src)
        self.assertNotIn('motion *= saturate(elapsed_time_start / warmup_seconds)',src)
        self.assertIn('filter->shader_enable_time = filter->elapsed_time',runtime)

    def test_motion_luma_is_difference_of_luminances(self):
        src=(SHADERS/'imweb-ports/motion_matte.shader').read_text()
        self.assertIn('abs(dot(a, float3(0.299, 0.587, 0.114)) -',src)
        self.assertNotIn('dot(d, float3(0.299, 0.587, 0.114))',src)

    def test_original_glyphfield_license_is_preserved(self):
        shader=(SHADERS/'soft_register.shader').read_text()
        license=SHADERS/'GLYPHFIELD-LICENSE.txt'
        self.assertTrue(license.exists(),'Upstream license notice missing')
        body=license.read_text()
        self.assertIn('Copyright (c) 2026 Kevin Liu',body)
        self.assertIn('Permission is hereby granted, free of charge',body)
        self.assertIn('THE SOFTWARE IS PROVIDED "AS IS"',body)
        self.assertIn('GLYPHFIELD-LICENSE.txt',shader)

    def test_n64_sampler_avoids_unassociated_rgb_halos(self):
        src=(SHADERS/'retro_ursc/ursc_n64_three_point.shader').read_text()
        self.assertIn('float4 urscPremultiply(float4 c)',src)
        self.assertIn('return float4(c.rgb*c.a,c.a);',src)
        self.assertIn('float3 rgb = mixed.a > 0.00001 ?',src)
        self.assertIn('mixed.rgb/mixed.a : float3(0.0,0.0,0.0)',src)

if __name__=='__main__': unittest.main()
