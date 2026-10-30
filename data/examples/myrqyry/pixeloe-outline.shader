// PixelOE Build 2 — contrast-aware outline expansion stage, adapted for OBS.
// Source: https://github.com/Koishi-Star/PixelOEwithC
// Based on build2/outline.frag at 2546d6e8b8c01be2ef18969bca034c919bdb11a2.
// Modified for OBS Shaderfilter. Copyright (c) KohakuBlueleaf.
// Licensed under Apache-2.0; see pixeloe-ports/LICENSE-APACHE-2.0.txt.
// Attach as the first Shaderfilter filter, before pixeloe-pixelize.shader.
// This is a file-backed standard-wrapper .shader, not a full .effect.

uniform float Pixel_Size<
    string label = "Pixel Size";
    string group = "PixelOE Outline";
    string widget_type = "slider";
    float minimum = 1.0;
    float maximum = 12.0;
    float step = 1.0;
> = 6.0;

uniform float Thickness<
    string label = "Outline Thickness";
    string group = "PixelOE Outline";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 6.0;
    float step = 1.0;
> = 2.0;

uniform float Average_Scale<
    string label = "Average Contrast Scale";
    string group = "PixelOE Outline";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 20.0;
    float step = 0.1;
> = 10.0;

uniform float Distance_Scale<
    string label = "Contrast Distance Scale";
    string group = "PixelOE Outline";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 8.0;
    float step = 0.1;
> = 3.0;

uniform float Effect_Mix<
    string label = "Effect Mix";
    string group = "Output";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;

float3 sampleRgb(float2 uv)
{
    return image.Sample(textureSampler, uv).rgb;
}

float luminance(float3 color)
{
    return dot(color, float3(0.299, 0.587, 0.114));
}

float contrastWeight(float2 uv, int kernelSize)
{
    float2 texel = uv_pixel_interval;
    int halfKernel = kernelSize / 2;
    float maximum = 0.0;
    float minimum = 1.0;
    float sum = 0.0;
    int count = 0;

    [loop]
    for (int y = -halfKernel; y <= halfKernel; y++) {
        [loop]
        for (int x = -halfKernel; x <= halfKernel; x++) {
            float value = luminance(sampleRgb(uv + float2(x, y) * texel));
            maximum = max(maximum, value);
            minimum = min(minimum, value);
            sum += value;
            count++;
        }
    }

    float average = sum / max(float(count), 1.0);
    float brightDistance = maximum - average;
    float darkDistance = average - minimum;
    float weight = (average - 0.5) * Average_Scale
        - (brightDistance - darkDistance) * Distance_Scale;
    return 1.0 / (1.0 + exp(-clamp(weight, -20.0, 20.0)));
}

float3 morphology(float2 uv, int radius, bool expand)
{
    float3 result = expand ? float3(0.0, 0.0, 0.0) : float3(1.0, 1.0, 1.0);
    float radiusSquared = float(radius * radius);
    [loop]
    for (int y = -radius; y <= radius; y++) {
        [loop]
        for (int x = -radius; x <= radius; x++) {
            if (float(x * x + y * y) <= radiusSquared) {
                float3 c = sampleRgb(uv + float2(x, y) * uv_pixel_interval);
                result = expand ? max(result, c) : min(result, c);
            }
        }
    }
    return result;
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float4 original = image.Sample(textureSampler, uv);
    int pixelSize = clamp(int(Pixel_Size + 0.5), 1, 12);
    int radius = clamp(int(Thickness + 0.5), 0, 6);
    if (radius == 0) return original;

    float weight = contrastWeight(uv, pixelSize);
    float3 eroded = morphology(uv, radius, false);
    float3 dilated = morphology(uv, radius, true);
    float3 outlined = lerp(dilated, eroded, weight);

    // Preserve the source's sequential cleanup intent without feeding a
    // previous frame back into the same-frame filter chain.
    if (radius > 1) {
        outlined = morphology(uv, radius, false);
        outlined = morphology(uv, radius, true);
        outlined = morphology(uv, radius, false);
    }
    return float4(lerp(original.rgb, outlined, saturate(Effect_Mix)), original.a);
}
