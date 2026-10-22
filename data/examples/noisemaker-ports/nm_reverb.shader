// OBS HLSL adaptation of Noisemaker filter/reverb/reverb.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/reverb
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}
float2 nmMod2(float2 x, float m) { return x - m * floor(x / m); }

// Reverb effect: blend input with multiple scaled-down versions of itself.
// Iterations control how many octaves of scaling are blended.
uniform int iterations<
    string label = "Iterations";
    string widget_type = "slider";
    int minimum = 1;
    int maximum = 8;
    int step = 1;
> = 3;
uniform bool ridges<
    string label = "Ridges";
> = false;
uniform float alpha<
    string label = "Alpha";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;
uniform float wrap<
    string label = "Wrap";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 2.0;
    float step = 0.01;
> = 0.0;
float2 applyWrap(float2 uv) {
    int mode = int(wrap);
    if (mode == 0) {
        return abs(nmMod2(uv + 1.0, 2.0) - 1.0);
    } else if (mode == 1) {
        return frac(uv);
    }
    return clamp(uv, 0.0, 1.0);
}

float4 ridge_transform(float4 color) {
    return float4(1.0, 1.0, 1.0, 1.0) - abs(color * 2.0 - float4(1.0, 1.0, 1.0, 1.0));
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 dims = uv_size;

    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 globalUV = globalCoord / uv_size;
    float2 localUV = (v_in.uv * uv_size) / dims;

    float4 original = nmSample(localUV);
    float4 current = original;

    if (ridges) {
        current = ridge_transform(current);
    }

    float4 accum = current;
    float totalWeight = 1.0;
    float weight = 0.5;
    float scale = 2.0;

    int iters = clamp(iterations, 1, 8);
    for (int i = 0; i < iters; i++) {
        float2 warpedGlobalUV = globalUV * scale;
        float2 wrappedGlobalUV = applyWrap(warpedGlobalUV);
        float2 sampledLocalUV = frac((wrappedGlobalUV * uv_size - float2(0.0, 0.0)) / dims);

        float4 scaled = nmSample(sampledLocalUV);

        if (ridges) {
            scaled = ridge_transform(scaled);
        }

        accum += scaled * weight;
        totalWeight += weight;

        scale *= 2.0;
        weight *= 0.5;
    }

    float4 result = accum / totalWeight;

    fragColor = float4(lerp(original.rgb, result.rgb, alpha), 1.0);
    return fragColor;
}
