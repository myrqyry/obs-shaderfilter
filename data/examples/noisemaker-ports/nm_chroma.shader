// OBS HLSL adaptation of Noisemaker filter/chroma/chroma.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/chroma
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Chroma isolation effect
 * Isolate specific color with range and feathering
 * Outputs mono mask based on hue distance from target
 */
uniform float targetHue<
    string label = "Target hue";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.33;
uniform float range<
    string label = "Range";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.5;
    float step = 0.01;
> = 0.25;
uniform float feather<
    string label = "Feather";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.25;
    float step = 0.01;
> = 0.05;
float3 rgb2hsv(float3 c) {
    float4 K = float4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float hueDistance(float h1, float h2) {
    float d = abs(h1 - h2);
    return min(d, 1.0 - d);
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 texSize = uv_size;
    float2 uv = (v_in.uv * uv_size) / texSize;
    float4 color = nmSample(uv);

    float3 hsv = rgb2hsv(color.rgb);
    float hue = hsv.x;
    float sat = hsv.y;

    float dist = hueDistance(hue, targetHue);

    // Apply range and feather to create smooth mask
    float inner = range;
    float outer = range + max(feather, 0.0001);
    float mask = 1.0 - smoothstep(inner, outer, dist);

    // Scale by saturation - desaturated colors don't have meaningful hue
    mask *= sat;

    fragColor = float4(float3(mask, mask, mask), color.a);
    return fragColor;
}
