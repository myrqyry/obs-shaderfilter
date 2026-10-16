// OBS HLSL adaptation of Noisemaker filter/deriv/deriv.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/deriv
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Derivative-based edge detection
 * Computes image derivatives to highlight edges
 */
uniform float amount<
    string label = "Amount";
    string widget_type = "slider";
    float minimum = 0.1;
    float maximum = 5.0;
    float step = 0.01;
> = 2.0;
// Fixed 1: OBS uses native output resolution, not Noisemaker 1.0.
float3 desaturate(float3 color) {
    float avg = 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
    return float3(avg, avg, avg);
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 texSize = uv_size;
    float2 texelSize = 1.0 / texSize;
    float2 localUV = (v_in.uv * uv_size) * texelSize;

    float radiusPixels = amount * 1.0;
    radiusPixels = min(radiusPixels, 256.0);

    float4 color = nmSample(localUV);
    float3 center = desaturate(color.rgb);
    float3 right = desaturate(nmSample(localUV + float2(radiusPixels, 0.0) * texelSize).rgb);
    float3 bottom = desaturate(nmSample(localUV + float2(0.0, radiusPixels) * texelSize).rgb);

    float3 dx = center - right;
    float3 dy = center - bottom;

    float dist = distance(dx, dy) * 2.5;

    fragColor = float4(clamp(color.rgb * dist, 0.0, 1.0), color.a);
    return fragColor;
}
