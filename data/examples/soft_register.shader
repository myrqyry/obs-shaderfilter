// Soft Register — two misregistered, rotating ink screens for live OBS imagery.
// Based on Glyphfield's "Soft Register" material technique (MIT):
// https://github.com/Kevin-Liu-01/Glyphfield/blob/main/src/lib/originalMaterialShaders.ts
// Reworked as an image-aware ShaderFilter HLSL filter (NOT a procedural backdrop).
// RGB processing uses the incoming source's luminance; original alpha is preserved.

uniform float print_mix<
    string label = "Print Mix";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 1.0;

uniform float dot_spacing<
    string label = "Screen Dot Spacing (px at 900p)";
    string widget_type = "slider";
    float minimum = 5.0; float maximum = 36.0; float step = 1.0;
> = 12.0;

uniform float registration_x<
    string label = "Registration X (px at 900p)";
    string widget_type = "slider";
    float minimum = -15.0; float maximum = 15.0; float step = 0.25;
> = 2.0;

uniform float registration_y<
    string label = "Registration Y (px at 900p)";
    string widget_type = "slider";
    float minimum = -15.0; float maximum = 15.0; float step = 0.25;
> = -1.5;

uniform float angle_a<
    string label = "Ink A Angle";
    string widget_type = "slider";
    float minimum = -90.0; float maximum = 90.0; float step = 1.0;
> = 15.0;

uniform float angle_b<
    string label = "Ink B Angle";
    string widget_type = "slider";
    float minimum = -90.0; float maximum = 90.0; float step = 1.0;
> = 75.0;

uniform float contrast<
    string label = "Print Contrast";
    string widget_type = "slider";
    float minimum = 0.5; float maximum = 2.5; float step = 0.05;
> = 1.3;

uniform float4 ink_a<
    string label = "Ink A (deep)";
> = {0.13, 0.25, 0.31, 1.0};

uniform float4 ink_b<
    string label = "Ink B (warm)";
> = {0.77, 0.34, 0.24, 1.0};

uniform float4 paper_color<
    string label = "Paper";
> = {0.96, 0.93, 0.86, 1.0};

// Screen in reference-height pixels, making dots stable between preview
// and full-resolution output. fwidth softens coverage when dots shrink.
float softRegisterDots(float2 pos, float degrees, float spacing, float tone) {
    float a = degrees * 0.017453292519943;
    float c = cos(a), s = sin(a);
    float2 rotated = float2(c * pos.x - s * pos.y,
                            s * pos.x + c * pos.y) / max(spacing, 1.0);
    float2 local = frac(rotated) - 0.5;
    float distanceToCenter = length(local);
    float radius = sqrt(saturate(tone)) * 0.66;
    float edgeWidth = max(length(float2(ddx(rotated.x), ddy(rotated.y))), 0.001);
    float dots = 1.0 - smoothstep(radius - edgeWidth, radius + edgeWidth, distanceToCenter);
    // When screens become subpixel, converge to the tone rather than alias.
    return lerp(dots, tone, smoothstep(0.22, 0.48, edgeWidth));
}

float4 mainImage(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 source = image.Sample(textureSampler, uv);
    if (print_mix <= 0.0001 || source.a <= 0.0001)
        return source;

    float luma = dot(source.rgb, float3(0.2126, 0.7152, 0.0722));
    luma = saturate((luma - 0.5) * contrast + 0.5);
    float deepInk = 1.0 - smoothstep(0.10, 0.83, luma);
    float warmInk = (1.0 - smoothstep(0.20, 0.95, luma)) * 0.73;

    // Stable physical screen spacing, not stretch-to-viewport pattern.
    float2 point = uv * max(uv_size, float2(1.0, 1.0)) *
                   (900.0 / max(uv_size.y, 1.0));
    float screenA = softRegisterDots(point, angle_a, dot_spacing, deepInk);
    float screenB = softRegisterDots(point + float2(registration_x, registration_y),
                                     angle_b, dot_spacing, warmInk);
    float3 paper = saturate(paper_color.rgb);
    float3 printed = paper;
    printed *= lerp(float3(1.0, 1.0, 1.0),
                    saturate(ink_a.rgb / max(paper, float3(0.04, 0.04, 0.04))),
                    screenA * 0.93);
    printed *= lerp(float3(1.0, 1.0, 1.0),
                    saturate(ink_b.rgb / max(paper, float3(0.04, 0.04, 0.04))),
                    screenB * 0.86);
    // Retain a faint wash from the source so the print respects image colors.
    printed = lerp(printed, printed * saturate(source.rgb * 1.1 + 0.18), 0.12);
    return float4(lerp(source.rgb, saturate(printed), saturate(print_mix)),
                  source.a);
}
