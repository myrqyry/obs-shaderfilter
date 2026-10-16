// OBS HLSL adaptation of Noisemaker filter/colorReplace/colorReplace.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/colorReplace
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

uniform float3 targetColor<
    string label = "Target color";
> = {0.0, 0.0, 0.0};
uniform float3 replaceColor<
    string label = "Replace color";
> = {1.0, 1.0, 1.0};
uniform float sensitivity<
    string label = "Sensitivity";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.3;
uniform float smoothing<
    string label = "Smoothing";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.1;
uniform float colorMix<
    string label = "Color mix";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;
uniform float replaceAlpha<
    string label = "Replace alpha";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;
uniform float keepAlpha<
    string label = "Keep alpha";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;
/* Color replacement.
   Matches input pixels by euclidean RGB distance to targetColor, then
   independently remaps RGB toward replaceColor and rescales alpha. */
float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
  float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
  float2 st = (v_in.uv * uv_size) / max(uv_size, float2(1.0, 1.0));
  float4 src = nmSample(st);

  // Normalized euclidean RGB distance (0 = exact match, 1 = max distance).
  float dist = length(src.rgb - targetColor) / 1.7320508;

  // Match strength: 1 at exact match, 0 beyond (sensitivity + smoothing/2).
  float halfBand = max(smoothing, 0.0001) * 0.5;
  float edge0 = max(sensitivity - halfBand, 0.0);
  float edge1 = sensitivity + halfBand;
  float match = 1.0 - smoothstep(edge0, edge1, dist);

  float3 outRgb = lerp(src.rgb, replaceColor, match * colorMix);
  float outA = src.a * lerp(keepAlpha, replaceAlpha, match);

  fragColor = float4(outRgb, outA);
    return fragColor;
}
