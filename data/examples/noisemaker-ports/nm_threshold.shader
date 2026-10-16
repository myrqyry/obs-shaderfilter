// OBS HLSL adaptation of Noisemaker filter/threshold/thresh.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/threshold
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

uniform float level<
    string label = "Level";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.5;
uniform float sharpness<
    string label = "Sharpness";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.5;
    float step = 0.01;
> = 0.05;
/* Binary threshold with adjustable edge softness. */
float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
  float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
  float2 st = (v_in.uv * uv_size) / uv_size;
  float4 c = nmSample(st);
  float l = dot(c.rgb, float3(0.299,0.587,0.114));
  float e = sharpness <= 0.0 ? step(level, l) : smoothstep(level - sharpness, level + sharpness, l);
  fragColor = float4(float3(e, e, e),1.0);
    return fragColor;
}
