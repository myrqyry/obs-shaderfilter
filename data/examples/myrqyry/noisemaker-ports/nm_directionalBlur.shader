// OBS HLSL adaptation of Noisemaker filter/directionalBlur/directionalBlur.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/directionalBlur
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Directional Blur - linear motion blur along a fixed angle. Averages a
 * fixed N-tap comb stepped along
 * dir = (cos(angle), sin(angle)), spanning blurDistance px total
 * (t ranges over [-blurDistance/2, blurDistance/2]). A per-pixel hash
 * shifts the whole tap comb by up to half a tap-step to hide banding
 * from the fixed tap count.
 */
uniform float angle<
    string label = "Angle";
    string widget_type = "slider";
    float minimum = -180.0;
    float maximum = 180.0;
    float step = 0.01;
> = 0.0;
uniform float blurDistance<
    string label = "Blur distance";
    string widget_type = "slider";
    float minimum = 1.0;
    float maximum = 200.0;
    float step = 0.01;
> = 60.0;
#define N 32

float hash12(float2 p) {
    float3 p3 = frac(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 dir = float2(cos(radians(angle)), sin(radians(angle)));

    float tapStep = blurDistance / float(N - 1);
    float jitter = (hash12((v_in.uv * uv_size)) - 0.5) * tapStep;

    float4 sum = float4(0.0, 0.0, 0.0, 0.0);
    for (int i = 0; i < N; i++) {
        float t = (float(i) / float(N - 1) - 0.5) * blurDistance + jitter;
        float2 offset = dir * t;
        sum += nmSample(((v_in.uv * uv_size) + offset) / uv_size);
    }
    fragColor = sum / float(N);
    return fragColor;
}
