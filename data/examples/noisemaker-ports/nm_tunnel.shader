// OBS HLSL adaptation of Noisemaker filter/tunnel/tunnel.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/tunnel
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// Noisemaker filter inputs use edge-clamped texture sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Perspective tunnel effect
 * Based on Inigo Quilez's tunnel shader
 * MIT License
 */
uniform int shape<
    string label = "Shape";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "circle";
    int option_1_value = 1;
    string option_1_label = "triangle";
    int option_2_value = 2;
    string option_2_label = "roundedRect";
    int option_3_value = 3;
    string option_3_label = "square";
    int option_4_value = 4;
    string option_4_label = "hexagon";
    int option_5_value = 5;
    string option_5_label = "octagon";
> = 0;
uniform float speed<
    string label = "Speed";
    string widget_type = "slider";
    float minimum = -5.0;
    float maximum = 5.0;
    float step = 0.01;
> = 1.0;
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
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.0;
uniform float center<
    string label = "Center";
    string widget_type = "slider";
    float minimum = -100.0;
    float maximum = 100.0;
    float step = 0.01;
> = 100.0;
uniform bool aspectLens<
    string label = "Aspect lens";
> = true;
uniform bool antialias<
    string label = "Antialias";
> = true;
#define PI 3.14159265359
#define TAU 6.28318530718

float polygonShape(float2 uv, int sides) {
    float a = atan(uv.x, uv.y) + PI;
    float r = TAU / float(sides);
    return cos(floor(0.5 + a / r) * r - a) * length(uv);
}

float2 smod(float2 v, float m) {
    return m * (0.75 - abs(frac(v) - 0.5) - 0.25);
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 texSize = uv_size;
    float2 tileDims = texSize;
    float2 fullRes = uv_size.x > 0.0 ? uv_size : tileDims;
    float2 uv = ((v_in.uv * uv_size) + float2(0.0, 0.0)) / fullRes;

    // Center the coordinates
    float2 centered = uv - 0.5;

    // Optional aspect ratio correction
    float aspectRatio = fullRes.x / fullRes.y;
    if (aspectLens) { centered.x *= aspectRatio; }

    float a = atan(centered.y, centered.x);
    float r;

    if (shape == 0) {
        // Circle
        r = length(centered);
    } else if (shape == 1) {
        // Triangle
        r = polygonShape(centered * 2.0, 3);
    } else if (shape == 2) {
        // Rounded square (superellipse)
        float2 p = centered * centered * centered * centered * centered * centered * centered * centered;
        r = pow(p.x + p.y, 1.0 / 8.0);
    } else if (shape == 3) {
        // Square
        r = polygonShape(centered * 2.0, 4);
    } else if (shape == 4) {
        // Hexagon
        r = polygonShape(centered * 2.0, 6);
    } else {
        // Octagon
        r = polygonShape(centered * 2.0, 8);
    }

    // Apply scale
    r -= scale * 0.15;

    // Create tunnel coordinates
    float2 tunnelCoords = smod(float2(
        0.3 / r + elapsed_time * speed,
        a / PI + elapsed_time * rotation
    ), 1.0);

    // Sample with optional supersampling
    float4 color;
    if (antialias) {
        float2 dx = ddx(tunnelCoords);
        float2 dy = ddy(tunnelCoords);
        color = float4(0.0, 0.0, 0.0, 0.0);
        color += nmSample(tunnelCoords + dx * -0.375 + dy * -0.125);
        color += nmSample(tunnelCoords + dx *  0.125 + dy * -0.375);
        color += nmSample(tunnelCoords + dx *  0.375 + dy *  0.125);
        color += nmSample(tunnelCoords + dx * -0.125 + dy *  0.375);
        color *= 0.25;
    } else {
        color = nmSample(tunnelCoords);
    }

    // Center vignette: smooth falloff to hide moiré at vanishing point
    if (center != 0.0) {
        float centerMask = smoothstep(0.0, 0.5, r);
        float amt = center / 100.0;
        if (amt < 0.0) {
            color.rgb *= lerp(1.0, centerMask, -amt);
        } else {
            color.rgb = lerp(color.rgb, float3(1.0, 1.0, 1.0), (1.0 - centerMask) * amt);
        }
    }

    fragColor = color;
    return fragColor;
}
