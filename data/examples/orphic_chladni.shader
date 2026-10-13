// Orphic Chladni Resonance — OBS ShaderFilter port.
// Based on ORPHIC/js/scene-chladni-resonance.js (Aditya Rajashekaran, 2026).
// https://github.com/adityarajashekaran/orphic
// SPDX-License-Identifier: AGPL-3.0-or-later
// Port: original three-wave nodal geometry, procedural coloring, and shimmer.
// Adaptation: ShaderFilter provides loudness/peak, not FFT bands or beat events.
// Load as a normal file-backed .shader with the standard template (not full effect).

uniform float audio_peak;
uniform float audio_magnitude;

uniform int Mode_Set<
    string label = "Resonant mode set";
    string widget_type = "select";
    int option_0_value = 0; string option_0_label = "3:5 / 2:7 / 4:6";
    int option_1_value = 1; string option_1_label = "2:5 / 3:7 / 4:9";
    int option_2_value = 2; string option_2_label = "3:8 / 5:7 / 2:9";
> = 0;
uniform float Scale<
    string label = "Plate scale";
    string widget_type = "slider";
    float minimum = 0.35; float maximum = 3.0; float step = 0.05;
> = 1.1;
uniform float Rotation_Speed<
    string label = "Rotation";
    string widget_type = "slider";
    float minimum = -0.3; float maximum = 0.3; float step = 0.01;
> = 0.04;
uniform float Nodal_Sharpness<
    string label = "Nodal sharpness";
    string widget_type = "slider";
    float minimum = 4.0; float maximum = 32.0; float step = 1.0;
> = 14.0;
uniform float Warp_Amount<
    string label = "Liquid shimmer";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.15; float step = 0.005;
> = 0.022;
uniform float Audio_Gain<
    string label = "Audio response";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 4.0; float step = 0.1;
> = 1.7;
uniform float Hue<
    string label = "Palette phase";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.12;
uniform float Glow<
    string label = "Nodal glow";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 3.0; float step = 0.05;
> = 1.25;
uniform float Plate_Fill<
    string label = "Interference fill";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.02;
> = 0.28;
uniform float Mix_With_Source<
    string label = "Mix with source (1 = pattern)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.9;

#define ORPHIC_PI 3.14159265
float chladni(float2 p, float n, float m) {
    return cos(n * ORPHIC_PI * p.x) * cos(m * ORPHIC_PI * p.y)
         - cos(m * ORPHIC_PI * p.x) * cos(n * ORPHIC_PI * p.y);
}
float3 cosine_palette(float t, float3 a, float3 b, float3 c, float3 d) {
    return a + b * cos(6.2831853 * (c * t + d));
}
float noise_hash(float2 p) {
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}
float noise_value(float2 p) {
    float2 i = floor(p), f = frac(p);
    f = f * f * (3.0 - 2.0 * f);
    return lerp(lerp(noise_hash(i), noise_hash(i + float2(1, 0)), f.x),
                lerp(noise_hash(i + float2(0, 1)), noise_hash(i + 1.0), f.x), f.y);
}
float fbm_small(float2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; ++i) {
        v += amp * noise_value(p);
        p = p * 2.03 + 13.7;
        amp *= 0.5;
    }
    return v;
}
float3 tonemap_aces(float3 x) {
    x = max(x, float3(0.0, 0.0, 0.0));
    return saturate((x * (2.51 * x + 0.03)) /
                    (x * (2.43 * x + 0.59) + 0.14));
}
float4 mainImage(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 src = image.Sample(textureSampler, uv);
    float2 p = (uv - 0.5) * float2(uv_size.x / max(uv_size.y, 1.0), 1.0) * Scale;
    float level = saturate(audio_magnitude * Audio_Gain);
    float hit = saturate(audio_peak * Audio_Gain);
    float t = elapsed_time;
    float ang = t * Rotation_Speed;
    float cs = cos(ang), sn = sin(ang);
    p = float2(cs * p.x - sn * p.y, sn * p.x + cs * p.y);
    float2 warp = float2(fbm_small(p * 3.0 + t * 0.1),
                         fbm_small(p * 3.0 - t * 0.13)) - 0.5;
    p += warp * (Warp_Amount + hit * 0.018);
    float n1 = 3.0, m1 = 5.0, n2 = 2.0, m2 = 7.0, n3 = 4.0, m3 = 6.0;
    if (Mode_Set == 1) {
        n1=2.0; m1=5.0; n2=3.0; m2=7.0; n3=4.0; m3=9.0;
    } else if (Mode_Set == 2) {
        n1=3.0; m1=8.0; n2=5.0; m2=7.0; n3=2.0; m3=9.0;
    }
    float w = chladni(p, n1, m1) * (0.35 + level * 0.65)
            + chladni(p, n2, m2) * (0.25 + level * 0.35)
            + chladni(p, n3, m3) * (0.18 + hit * 0.35);
    float line = exp(-abs(w) * max(4.0, Nodal_Sharpness - level * 3.0));
    float fill = 0.5 + 0.5 * sin(w * 2.2);
    float hue = Hue + t * 0.006 + length(p) * 0.06;
    float3 line_color = cosine_palette(hue, float3(0.55, 0.55, 0.55),
        float3(0.45, 0.45, 0.45), float3(1, 1, 1), float3(0, 0.33, 0.67));
    float3 fill_color = cosine_palette(hue + 0.45, float3(0.20, 0.20, 0.20),
        float3(0.18, 0.18, 0.18), float3(1, 1, 1), float3(0, 0.33, 0.67));
    float grain = noise_hash(floor(p * uv_size.y * 0.7) + floor(t * 24.0));
    float3 col = fill_color * fill * fill * 0.7 * Plate_Fill;
    col += line_color * line * (0.8 + hit * 1.5) * Glow;
    col += line_color * line * step(0.93, grain) * (0.1 + hit * 0.65);
    float2 d = uv - 0.5;
    col *= 1.0 - saturate(dot(d, d) * 1.1);
    col *= 0.65 + level * 0.45;
    col = tonemap_aces(col);
    float mixAmount = saturate(Mix_With_Source);
    return float4(lerp(src.rgb, col, mixAmount), lerp(src.a, 1.0, mixAmount));
}
