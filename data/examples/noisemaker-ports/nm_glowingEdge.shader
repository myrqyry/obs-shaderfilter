// OBS HLSL adaptation of Noisemaker filter/glowingEdge/glowingEdge.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/glowingEdge
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

// Glowing Edge - single-pass effect that computes Sobel edges and applies glow
uniform float alpha<
    string label = "Alpha";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;
uniform float sobelMetric<
    string label = "Sobel metric";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 3.0;
    float step = 0.01;
> = 0.0;
uniform float width<
    string label = "Width";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 10.0;
    float step = 0.01;
> = 1.0;
float luminance(float3 rgb) {
    return dot(rgb, float3(0.299, 0.587, 0.114));
}

float distance_metric(float gx, float gy, int metric) {
    float abs_gx = abs(gx);
    float abs_gy = abs(gy);

    if (metric == 1) {
        return abs_gx + abs_gy;  // Manhattan
    } else if (metric == 2) {
        return max(abs_gx, abs_gy);  // Chebyshev
    } else if (metric == 3) {
        float cross = (abs_gx + abs_gy) / 1.414;
        return max(cross, max(abs_gx, abs_gy));  // Minkowski
    }
    return sqrt(gx * gx + gy * gy);  // Euclidean (0)
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 uv = globalCoord / uv_size;
    float2 texel = width / uv_size;

    // Sample base color
    float4 base = nmSample((v_in.uv * uv_size) / uv_size);

    // Sample 3x3 neighborhood for Sobel
    float tl = luminance(nmSample(((uv + float2(-texel.x, -texel.y)) * uv_size - float2(0.0, 0.0)) / uv_size).rgb);
    float tc = luminance(nmSample(((uv + float2(0.0, -texel.y)) * uv_size - float2(0.0, 0.0)) / uv_size).rgb);
    float tr = luminance(nmSample(((uv + float2(texel.x, -texel.y)) * uv_size - float2(0.0, 0.0)) / uv_size).rgb);
    float ml = luminance(nmSample(((uv + float2(-texel.x, 0.0)) * uv_size - float2(0.0, 0.0)) / uv_size).rgb);
    float mr = luminance(nmSample(((uv + float2(texel.x, 0.0)) * uv_size - float2(0.0, 0.0)) / uv_size).rgb);
    float bl = luminance(nmSample(((uv + float2(-texel.x, texel.y)) * uv_size - float2(0.0, 0.0)) / uv_size).rgb);
    float bc = luminance(nmSample(((uv + float2(0.0, texel.y)) * uv_size - float2(0.0, 0.0)) / uv_size).rgb);
    float br = luminance(nmSample(((uv + float2(texel.x, texel.y)) * uv_size - float2(0.0, 0.0)) / uv_size).rgb);

    // Sobel kernels
    float gx = -tl - 2.0*ml - bl + tr + 2.0*mr + br;
    float gy = -tl - 2.0*tc - tr + bl + 2.0*bc + br;

    // Edge magnitude
    int metric = int(sobelMetric);
    float edge = clamp(distance_metric(gx, gy, metric) * 3.0, 0.0, 1.0);

    // Glow: edges emit the base color as additive light
    float3 glow = edge * base.rgb * 2.0;

    // Screen blend glow onto original: brighter where edges are
    float3 result = float3(1.0, 1.0, 1.0) - (float3(1.0, 1.0, 1.0) - base.rgb) * (float3(1.0, 1.0, 1.0) - glow);

    // Mix based on alpha
    float3 mixed = lerp(base.rgb, result, alpha);

    fragColor = float4(clamp(mixed, 0.0, 1.0), base.a);
    return fragColor;
}
