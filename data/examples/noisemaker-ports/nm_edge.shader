// OBS HLSL adaptation of Noisemaker filter/edge/edge.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/edge
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// Noisemaker filter inputs use edge-clamped texture sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Edge detection with multiple kernels, sizes, and blend modes
 */
uniform float kernel<
    string label = "Kernel";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;
uniform float size<
    string label = "Size";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;
// OBS native 1.0 is fixed at unity.
uniform float blend<
    string label = "Blend";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 0.01;
> = 6.0;
uniform float invert<
    string label = "Invert";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 500.0;
    float step = 0.01;
> = 0.0;
uniform float channel<
    string label = "Channel";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.0;
uniform float threshold<
    string label = "Threshold";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 0.01;
> = 0.0;
uniform float amount<
    string label = "Amount";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 500.0;
    float step = 0.01;
> = 100.0;
uniform float mixAmt<
    string label = "Mix amt";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 0.01;
> = 100.0;
uniform float level<
    string label = "Level";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 0.01;
> = 50.0;
uniform float contourSide<
    string label = "Contour side";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 0.01;
> = 0.0;
#define LUMA float3(0.2126, 0.7152, 0.0722)

float getWeight(int dx, int dy, int kernelType) {
    if (dx == 0 && dy == 0) return 0.0;

    if (kernelType == 0) {
        // fine: cardinal neighbors only (cross Laplacian)
        if (dx == 0 || dy == 0) return -1.0;
        return 0.0;
    } else {
        // bold: all neighbors equally
        return -1.0;
    }
}

float4 applyBlend(float4 edge, float4 orig, int mode) {
    if (mode == 0) return min(orig + edge, float4(1.0, 1.0, 1.0, 1.0));                        // add
    if (mode == 1) return min(orig, edge);                                     // darken
    if (mode == 2) return abs(orig - edge);                                    // difference
    if (mode == 3) return min(orig / max(1.0 - edge, float4(0.001, 0.001, 0.001, 0.001)), float4(1.0, 1.0, 1.0, 1.0)); // dodge
    if (mode == 4) return max(orig, edge);                                     // lighten
    if (mode == 5) return orig * edge;                                         // multiply
    if (mode == 7) {                                                           // overlay
        float4 result;
        result.r = orig.r < 0.5 ? 2.0 * orig.r * edge.r : 1.0 - 2.0 * (1.0 - orig.r) * (1.0 - edge.r);
        result.g = orig.g < 0.5 ? 2.0 * orig.g * edge.g : 1.0 - 2.0 * (1.0 - orig.g) * (1.0 - edge.g);
        result.b = orig.b < 0.5 ? 2.0 * orig.b * edge.b : 1.0 - 2.0 * (1.0 - orig.b) * (1.0 - edge.b);
        result.a = orig.a;
        return result;
    }
    if (mode == 8) return 1.0 - (1.0 - orig) * (1.0 - edge);                 // screen
    return edge;                                                                // normal (6)
}

// Contour: mark only the selected side of a level crossing against the 4
// cardinal neighbors (Trace Contour). Returns a binary float3:
// 1.0 = background (white), 0.0 = contour line (dark).
float3 contourConv(float2 fragCoord, float2 texelSize, float3 centerRGB, float lvl, bool useLuma, bool upperSide) {
    float3 northRGB = nmSample((fragCoord + float2(0.0,  1.0)) * texelSize).rgb;
    float3 southRGB = nmSample((fragCoord + float2(0.0, -1.0)) * texelSize).rgb;
    float3 eastRGB  = nmSample((fragCoord + float2( 1.0, 0.0)) * texelSize).rgb;
    float3 westRGB  = nmSample((fragCoord + float2(-1.0, 0.0)) * texelSize).rgb;

    if (useLuma) {
        float centerL = dot(centerRGB, LUMA);
        bool centerOnSide = upperSide ? centerL >= lvl : centerL < lvl;
        bool crossing = centerOnSide && (upperSide
            ? dot(northRGB, LUMA) < lvl || dot(southRGB, LUMA) < lvl ||
              dot(eastRGB, LUMA) < lvl  || dot(westRGB, LUMA) < lvl
            : dot(northRGB, LUMA) >= lvl || dot(southRGB, LUMA) >= lvl ||
              dot(eastRGB, LUMA) >= lvl  || dot(westRGB, LUMA) >= lvl);
        return float3(crossing ? 0.0 : 1.0);
    }

    bvec3 centerOnSide = upperSide ? greaterThanEqual(centerRGB, float3(lvl, lvl, lvl))
                                    : lessThan(centerRGB, float3(lvl, lvl, lvl));
    bvec3 crossing = bvec3(
        centerOnSide.r && (upperSide
            ? northRGB.r < lvl || southRGB.r < lvl || eastRGB.r < lvl || westRGB.r < lvl
            : northRGB.r >= lvl || southRGB.r >= lvl || eastRGB.r >= lvl || westRGB.r >= lvl),
        centerOnSide.g && (upperSide
            ? northRGB.g < lvl || southRGB.g < lvl || eastRGB.g < lvl || westRGB.g < lvl
            : northRGB.g >= lvl || southRGB.g >= lvl || eastRGB.g >= lvl || westRGB.g >= lvl),
        centerOnSide.b && (upperSide
            ? northRGB.b < lvl || southRGB.b < lvl || eastRGB.b < lvl || westRGB.b < lvl
            : northRGB.b >= lvl || southRGB.b >= lvl || eastRGB.b >= lvl || westRGB.b >= lvl)
    );
    return float3(crossing.r ? 0.0 : 1.0, crossing.g ? 0.0 : 1.0, crossing.b ? 0.0 : 1.0);
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 texSize = uv_size;
    // uv_size is built in.
    float2 texelSize = 1.0 / uv_size;

    float4 origColor = nmSample((v_in.uv * uv_size) * texelSize);

    int kernelType = int(kernel);
    int radius = min(int((size + 1.0) * 1.0), 256);
    int blendMode = int(blend);
    bool doInvert = invert > 0.5;
    bool useLuma = channel > 0.5;

    // Convolution
    float3 conv = float3(0.0, 0.0, 0.0);
    float centerWeight = 0.0;

    if (kernelType == 2) {
        // Contour: level-crossing trace, not a weighted convolution.
        conv = contourConv((v_in.uv * uv_size), texelSize, origColor.rgb, level / 100.0, useLuma, contourSide > 0.5);
    } else {
        for (int dy = -3; dy <= 3; dy++) {
            for (int dx = -3; dx <= 3; dx++) {
                if (abs(dx) > radius || abs(dy) > radius) continue;
                if (dx == 0 && dy == 0) continue;

                float w = getWeight(dx, dy, kernelType);
                if (w == 0.0) continue;

                float2 sampleCoord = (v_in.uv * uv_size) + float2(float(dx), float(dy));
                float2 localUV = sampleCoord * texelSize;
                float3 s = nmSample(localUV).rgb;

                if (useLuma) {
                    conv += float3(dot(s, LUMA)) * w;
                } else {
                    conv += s * w;
                }

                centerWeight -= w;
            }
        }

        // Center sample
        float3 centerSample = origColor.rgb;
        if (useLuma) {
            centerSample = float3(dot(centerSample, LUMA));
        }
        conv += centerSample * centerWeight;
    }

    // Amount
    conv *= amount / 50.0;
    conv = clamp(conv, 0.0, 1.0);

    // Threshold (before invert so it measures actual edge strength)
    if (threshold > 0.0) {
        float thresh = threshold / 100.0;
        float edge;
        if (useLuma) {
            edge = conv.r;
        } else {
            edge = dot(conv, LUMA);
        }
        float mask = smoothstep(thresh - 0.01, thresh + 0.01, edge);
        conv *= mask;
    }

    // Invert
    if (doInvert) {
        conv = 1.0 - conv;
    }

    // Blend
    float4 edgeColor = float4(conv, origColor.a);
    float4 blended = applyBlend(edgeColor, origColor, blendMode);

    // Mix
    float m = mixAmt / 100.0;
    fragColor = float4(lerp(origColor.rgb, blended.rgb, m), origColor.a);
    return fragColor;
}
