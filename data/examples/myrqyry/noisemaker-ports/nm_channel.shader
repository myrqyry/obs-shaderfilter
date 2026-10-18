// OBS HLSL adaptation of Noisemaker filter/channel/channel.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/channel
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

uniform int channel<
    string label = "Channel";
    string widget_type = "slider";
    int minimum = 0;
    int maximum = 3;
    int step = 1;
> = 0;
uniform float scale<
    string label = "Scale";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 6.0;
    float step = 0.01;
> = 1.0;
uniform float offset<
    string label = "Offset";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.0;
/* Extracts a single channel (r=0, g=1, b=2, a=3) as grayscale. */
float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
  float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
  float2 st = ((v_in.uv * uv_size) - 0.5) / uv_size;
  float4 c = nmSample(st);

  float v;
  if (channel == 0) {
    v = c.r;
  } else if (channel == 1) {
    v = c.g;
  } else if (channel == 2) {
    v = c.b;
  } else {
    v = c.a;
  }

  v = frac(v * scale + offset);
  fragColor = float4(float3(v, v, v), 1.0);
    return fragColor;
}
