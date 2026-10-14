// OBS HLSL adaptation of Noisemaker filter/wind/wind.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/wind
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// Noisemaker filter inputs use edge-clamped texture sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}
/*
 * Wind — soft horizontal trails from bright image structure.
 *
 * Every fragment integrates brighter samples along its upwind scanline.
 * A smooth luminance gate prevents threshold chatter, distance weights
 * taper the run, and the weighted integration avoids the hard winner and
 * random segment boundaries that make a directional trail look like grain.
 * Wind tapers quickly, Blast carries a broad dense trail, and Stagger uses
 * a continuous row phase so adjacent scanlines separate without band edges.
 */
// METHOD is a compile-elapsed_time define injected by the runtime (see definition.js
// `globals.method.define`). Wrapping the wind/blast/stagger dispatch in #if
// blocks instead of a runtime int comparison lets the compiler drop the
// unreachable decay/taper/density/gain arms for the compiled variant.
uniform int direction<
    string label = "Direction";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "fromLeft";
    int option_1_value = 1;
    string option_1_label = "fromRight";
> = 0;
uniform float strength<
    string label = "Strength";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 0.01;
> = 90.0;
uniform float threshold<
    string label = "Threshold";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 0.01;
> = 10.0;
float lum(float3 c) {
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}
float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 uv = (v_in.uv * uv_size) / uv_size;
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float4 src = nmSample(uv);
    float amount = clamp(strength / 100.0, 0.0, 1.0);
    if (amount <= 0.0) {
        fragColor = src;
        return fragColor;
    }
    float reach = 32.0 * amount;
    float marchDir = (direction == 0) ? -1.0 : 1.0;
    float staggerPhase = 0.0;
    float3 accumColor = float3(0.0, 0.0, 0.0);
    float accumWeight = 0.0;
    float baseLum = lum(src.rgb);
    float edge = threshold / 100.0;
    for (int i = 1; i <= 32; i++) {
        float distancePx = float(i) * 1.0;
        if (distancePx > reach) { break; }
        float sampleDistance = distancePx + staggerPhase;
        float2 sampleUV = clamp(
            ((v_in.uv * uv_size) + float2(marchDir * sampleDistance, 0.0)) / uv_size,
            0.0, 1.0);
        float3 candidate = nmSample(sampleUV).rgb;
        float contrast = lum(candidate) - baseLum - edge;
        float activation = smoothstep(0.0, 0.08, contrast);
        float alongRun = distancePx / max(reach, 1.0);
        float decayRate = 0.8;
        float taperStart = 0.82;
        float endTaper = 1.0 - smoothstep(taperStart, 1.0, alongRun);
        float weight = activation * exp(-decayRate * alongRun) * endTaper;
        accumColor += candidate * weight;
        accumWeight += weight;
    }
    float3 integrated = accumColor / max(accumWeight, 0.00001);
    float densityRate = 0.12;
    float density = 1.0 - exp(-accumWeight * densityRate);
    float methodGain = 1.0;
    float blendAmount = clamp(density * amount * methodGain, 0.0, 1.0);
    float3 streak = lerp(src.rgb, integrated, blendAmount);
    fragColor = float4(max(src.rgb, streak), src.a);
    return fragColor;
}
