// OBS HLSL adaptation of Noisemaker filter/scroll/scroll.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/scroll
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}
float2 nmMod2(float2 x, float m) { return x - m * floor(x / m); }

uniform float x<
    string label = "X";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.5;
uniform float y<
    string label = "Y";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.5;
uniform float speedX<
    string label = "Speed x";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.5;
uniform float speedY<
    string label = "Speed y";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.5;
uniform int wrap<
    string label = "Wrap";
    string widget_type = "slider";
    int minimum = 0;
    int maximum = 2;
    int step = 1;
> = 0;
/* Scrolls texture coordinates with wraparound. */
float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float aspect = uv_size.x / max(uv_size.y, 1.0);
  float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
  float2 globalUV = globalCoord / uv_size;

  globalUV.x *= aspect;
  float2 offset = float2(-x + elapsed_time * -speedX, y + elapsed_time * speedY);
  offset.x *= aspect;
  globalUV += offset;
  globalUV.x /= aspect;

  // Convert to local UV for sampling
  float2 localUV = (globalUV * uv_size - float2(0.0, 0.0)) / uv_size;

  // Apply wrap mode in local UV space to constrain to tile bounds
  if (wrap == 0) {
      // mirror
      localUV = abs(nmMod2(localUV + 1.0, 2.0) - 1.0);
  } else if (wrap == 1) {
      // repeat
      localUV = frac(localUV);
  } else {
      // clamp
      localUV = clamp(localUV, 0.0, 1.0);
  }

  fragColor = float4(nmSample(localUV).rgb, 1.0);
    return fragColor;
}
