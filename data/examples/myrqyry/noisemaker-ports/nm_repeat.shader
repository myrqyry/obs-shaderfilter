// OBS HLSL adaptation of Noisemaker filter/repeat/repeat.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/repeat
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
uniform float offsetX<
    string label = "Offset x";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.5;
uniform float offsetY<
    string label = "Offset y";
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
  // Compute global coordinate
  float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);

  // Compute global UV
  float2 globalUV = globalCoord / uv_size;

  // Apply repeat transformation in global space
  float2 st = globalUV;
  st.x *= aspect;
  st = st * float2(x, y) + float2(offsetX * aspect, offsetY);
  st.x /= aspect;

  // Apply wrap mode
  if (wrap == 0) {
      // mirror
      st = abs(nmMod2(st + 1.0, 2.0) - 1.0);
  } else if (wrap == 1) {
      // repeat
      st = frac(st);
  } else {
      // clamp
      st = clamp(st, 0.0, 1.0);
  }

  // Convert warped global UV to local UV for sampling
  float2 localUV = (st * uv_size - float2(0.0, 0.0)) / uv_size;

  // For seamless tiling across tile boundaries, apply wrap to local UV
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
