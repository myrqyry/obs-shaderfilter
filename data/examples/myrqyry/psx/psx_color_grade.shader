// PSX / Color Grade
// OBS Shaderfilter standard template. Artist-directed screen-space fog,
// 5-bit-like quantization, ordered dithering, gamma/contrast/saturation.
// Fog is an image-height gradient (no geometry depth buffer).

uniform int Color_Bits<
    string label = "Color bits per channel";
    string widget_type = "slider";
    int minimum = 2; int maximum = 8; int step = 1;
> = 5;
uniform float Dither_Amount<
    string label = "Dither amount";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.5; float step = 0.05;
> = 0.65;
uniform float Gamma<
    string label = "Gamma";
    string widget_type = "slider";
    float minimum = 0.5; float maximum = 2.0; float step = 0.05;
> = 1.0;
uniform float Contrast<
    string label = "Contrast";
    string widget_type = "slider";
    float minimum = 0.5; float maximum = 1.8; float step = 0.05;
> = 1.08;
uniform float Saturation<
    string label = "Saturation";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.8; float step = 0.05;
> = 0.90;
uniform float Fog_Amount<
    string label = "Lower-screen color fog";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.18;
uniform float Fog_Start<
    string label = "Fog begins at image height";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.95; float step = 0.01;
> = 0.30;
uniform float4 Fog_Color<
    string label = "Fog color";
> = {0.33, 0.38, 0.48, 1.0};
uniform float Mix<
    string label = "Effect strength";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 1.0;

float psx_grade_b2(float x, float y) {
    return 2.0 * x + 3.0 * y - 4.0 * x * y;
}
float psx_grade_bayer(float2 coords) {
    float2 p = floor(coords);
    p -= 4.0 * floor(p / 4.0);
    float2 a = p - 2.0 * floor(p / 2.0);
    float2 b = floor(p / 2.0);
    return (4.0 * psx_grade_b2(a.x, a.y) + psx_grade_b2(b.x, b.y) - 7.5) / 16.0;
}

float4 mainImage(VertData v_in) : TARGET {
    float4 src = image.Sample(textureSampler, v_in.uv);
    if (Mix <= 0.0 || src.a <= 0.001) return src;

    float3 col = saturate(src.rgb);
    float y = dot(col, float3(0.299, 0.587, 0.114));
    col = lerp(float3(y, y, y), col, Saturation);
    col = saturate((col - 0.5) * Contrast + 0.5);
    col = pow(col, float3(1.0 / max(Gamma, 0.01), 1.0 / max(Gamma, 0.01), 1.0 / max(Gamma, 0.01)));

    // A deliberate stylized screen-space wash, not depth-derived fog.
    float fog = saturate((v_in.uv.y - Fog_Start) / max(1.0 - Fog_Start, 0.01)) * Fog_Amount;
    col = lerp(col, Fog_Color.rgb, fog);

    float levels = pow(2.0, float(Color_Bits)) - 1.0;
    float2 pixels = v_in.uv * max(uv_size, float2(1.0, 1.0));
    float noise = psx_grade_bayer(pixels);
    col = saturate(floor(saturate(col) * levels + 0.5 + noise * Dither_Amount) / levels);

    return float4(lerp(src.rgb, col, Mix), src.a);
}
