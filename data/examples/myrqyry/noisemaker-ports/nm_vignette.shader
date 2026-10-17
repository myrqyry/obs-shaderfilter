// OBS HLSL adaptation of Noisemaker filter/vignette/vignette.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/vignette
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Radial vignette with brightness blend
 */
uniform float vignetteBrightness<
    string label = "Vignette brightness";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.0;
uniform float alpha<
    string label = "Alpha";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;
float computeVignetteMask(float2 uv, float2 dims) {
    if (dims.x <= 0.0 || dims.y <= 0.0) {
        return 0.0;
    }

    float2 delta = abs(uv - float2(0.5, 0.5));
    float aspect = dims.x / max(dims.y, 1.0);
    float2 scaled = float2(delta.x * aspect, delta.y);
    float maxRadius = length(float2(aspect * 0.5, 0.5));

    if (maxRadius <= 0.0) {
        return 0.0;
    }

    float normalizedDist = clamp(length(scaled) / maxRadius, 0.0, 1.0);
    return normalizedDist * normalizedDist;
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float aspect = uv_size.x / max(uv_size.y, 1.0);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 texSize = uv_size;
    float2 tileDims = texSize;
    float2 dims = uv_size.x > 0.0 ? uv_size : tileDims;
    float2 uv = (v_in.uv * uv_size) / tileDims;
    float2 globalUV = ((v_in.uv * uv_size) + float2(0.0, 0.0)) / dims;

    float4 texel = nmSample(uv);

    float mask = computeVignetteMask(globalUV, dims);

    // Apply brightness to RGB only, preserve alpha
    float3 brightnessRgb = float3(vignetteBrightness, vignetteBrightness, vignetteBrightness);
    float3 edgeBlend = lerp(texel.rgb, brightnessRgb, mask);
    float3 finalRgb = lerp(texel.rgb, edgeBlend, alpha);

    fragColor = float4(finalRgb, texel.a);
    return fragColor;
}
