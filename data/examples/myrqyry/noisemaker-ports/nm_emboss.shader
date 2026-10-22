// OBS HLSL adaptation of Noisemaker filter/emboss/emboss.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/emboss
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// Noisemaker filter inputs use edge-clamped texture sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Emboss relief with two explicit visual contracts:
 *   0 color       - the shipped color convolution, preserved exactly
 *   1 gray  - neutral-gray directional relief with edge-local chroma
 */

// STYLE is a compile-elapsed_time define injected by the runtime (definition.js
// globals.style.define). Baking it lets the compiler drop the unused color or
// gray path entirely instead of carrying both through a runtime branch.
#ifndef STYLE
#define STYLE 0
#endif
uniform float amount<
    string label = "Amount";
    string widget_type = "slider";
    float minimum = 0.1;
    float maximum = 5.0;
    float step = 0.01;
> = 1.0;
uniform float angle<
    string label = "Angle";
    string widget_type = "slider";
    float minimum = -360.0;
    float maximum = 360.0;
    float step = 0.01;
> = 135.0;
uniform float height<
    string label = "Height";
    string widget_type = "slider";
    float minimum = 1.0;
    float maximum = 10.0;
    float step = 0.01;
> = 1.0;
uniform float colorAmount<
    string label = "Color amount";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 0.01;
> = 100.0;
// OBS native 1.0 is fixed at unity.
#define LUMA float3(0.2126, 0.7152, 0.0722)

float3 sampleGlobal(float2 globalUV) {
    float2 localUV = (globalUV * uv_size - float2(0.0, 0.0)) / uv_size;
    return nmSample(localUV).rgb;
}

float3 colorDefaultEmboss(float2 uv, float2 texelSize) {
    float kernel[9];
    kernel[0] = -2.0; kernel[1] = -1.0; kernel[2] = 0.0;
    kernel[3] = -1.0; kernel[4] = 1.0;  kernel[5] = 1.0;
    kernel[6] = 0.0;  kernel[7] = 1.0;  kernel[8] = 2.0;

    // COLOR_DEFAULT_EXACT_BEGIN
    // Copied from the pre-angle/height shader: literal offsets and arithmetic
    // order intentionally stay intact so defaults never depend on trig folding.
    float2 offsets[9];
    offsets[0] = float2(-texelSize.x, -texelSize.y);
    offsets[1] = float2(0.0, -texelSize.y);
    offsets[2] = float2(texelSize.x, -texelSize.y);
    offsets[3] = float2(-texelSize.x, 0.0);
    offsets[4] = float2(0.0, 0.0);
    offsets[5] = float2(texelSize.x, 0.0);
    offsets[6] = float2(-texelSize.x, texelSize.y);
    offsets[7] = float2(0.0, texelSize.y);
    offsets[8] = float2(texelSize.x, texelSize.y);

    float3 conv = float3(0.0, 0.0, 0.0);
    for (int i = 0; i < 9; i++) {
        float3 texSample = nmSample(((uv + offsets[i] * amount * 1.0) * uv_size - float2(0.0, 0.0)) / uv_size).rgb;
        conv += texSample * kernel[i];
    }
    // COLOR_DEFAULT_EXACT_END
    return conv;
}

float3 colorGeneralEmboss(float2 uv, float2 texelSize) {
    float kernel[9];
    kernel[0] = -2.0; kernel[1] = -1.0; kernel[2] = 0.0;
    kernel[3] = -1.0; kernel[4] = 1.0;  kernel[5] = 1.0;
    kernel[6] = 0.0;  kernel[7] = 1.0;  kernel[8] = 2.0;

    float2 baseOffsetsPx[9];
    baseOffsetsPx[0] = float2(-1.0, -1.0);
    baseOffsetsPx[1] = float2( 0.0, -1.0);
    baseOffsetsPx[2] = float2( 1.0, -1.0);
    baseOffsetsPx[3] = float2(-1.0,  0.0);
    baseOffsetsPx[4] = float2( 0.0,  0.0);
    baseOffsetsPx[5] = float2( 1.0,  0.0);
    baseOffsetsPx[6] = float2(-1.0,  1.0);
    baseOffsetsPx[7] = float2( 0.0,  1.0);
    baseOffsetsPx[8] = float2( 1.0,  1.0);

    float theta = radians(angle - 135.0);
    float ct = cos(theta);
    float st = sin(theta);
    float3 conv = float3(0.0, 0.0, 0.0);
    for (int i = 0; i < 9; i++) {
        float2 basePx = baseOffsetsPx[i];
        float2 rotatedPx = float2(ct * basePx.x + st * basePx.y, -st * basePx.x + ct * basePx.y) * height;
        float2 offsetUV = rotatedPx * texelSize * amount * 1.0;
        float3 texSample = nmSample(((uv + offsetUV) * uv_size - float2(0.0, 0.0)) / uv_size).rgb;
        conv += texSample * kernel[i];
    }
    return conv;
}

float3 grayEmboss(float2 uv, float3 centerRGB) {
    float theta = radians(angle);
    // This direction is a backend-independent sample delta, so GLSL and WGSL
    // use the same constant-vector expansion.
    float2 direction = float2(cos(theta), sin(theta));
    float2 offsetUV = direction * (height * 1.0) / uv_size;
    float positiveLuma = dot(sampleGlobal(uv + offsetUV), LUMA);
    float negativeLuma = dot(sampleGlobal(uv - offsetUV), LUMA);
    float signedEdge = positiveLuma - negativeLuma;
    float edgeMagnitude = abs(signedEdge);
    float relief = 0.5 + 0.5 * signedEdge;

    float centerLuma = dot(centerRGB, LUMA);
    float3 sourceChroma = centerRGB - float3(centerLuma, centerLuma, centerLuma);
    float3 tracedColor = sourceChroma * edgeMagnitude * clamp(colorAmount / 100.0, 0.0, 1.0);
    return float3(relief, relief, relief) + tracedColor;
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 uv_size = uv_size;
    float2 uv = globalCoord / uv_size;
    float2 texelSize = 1.0 / uv_size;
    float4 origColor = nmSample((v_in.uv * uv_size) / uv_size);
    bool fullFrame = all(equal(float2(0.0, 0.0), float2(0.0, 0.0))) && all(equal(uv_size, uv_size));
    // Preserve the shipped full-frame sample delta exactly. A tiled input's
    // local texture is smaller than the print canvas, so only that path uses
    // the full-uv_size pixel delta before mapping back to local UVs.
    float2 colorTexelSize = fullFrame ? texelSize : 1.0 / uv_size;

    float3 result;
#if STYLE == 0
    if (angle == 135.0 && height == 1.0) {
        result = colorDefaultEmboss(uv, colorTexelSize);
    } else {
        result = colorGeneralEmboss(uv, colorTexelSize);
    }
#else
    result = grayEmboss(uv, origColor.rgb);
#endif

    fragColor = float4(clamp(result, 0.0, 1.0), origColor.a);
    return fragColor;
}
