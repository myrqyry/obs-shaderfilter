// Orphic Hyperdrive — OBS ShaderFilter port.
// Based on ORPHIC/js/scene-hyperdrive.js (Aditya Rajashekaran, 2026).
// https://github.com/adityarajashekaran/orphic
// SPDX-License-Identifier: AGPL-3.0-or-later
// Retains the polar tunnel/spokes, derivative fade, star streaks and chromatic
// depth offset. The original beat-event ring queue and integrated audio-driven
// travel are NOT available in ShaderFilter; rings here run periodically.

uniform float audio_peak;
uniform float audio_magnitude;
uniform float Speed<
    string label = "Travel speed";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 7.0; float step = 0.1;
> = 1.7;
uniform float Twist<
    string label = "Twist speed";
    string widget_type = "slider";
    float minimum = -1.0; float maximum = 1.0; float step = 0.01;
> = 0.08;
uniform float Spokes<
    string label = "Spoke pairs";
    string widget_type = "slider";
    float minimum = 3.0; float maximum = 20.0; float step = 1.0;
> = 8.0;
uniform float Hue<
    string label = "Palette phase";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.17;
uniform float Rings<
    string label = "Periodic ring intensity";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 2.5; float step = 0.05;
> = 0.65;
uniform float Audio_Gain<
    string label = "Audio response";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 4.0; float step = 0.1;
> = 1.7;
uniform float Chromatic_Aberration<
    string label = "Chromatic depth shift";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.09; float step = 0.005;
> = 0.025;
uniform float Brightness<
    string label = "Brightness";
    string widget_type = "slider";
    float minimum = 0.2; float maximum = 3.0; float step = 0.05;
> = 1.0;
uniform float Mix_With_Source<
    string label = "Mix with source (1 = pattern)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.9;
float2 hash22_orphic(float2 p) {
    float3 p3 = frac(float3(p.x, p.y, p.x) *
                       float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.xx + p3.yz) * p3.zy);
}
float3 pal_orphic(float t, float3 a, float3 b, float3 c, float3 d) {
    return a + b * cos(6.28318 * (c * t + d));
}
float3 aces_orphic(float3 x) {
    x = max(x, float3(0.0, 0.0, 0.0));
    return saturate((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14));
}
float3 tunnel_orphic(float2 uv, float chroma, float travel,
                     float spin, float level, float hit) {
    float r = length(uv) + 0.0001;
    float ang = atan2(uv.y, uv.x);
    float depth = 0.35 / r + travel + chroma;
    float a = ang + spin + sin(depth * 0.30) * 0.18;
    float lon = pow(abs(sin(a * Spokes)), 36.0);
    float lat = pow(abs(sin(depth * 4.7)), 30.0);
    float derivative = abs(ddx(depth)) + abs(ddy(depth));
    float fade = exp(-pow(derivative * 1.8, 2.0));
    float lattice = (lon*(0.35+level*0.55) + lat*1.1 + lon*lat*2.5)*fade;
    float hue = Hue + depth*0.03 + travel*0.012;
    float3 col = pal_orphic(hue, float3(0.5,0.5,0.5),
        float3(0.5,0.5,0.5), float3(1,1,1), float3(0,0.33,0.67)) * lattice;
    // Uniform depth-spaced rings: deterministic periodic alternative to beat queue.
    float latticeRing = pow(abs(sin(depth * 0.85)), 22.0) * fade;
    col += pal_orphic(hue + 0.5, float3(0.6,0.6,0.6),
        float3(0.4,0.4,0.4), float3(1,1,1), float3(0,0.33,0.67))
        * latticeRing * Rings * (0.4+hit*1.2);
    float bx = (ang/6.28318 + 0.5)*90.0;
    float2 h = hash22_orphic(float2(floor(bx), 7.0));
    float prof = exp(-pow((frac(bx)-0.5)*6.0, 2.0));
    float along = frac(depth*(0.55+h.y*0.5)+h.x*7.0);
    float streak = prof*pow(1.0-along,12.0)*fade;
    col += float3(0.85,0.92,1.0)*streak*(0.25+level*0.65);
    col *= smoothstep(0.04,0.45,r)*0.92 + 0.08;
    col += col*0.18/(r*4.0+0.4);
    return col;
}
float4 mainImage(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 src = image.Sample(textureSampler, uv);
    float level = saturate(audio_magnitude*Audio_Gain);
    float hit = saturate(audio_peak*Audio_Gain);
    float2 p = (uv-0.5)*float2(uv_size.x/max(uv_size.y,1.0),1.0);
    p *= 1.0-hit*0.05;
    float travel = elapsed_time*Speed;
    float spin = elapsed_time*Twist;
    float ca = hit*Chromatic_Aberration;
    float3 col = float3(
       tunnel_orphic(p, ca, travel, spin, level, hit).r,
       tunnel_orphic(p, 0.0, travel, spin, level, hit).g,
       tunnel_orphic(p,-ca, travel, spin, level, hit).b);
    float3 coreColor = lerp(
        pal_orphic(Hue+travel*0.012+0.5, float3(0.6,0.6,0.6),
            float3(0.4,0.4,0.4), float3(1,1,1), float3(0,0.33,0.67)),
        float3(1,1,1), 0.55);
    float d2 = dot(p,p);
    col += coreColor*(exp(-d2*260.0)+exp(-d2*40.0)*0.18)
        *(0.45+hit*0.9+level*0.35);
    col *= (0.45+level)*Brightness;
    float2 d = uv-0.5;
    col *= 1.0-dot(d,d)*0.6;
    col *= 0.94+0.06*sin(uv.y*uv_size.y*1.8);
    col = aces_orphic(col);
    float a = saturate(Mix_With_Source);
    return float4(lerp(src.rgb,col,a),lerp(src.a,1.0,a));
}
