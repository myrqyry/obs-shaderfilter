// PixelOE Build 2 — contrast-aware pixel selection stage, adapted for OBS.
// Source: https://github.com/Koishi-Star/PixelOEwithC
// Based on build2/pixelize.frag at 2546d6e8b8c01be2ef18969bca034c919bdb11a2.
// Modified for OBS Shaderfilter. Copyright (c) KohakuBlueleaf.
// Licensed under Apache-2.0; see pixeloe-ports/LICENSE-APACHE-2.0.txt.
// Attach after pixeloe-outline.shader for the original two-stage ordering.
// This is a file-backed standard-wrapper .shader, not a full .effect.

uniform float Pixel_Size<
    string label = "Pixel Size";
    string group = "PixelOE Pixelize";
    string widget_type = "slider";
    float minimum = 1.0;
    float maximum = 16.0;
    float step = 1.0;
> = 6.0;

uniform bool Show_Original<
    string label = "Show Original";
    string group = "PixelOE Pixelize";
> = false;

uniform float Denoise_Strength<
    string label = "Integrated Denoise";
    string group = "Noise Reduction";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;

uniform float Denoise_Color_Sigma<
    string label = "Denoise Color Similarity";
    string group = "Noise Reduction";
    string widget_type = "slider";
    float minimum = 0.02;
    float maximum = 0.5;
    float step = 0.01;
> = 0.25;

uniform float Denoise_Spatial_Sigma<
    string label = "Denoise Spatial Radius";
    string group = "Noise Reduction";
    string widget_type = "slider";
    float minimum = 0.5;
    float maximum = 2.0;
    float step = 0.05;
> = 1.25;

uniform float Color_Quantization<
    string label = "Color Quantization";
    string group = "Palette and Dither";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.0;

uniform float Color_Levels<
    string label = "Color Levels per Channel";
    string group = "Palette and Dither";
    string widget_type = "slider";
    float minimum = 2.0;
    float maximum = 32.0;
    float step = 1.0;
> = 8.0;

uniform float Dither_Strength<
    string label = "Ordered Dither Strength";
    string group = "Palette and Dither";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.5;

uniform float Effect_Mix<
    string label = "Effect Mix";
    string group = "Output";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;

float3 rgbToPixelOEColor(float3 rgb)
{
    return float3(rgb.r * 0.299 + rgb.g * 0.587 + rgb.b * 0.114,
                  0.5 + 0.5 * (rgb.r - rgb.g),
                  0.5 + 0.5 * (rgb.g - rgb.b));
}

float bayer4x4(int x, int y)
{
    int ix = x % 4;
    int iy = y % 4;
    if (iy == 0) {
        if (ix == 0) return 0.0;
        if (ix == 1) return 8.0;
        if (ix == 2) return 2.0;
        return 10.0;
    }
    if (iy == 1) {
        if (ix == 0) return 12.0;
        if (ix == 1) return 4.0;
        if (ix == 2) return 14.0;
        return 6.0;
    }
    if (iy == 2) {
        if (ix == 0) return 3.0;
        if (ix == 1) return 11.0;
        if (ix == 2) return 1.0;
        return 9.0;
    }
    if (ix == 0) return 15.0;
    if (ix == 1) return 7.0;
    if (ix == 2) return 13.0;
    return 5.0;
}

float3 bilateralDenoiseSample(float2 uv, float3 center)
{
    if (Denoise_Strength <= 0.0) return center;

    float colorSigma = max(Denoise_Color_Sigma, 0.001);
    float spatialSigma = max(Denoise_Spatial_Sigma, 0.1);
    float3 sum = center;
    float totalWeight = 1.0;

    // Compact cross-shaped bilateral kernel: smooth isolated noise while
    // reducing contributions from neighboring samples across color edges.
    [loop]
    for (int i = 0; i < 4; i++) {
        float2 offset = (i == 0) ? float2(-1.0, 0.0)
            : (i == 1) ? float2(1.0, 0.0)
            : (i == 2) ? float2(0.0, -1.0) : float2(0.0, 1.0);
        float2 sampleUv = clamp(uv + offset * uv_pixel_interval,
            uv_pixel_interval * 0.5, 1.0 - uv_pixel_interval * 0.5);
        float3 sampleColor = image.Sample(textureSampler, sampleUv).rgb;
        float3 colorDelta = sampleColor - center;
        float colorDistance = dot(colorDelta, colorDelta);
        float spatialDistance = dot(offset, offset);
        float weight = exp(-0.5 * (colorDistance / (colorSigma * colorSigma)
            + spatialDistance / (spatialSigma * spatialSigma)));
        sum += sampleColor * weight;
        totalWeight += weight;
    }

    float3 filtered = sum / max(totalWeight, 0.000001);
    return lerp(center, filtered, saturate(Denoise_Strength));
}

float3 chooseContrastPixel(float2 blockStart, int blockSize)
{
    float2 texel = uv_pixel_interval;
    float2 centerUv = blockStart + float2(blockSize * 0.5, blockSize * 0.5) * texel;
    float3 center = bilateralDenoiseSample(centerUv,
        image.Sample(textureSampler, centerUv).rgb);
    float centerLuma = rgbToPixelOEColor(center).x;
    float maximum = 0.0;
    float minimum = 1.0;
    float sum = 0.0;
    float3 maximumColor = float3(0.0, 0.0, 0.0);
    float3 minimumColor = float3(1.0, 1.0, 1.0);

    [loop]
    for (int y = 0; y < blockSize; y++) {
        [loop]
        for (int x = 0; x < blockSize; x++) {
            float2 sampleUv = blockStart + float2(x, y) * texel;
            float3 sampleColor = bilateralDenoiseSample(sampleUv,
                image.Sample(textureSampler, sampleUv).rgb);
            float value = rgbToPixelOEColor(sampleColor).x;
            if (value > maximum) {
                maximum = value;
                maximumColor = sampleColor;
            }
            if (value < minimum) {
                minimum = value;
                minimumColor = sampleColor;
            }
            sum += value;
        }
    }

    float average = sum / max(float(blockSize * blockSize), 1.0);
    if (centerLuma < average && (maximum - centerLuma) > (centerLuma - minimum)) {
        return minimumColor;
    }
    if (centerLuma > average && (maximum - centerLuma) < (centerLuma - minimum)) {
        return maximumColor;
    }
    return center;
}

float4 mainImage(VertData v_in) : TARGET
{
    float4 original = image.Sample(textureSampler, v_in.uv);
    if (Show_Original) return original;

    int blockSize = clamp(int(Pixel_Size + 0.5), 1, 16);
    float2 pixelPosition = v_in.uv * uv_size;
    float2 blockPixelStart = floor(pixelPosition / float(blockSize)) * float(blockSize);
    float2 blockStart = blockPixelStart / uv_size;
    float3 selected = chooseContrastPixel(blockStart, blockSize);
    if (Color_Quantization > 0.0) {
        float levels = max(Color_Levels - 1.0, 1.0);
        float2 blockIndex = floor(pixelPosition / float(blockSize));
        float threshold = (bayer4x4(int(blockIndex.x), int(blockIndex.y)) / 16.0
            - 0.5) * saturate(Dither_Strength);
        float3 quantized = floor(saturate(selected) * levels + 0.5 + threshold)
            / levels;
        selected = lerp(selected, quantized, saturate(Color_Quantization));
    }
    return float4(lerp(original.rgb, selected, saturate(Effect_Mix)), original.a);
}
