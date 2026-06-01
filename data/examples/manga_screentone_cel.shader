// Manga Screentone Cel — cel shading + halftone dots + cross-hatch shadows + ink outlines
// Common manga patterns: screentone (dots), hatching, limited palette, bold edges

uniform float Threshold<
    string label = "Shading Threshold";
    string widget_type = "slider";
    float minimum = 0.1;
    float maximum = 0.9;
    float step = 0.01;
> = 0.5;

uniform float DotSize<
    string label = "Dot Size";
    string widget_type = "slider";
    float minimum = 1.0;
    float maximum = 12.0;
    float step = 0.5;
> = 4.0;

uniform float HatchScale<
    string label = "Hatch Scale";
    string widget_type = "slider";
    float minimum = 1.0;
    float maximum = 20.0;
    float step = 0.5;
> = 8.0;

uniform float OutlineThickness<
    string label = "Outline Thickness";
    string widget_type = "slider";
    float minimum = 0.5;
    float maximum = 4.0;
    float step = 0.1;
> = 1.5;

uniform float4 InkColor<
    string label = "Ink Color";
> = { 0.05, 0.05, 0.1, 1.0 };

float4 mainImage(VertData v_in) : TARGET
{
    float4 src = image.Sample(textureSampler, v_in.uv);
    float lum = dot(src.rgb, float3(0.299, 0.587, 0.114));

    // Cel shading levels (manga limited palette)
    float3 cel;
    if (lum > Threshold * 1.2) cel = float3(1.0, 0.95, 0.9);       // highlight
    else if (lum > Threshold)     cel = float3(0.95, 0.85, 0.7);   // mid
    else if (lum > Threshold * 0.6) cel = float3(0.6, 0.5, 0.35);  // shadow1
    else                          cel = float3(0.25, 0.2, 0.15);   // shadow2

    // Halftone dots for midtones (classic manga screentone)
    float2 pixel = v_in.uv * uv_size;
    float dot = frac(sin(dot(floor(pixel / DotSize), float2(12.9898, 78.233))) * 43758.5453);
    float dotMask = smoothstep(0.4, 0.6, dot);
    if (lum > Threshold * 0.7 && lum < Threshold * 1.1)
        cel = lerp(cel, float3(0.9), dotMask * 0.6);

    // Cross-hatch for deep shadows (common manga technique)
    if (lum < Threshold * 0.55) {
        float hatch = sin(pixel.x / HatchScale) * sin(pixel.y / HatchScale);
        float hatch2 = sin((pixel.x + pixel.y) / (HatchScale * 0.7));
        float hatchMask = max(hatch, hatch2);
        cel *= 1.0 - smoothstep(-0.3, 0.3, hatchMask) * 0.5;
    }

    // Simple edge ink outline (manga bold lines)
    float2 off = OutlineThickness * uv_pixel_interval;
    float4 s1 = image.Sample(textureSampler, v_in.uv + float2(off.x, 0));
    float4 s2 = image.Sample(textureSampler, v_in.uv + float2(0, off.y));
    float lum1 = s1.r * 0.299 + s1.g * 0.587 + s1.b * 0.114;
    float lum2 = s2.r * 0.299 + s2.g * 0.587 + s2.b * 0.114;
    float edge = abs(lum - lum1) + abs(lum - lum2);
    float ink = smoothstep(0.02, 0.08, edge);
    float3 final = lerp(cel, InkColor.rgb, ink * InkColor.a);

    return float4(final, src.a);
}
