// OBS HLSL adaptation of Noisemaker filter/polar/polar.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/polar
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// Noisemaker filter inputs use edge-clamped texture sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Polar and vortex coordinate transforms
 */
uniform int polarMode<
    string label = "Polar mode";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "polar";
    int option_1_value = 1;
    string option_1_label = "vortex";
> = 0;
uniform float speed<
    string label = "Speed";
    string widget_type = "slider";
    float minimum = -2.0;
    float maximum = 2.0;
    float step = 0.01;
> = 0.0;
uniform float rotation<
    string label = "Rotation";
    string widget_type = "slider";
    float minimum = -2.0;
    float maximum = 2.0;
    float step = 0.01;
> = 0.0;
uniform float scale<
    string label = "Scale";
    string widget_type = "slider";
    float minimum = -2.0;
    float maximum = 2.0;
    float step = 0.01;
> = 0.0;
uniform bool aspectLens<
    string label = "Aspect lens";
> = true;
uniform bool antialias<
    string label = "Antialias";
> = true;
#define TAU 6.28318530718

float smod(float v, float m) {
    return m * (0.75 - abs(frac(v) - 0.5) - 0.25);
}

float2 smod2(float2 v, float m) {
    return m * (0.75 - abs(frac(v) - 0.5) - 0.25);
}

float2 polarCoords(float2 uv, float aspect) {
    uv -= 0.5;
    if (aspectLens) { uv.x *= aspect; }
    float2 coord = float2(atan(uv.y, uv.x) / TAU + 0.5, length(uv) - scale * 0.075);
    coord.x = smod(coord.x + elapsed_time * -rotation, 1.0);
    coord.y = smod(coord.y + elapsed_time * speed, 1.0);
    return coord;
}

float2 vortexCoords(float2 uv, float aspect) {
    uv -= 0.5;
    if (aspectLens) { uv.x *= aspect; }
    float r2 = dot(uv, uv) - scale * 0.01;
    uv = uv / r2;
    uv.x = smod(uv.x + elapsed_time * -rotation, 1.0);
    uv.y = smod(uv.y + elapsed_time * speed, 1.0);
    return uv;
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 texSize = uv_size;
    float2 tileDims = texSize;
    float2 fullRes = uv_size.x > 0.0 ? uv_size : tileDims;
    float2 uv = ((v_in.uv * uv_size) + float2(0.0, 0.0)) / fullRes;
    float aspect = fullRes.x / fullRes.y;

    float2 coord;
    if (polarMode == 0) {
        coord = polarCoords(uv, aspect);
    } else {
        coord = vortexCoords(uv, aspect);
    }

    if (antialias) {
        float2 dx = ddx(coord);
        float2 dy = ddy(coord);
        float4 col = float4(0.0, 0.0, 0.0, 0.0);
        col += nmSample(coord + dx * -0.375 + dy * -0.125);
        col += nmSample(coord + dx *  0.125 + dy * -0.375);
        col += nmSample(coord + dx *  0.375 + dy *  0.125);
        col += nmSample(coord + dx * -0.125 + dy *  0.375);
        fragColor = col * 0.25;
    } else {
        fragColor = nmSample(coord);
    }
    return fragColor;
}
