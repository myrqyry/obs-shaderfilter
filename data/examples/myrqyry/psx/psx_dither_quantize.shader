// PSX / Dither + Quantize
// Standalone, source-preserving OBS Shaderfilter (standard template mode).
// 4x4 Bayer threshold and configurable per-channel color bit depth.

uniform int Color_Bits<
    string label = "Color bits per channel";
    string widget_type = "slider";
    int minimum = 2; int maximum = 8; int step = 1;
> = 5;

uniform float Dither_Amount<
    string label = "Ordered dither";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.5; float step = 0.05;
> = 0.75;

uniform float Pattern_Scale<
    string label = "Dither pattern size (source px)";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 6.0; float step = 1.0;
> = 1.0;

uniform float Mix<
    string label = "Effect strength";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 1.0;

float psx_bayer2(float x, float y) {
    return 2.0 * x + 3.0 * y - 4.0 * x * y;
}
float psx_bayer4(float2 xy) {
    float2 p = floor(xy) - 4.0 * floor(floor(xy) / 4.0);
    float2 lower = p - 2.0 * floor(p / 2.0);
    float2 upper = floor(p / 2.0);
    return (4.0 * psx_bayer2(lower.x, lower.y)
                + psx_bayer2(upper.x, upper.y) - 7.5) / 16.0;
}

float4 mainImage(VertData v_in) : TARGET {
    float4 src = image.Sample(textureSampler, v_in.uv);
    if (Mix <= 0.0 || src.a <= 0.001) return src;

    float2 pixels = v_in.uv * max(uv_size, float2(1.0, 1.0));
    float threshold = psx_bayer4(pixels / max(Pattern_Scale, 1.0));
    float levels = pow(2.0, float(Color_Bits)) - 1.0;
    float3 rgb = saturate(src.rgb);
    float3 reduced = floor(rgb * levels + 0.5 + threshold * Dither_Amount) / levels;
    return float4(lerp(src.rgb, saturate(reduced), Mix), src.a);
}
