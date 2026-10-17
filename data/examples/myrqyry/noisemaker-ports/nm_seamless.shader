// OBS HLSL adaptation of Noisemaker filter/seamless/seamless.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/seamless
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

uniform float blend<
    string label = "Blend";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.5;
    float step = 0.01;
> = 0.25;
uniform float repeat<
    string label = "Repeat";
    string widget_type = "slider";
    float minimum = 1.0;
    float maximum = 10.0;
    float step = 0.01;
> = 2.0;
uniform int curve<
    string label = "Curve";
    string widget_type = "slider";
    int minimum = 1;
    int maximum = 10;
    int step = 1;
> = 1;
/*
 * Blend weight function.
 * For a coordinate t in [0, 1], returns how much to blend
 * toward the wrapped sample. Weight is 1 at edges, 0 in center.
 */
float edgeWeight(float t, float width) {
    if (width <= 0.0) return 0.0;
    // Distance from nearest edge (0 at edge, 0.5 at center)
    float d = min(t, 1.0 - t);
    float w = 1.0 - clamp(d / width, 0.0, 1.0);
    // Apply curve
    if (curve == 0) {
        return w; // linear
    } else if (curve == 2) {
        return w * w; // sharp (quadratic)
    }
    return w * w * (3.0 - 2.0 * w); // smoothstep (default)
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 texSize = uv_size;
    float2 uv = (v_in.uv * uv_size) / texSize;

    // Apply tiling repetition
    float2 st = uv * repeat;
    st = frac(st);

    // Compute blend weights for x and y edges
    float wx = edgeWeight(st.x, blend);
    float wy = edgeWeight(st.y, blend);

    // Sample original and three wrapped positions
    float4 c00 = nmSample(st);
    float4 c10 = nmSample(frac(st + float2(0.5, 0.0)));
    float4 c01 = nmSample(frac(st + float2(0.0, 0.5)));
    float4 c11 = nmSample(frac(st + float2(0.5, 0.5)));

    // Bilinear blend using edge weights
    float4 mx0 = lerp(c00, c10, wx);
    float4 mx1 = lerp(c01, c11, wx);
    float4 result = lerp(mx0, mx1, wy);

    fragColor = float4(result.rgb, 1.0);
    return fragColor;
}
