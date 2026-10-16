// OBS HLSL adaptation of Noisemaker filter/lens/lens.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/lens
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// Noisemaker filter inputs use edge-clamped texture sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Lens distortion (barrel/pincushion)
 * Warps sample coordinates radially around the frame center
 */
uniform float lensDisplacement<
    string label = "Lens displacement";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.0;
uniform bool aspectLens<
    string label = "Aspect lens";
> = true;
uniform bool antialias<
    string label = "Antialias";
> = true;
#define HALF_FRAME 0.5

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 texSize = uv_size;
    float2 tileDims = texSize;
    float2 dims = uv_size.x > 0.0 ? uv_size : tileDims;
    float2 uv = ((v_in.uv * uv_size) + float2(0.0, 0.0)) / dims;

    // Zoom for negative displacement (pincushion)
    float zoom = (lensDisplacement < 0.0) ? (lensDisplacement * -0.25) : 0.0;

    // Distance from center, optionally aspect-corrected for circular distortion
    float aspect = dims.x / dims.y;
    float2 dist = uv - HALF_FRAME;
    float2 aDist = dist;
    if (aspectLens) { aDist.x *= aspect; }

    float maxDist = length(float2(aspectLens ? aspect * 0.5 : 0.5, 0.5));
    float distFromCenter = length(aDist);
    float normalizedDist = clamp(distFromCenter / maxDist, 0.0, 1.0);

    // Stronger effect near edges, weaker at center
    float centerWeight = 1.0 - normalizedDist;
    float centerWeightSq = centerWeight * centerWeight;

    // Apply radial distortion in aspect-corrected space
    float2 displacement = aDist * zoom + aDist * centerWeightSq * lensDisplacement;

    // Convert displacement back to UV space
    if (aspectLens) { displacement.x /= aspect; }

    bool isTileRendering = length(float2(0.0, 0.0)) > 0.0;

    // For tile rendering, limit displacement to stay within overlap
    if (isTileRendering) {
        float maxDispPixels = 256.0;
        float dispPixels = length(displacement * dims);
        if (dispPixels > maxDispPixels) {
            displacement *= maxDispPixels / dispPixels;
        }
    }

    // Non-tiling keeps the frac() wrap so normal-size output is
    // byte-identical to the pre-tile-aware shader (zero baseline
    // regression). Tiling drops the wrap (displacement is clamped above so
    // the sample stays within the tile overlap).
    float2 warpedGlobalUV = isTileRendering ? (uv - displacement) : frac(uv - displacement);
    float2 offset = (warpedGlobalUV * dims - float2(0.0, 0.0)) / tileDims;

    float2 sampledUV = offset;

    if (antialias) {
        float2 dx = ddx(sampledUV);
        float2 dy = ddy(sampledUV);
        float4 col = float4(0.0, 0.0, 0.0, 0.0);

        col += nmSample(sampledUV + dx * -0.375 + dy * -0.125);
        col += nmSample(sampledUV + dx *  0.125 + dy * -0.375);
        col += nmSample(sampledUV + dx *  0.375 + dy *  0.125);
        col += nmSample(sampledUV + dx * -0.125 + dy *  0.375);

        fragColor = col * 0.25;
    } else {
        fragColor = nmSample(sampledUV);
    }
    return fragColor;
}
