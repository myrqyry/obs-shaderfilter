// OBS HLSL adaptation of Noisemaker filter/prismaticAberration/prismaticAberration.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/prismaticAberration
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// Noisemaker filter inputs use edge-clamped texture sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}
float nmMod1(float x, float m) { return x - m * floor(x / m); }


/*
 * Prismatic aberration effect.
 * Ported from classicNoisedeck/lensDistortion.
 */
uniform float aberrationAmt<
    string label = "Aberration amt";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 0.01;
> = 50.0;
uniform float hueRotation<
    string label = "Hue rotation";
    string widget_type = "slider";
    float minimum = -180.0;
    float maximum = 180.0;
    float step = 0.01;
> = 0.0;
uniform float hueRange<
    string label = "Hue range";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 0.01;
> = 0.0;
uniform bool modulate<
    string label = "Modulate";
> = false;
uniform float saturation<
    string label = "Saturation";
    string widget_type = "slider";
    float minimum = -100.0;
    float maximum = 100.0;
    float step = 0.01;
> = 0.0;
uniform float passthru<
    string label = "Passthru";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 0.01;
> = 50.0;
#define PI 3.14159265359
#define TAU 6.28318530718
#define aspectRatio uv_size.x / uv_size.y

float map(float value, float inMin, float inMax, float outMin, float outMax) {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

float3 hsv2rgb(float3 hsv) {
    float h = frac(hsv.x);
    float s = hsv.y;
    float v = hsv.z;

    float c = v * s; // Chroma
    float x = c * (1.0 - abs(nmMod1(h * 6.0, 2.0) - 1.0));
    float m = v - c;

    float3 rgb;

    if (0.0 <= h && h < 1.0/6.0) {
        rgb = float3(c, x, 0.0);
    } else if (1.0/6.0 <= h && h < 2.0/6.0) {
        rgb = float3(x, c, 0.0);
    } else if (2.0/6.0 <= h && h < 3.0/6.0) {
        rgb = float3(0.0, c, x);
    } else if (3.0/6.0 <= h && h < 4.0/6.0) {
        rgb = float3(0.0, x, c);
    } else if (4.0/6.0 <= h && h < 5.0/6.0) {
        rgb = float3(x, 0.0, c);
    } else if (5.0/6.0 <= h && h < 1.0) {
        rgb = float3(c, 0.0, x);
    } else {
        rgb = float3(0.0, 0.0, 0.0);
    }

    return rgb + float3(m, m, m);
}

float3 rgb2hsv(float3 rgb) {
    float r = rgb.r;
    float g = rgb.g;
    float b = rgb.b;

    float max = max(r, max(g, b));
    float min = min(r, min(g, b));
    float delta = max - min;

    float h = 0.0;
    if (delta != 0.0) {
        if (max == r) {
            h = nmMod1((g - b) / delta, 6.0) / 6.0;
        } else if (max == g) {
            h = ((b - r) / delta + 2.0) / 6.0;
        } else if (max == b) {
            h = ((r - g) / delta + 4.0) / 6.0;
        }
    }

    float s = (max == 0.0) ? 0.0 : delta / max;
    float v = max;

    return float3(h, s, v);
}

float3 saturate(float3 color) {
    float sat = map(saturation, -100.0, 100.0, -1.0, 1.0);
    float avg = (color.r + color.g + color.b) / 3.0;
    color -= (avg - color) * sat;
    return color;
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 uv = globalCoord / uv_size;
    float2 fullRes = uv_size.x > 0.0 ? uv_size : uv_size;
    float2 globalUV = ((v_in.uv * uv_size) + float2(0.0, 0.0)) / fullRes;
    float globalAspect = fullRes.x / fullRes.y;

    float4 color = float4(0.0, 0.0, 0.0, 1.0);

    float2 diff = float2(0.5 * globalAspect, 0.5) - float2(globalUV.x * globalAspect, globalUV.y);
    float centerDist = length(diff);

    // No distortion/zoom
    float2 lensedCoords = uv;

    float aberrationOffset = map(aberrationAmt, 0.0, 100.0, 0.0, 0.05) * centerDist * PI * 0.5;

    float2 texelSize = 1.0 / uv_size;

    float redOffset = lerp(clamp(lensedCoords.x + aberrationOffset, 0.0, 1.0), lensedCoords.x, lensedCoords.x);
    float2 redUV = float2(redOffset, lensedCoords.y);
    float2 redLocalUV = (redUV * uv_size - float2(0.0, 0.0)) * texelSize;
    float4 red = nmSample(redLocalUV);

    float2 greenLocalUV = (lensedCoords * uv_size - float2(0.0, 0.0)) * texelSize;
    float4 green = nmSample(greenLocalUV);

    float blueOffset = lerp(lensedCoords.x, clamp(lensedCoords.x - aberrationOffset, 0.0, 1.0), lensedCoords.x);
    float2 blueUV = float2(blueOffset, lensedCoords.y);
    float2 blueLocalUV = (blueUV * uv_size - float2(0.0, 0.0)) * texelSize;
    float4 blue = nmSample(blueLocalUV);

    // from aberration
    float3 hsv = float3(1.0, 1.0, 1.0);

    float t = modulate ? elapsed_time : 0.0;

    // prismatic - get edges
    color = float4(length(float4(red.r, green.g, blue.b, color.a) - green)) * green;
    color.a = green.a;

    // boost hue range of edges
    hsv = rgb2hsv(color.rgb);
    hsv[0] = frac(((hsv[0] + 0.125 + (1.0 - (hueRotation / 360.0))) * (2.0 + hueRange * 0.05)) + t);
    hsv[1] = 1.0;

    // desaturate original
    green.rgb = saturate(green.rgb) * map(passthru, 0.0, 100.0, 0.0, 2.0);

    // recombine (add)
    color.rgb = min(green.rgb + hsv2rgb(hsv), 1.0);

    fragColor = color;
    return fragColor;
}
