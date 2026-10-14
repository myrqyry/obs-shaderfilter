// OBS HLSL adaptation of Noisemaker filter/scale/scale.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/scale
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}
float2 nmMod2(float2 x, float m) { return x - m * floor(x / m); }

uniform float scaleX<
    string label = "Scale x";
    string widget_type = "slider";
    float minimum = 0.05;
    float maximum = 4.0;
    float step = 0.01;
> = 0.5;
uniform float scaleY<
    string label = "Scale y";
    string widget_type = "slider";
    float minimum = 0.05;
    float maximum = 4.0;
    float step = 0.01;
> = 0.5;
uniform float centerX<
    string label = "Center x";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.5;
uniform float centerY<
    string label = "Center y";
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
float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float aspect = uv_size.x / max(uv_size.y, 1.0);
  // Compute global UV from tile-local coordinates
  float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
  float2 st = globalCoord / uv_size;

  // Apply scale transform in global UV space (centered and aspect-corrected)
  float2 c = float2(centerX, centerY);
  st -= c;
  st.x *= aspect;
  st = st / max(float2(scaleX, scaleY), float2(0.001, 0.001));
  st.x /= aspect;
  st += c;

  // Convert global UV to local UV for sampling inputTex
  float2 localUV = (st * uv_size - float2(0.0, 0.0)) / uv_size;

  // Apply wrap mode to local UV
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
