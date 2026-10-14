// OBS HLSL adaptation of Noisemaker filter/ridge/ridge.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/ridge
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

// Ridge effect.
// Parameterized ridge transform with configurable midpoint level.
uniform float level<
    string label = "Level";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.5;
float4 ridge_transform(float4 value, float lvl) {
    float denom = max(lvl, 1.0 - lvl);
    float4 result = float4(1.0, 1.0, 1.0, 1.0) - abs(value - float4(lvl, lvl, lvl, lvl)) / denom;
    return clamp(result, float4(0.0, 0.0, 0.0, 0.0), float4(1.0, 1.0, 1.0, 1.0));
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 dims = uv_size;
    float2 uv = (v_in.uv * uv_size) / dims;

    float4 texel = nmSample(uv);

    // Apply ridge transform
    float4 ridged = ridge_transform(texel, level);
    float4 out_color = float4(ridged.xyz, 1.0);

    fragColor = out_color;
    return fragColor;
}
