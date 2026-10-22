// OBS HLSL adaptation of Noisemaker filter/tint/colorize.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/tint
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// Noisemaker filter inputs use edge-clamped texture sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

uniform float3 color<
    string label = "Color";
> = {1.0, 1.0, 1.0};
uniform float alpha<
    string label = "Alpha";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.5;
uniform float mode<
    string label = "Mode";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.5;
float3 rgb_to_hsv(float3 rgb) {
    float r = rgb.x, g = rgb.y, b = rgb.z;
    float max_c = max(max(r, g), b);
    float min_c = min(min(r, g), b);
    float delta = max_c - min_c;
    float hue = 0.0;
    if (delta != 0.0) {
        if (max_c == r) {
            float raw = (g - b) / delta;
            raw = raw - floor(raw / 6.0) * 6.0;
            if (raw < 0.0) raw += 6.0;
            hue = raw;
        } else if (max_c == g) {
            hue = (b - r) / delta + 2.0;
        } else {
            hue = (r - g) / delta + 4.0;
        }
    }
    hue /= 6.0;
    if (hue < 0.0) hue += 1.0;
    float sat = max_c != 0.0 ? delta / max_c : 0.0;
    return float3(hue, sat, max_c);
}

float3 hsv_to_rgb(float3 hsv) {
    float h = hsv.x, s = hsv.y, v = hsv.z;
    float dh = h * 6.0;
    float dr = clamp(abs(dh - 3.0) - 1.0, 0.0, 1.0);
    float dg = clamp(-abs(dh - 2.0) + 2.0, 0.0, 1.0);
    float db = clamp(-abs(dh - 4.0) + 2.0, 0.0, 1.0);
    float oms = 1.0 - s;
    return float3((oms + s * dr) * v, (oms + s * dg) * v, (oms + s * db) * v);
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
  float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
  float2 st = (v_in.uv * uv_size) / max(uv_size, float2(1.0, 1.0));
  float4 base = nmSample(st);
  float3 base_rgb = base.a > 0.0 ? clamp(base.rgb / base.a, 0.0, 1.0) : float3(0.0, 0.0, 0.0);

  int m = int(mode);
  float3 tinted;
  if (m == 1) {
      // Multiply
      tinted = base_rgb * color;
  } else if (m == 2) {
      // Recolor: replace hue with tint color's hue
      float tintHue = rgb_to_hsv(color).x;
      float3 base_hsv = rgb_to_hsv(base_rgb);
      tinted = clamp(hsv_to_rgb(float3(tintHue, clamp(base_rgb.y, 0.0, 1.0), clamp(base_hsv.z, 0.0, 1.0))), 0.0, 1.0);
  } else {
      // Overlay (default)
      tinted = color;
  }

  float3 rgb = lerp(base_rgb, tinted, alpha);
  fragColor = float4(rgb * base.a, base.a);
    return fragColor;
}
