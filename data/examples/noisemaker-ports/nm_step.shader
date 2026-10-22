// OBS HLSL adaptation of Noisemaker filter/step/step.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/step
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// Noisemaker filter inputs use edge-clamped texture sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}
float3 nmFwidth3(float3 x) { return abs(ddx(x)) + abs(ddy(x)); }

/*
 * Step threshold effect
 * Creates hard edge at threshold value
 */
uniform float threshold<
    string label = "Threshold";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.5;
uniform bool antialias<
    string label = "Antialias";
> = true;
float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 texSize = uv_size;
    float2 uv = (v_in.uv * uv_size) / texSize;
    float4 color = nmSample(uv);

    if (antialias) {
        float3 fw = max(nmFwidth3(color.rgb), float3(0.0001, 0.0001, 0.0001));
        color.rgb = smoothstep(threshold - fw * 0.5, threshold + fw * 0.5, color.rgb);
    } else {
        color.rgb = step(threshold, color.rgb);
    }

    fragColor = color;
    return fragColor;
}
