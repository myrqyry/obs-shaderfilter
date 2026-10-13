// PSX / Analog Hybrid
// One-pass treatment: PSX quantized color + 4x4 dither, restrained analogue
// scanlines, chromatic bleed, spatial image smear and very small line jitter.
// The "ghost" is spatial, NOT temporal feedback/trails.
// Standard Shaderfilter template; a video source/filter is required.

uniform int Color_Bits<
    string label = "Color bits per channel";
    string widget_type = "slider";
    int minimum = 2; int maximum = 8; int step = 1;
> = 5;
uniform float Dither<
    string label = "Ordered dither";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.5; float step = 0.05;
> = 0.65;
uniform float Pixel_Softness<
    string label = "Horizontal color bleed (px)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 3.0; float step = 0.1;
> = 1.0;
uniform float Chroma_Split<
    string label = "Chroma separation (px)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 3.0; float step = 0.05;
> = 0.55;
uniform float Spatial_Ghost<
    string label = "Spatial smear (not frame trails)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.05;
> = 0.18;
uniform float Scanline<
    string label = "Soft scanlines";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.05;
> = 0.12;
uniform float Film_Grain<
    string label = "Grain";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.25; float step = 0.005;
> = 0.014;
uniform float Line_Jitter<
    string label = "Moving line drift (px)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 2.0; float step = 0.05;
> = 0.16;
uniform float Mix<
    string label = "Effect strength";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 1.0;

float psx_hybrid_b2(float x, float y) {
    return 2.0 * x + 3.0 * y - 4.0 * x * y;
}
float psx_hybrid_bayer(float2 p) {
    p = floor(p);
    p -= 4.0 * floor(p / 4.0);
    float2 lo = p - 2.0 * floor(p / 2.0);
    float2 hi = floor(p / 2.0);
    return (4.0 * psx_hybrid_b2(lo.x, lo.y) +
                   psx_hybrid_b2(hi.x, hi.y) - 7.5) / 16.0;
}
float psx_hybrid_noise(float2 p) {
    return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}
float3 psx_hybrid_sample(float2 uv) {
    return image.Sample(textureSampler, saturate(uv)).rgb;
}

float4 mainImage(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 original = image.Sample(textureSampler, uv);
    if (Mix <= 0.0 || original.a <= 0.001) return original;

    float2 dims = max(uv_size, float2(1.0, 1.0));
    float2 pixels = uv * dims;
    float frame = floor(elapsed_time * 30.0);
    float band = floor(pixels.y / 12.0);
    float jitter = (psx_hybrid_noise(float2(band, frame)) - 0.5) * 2.0 * Line_Jitter;
    float2 jitter_uv = saturate(uv + float2(jitter / dims.x, 0.0));
    float4 center = image.Sample(textureSampler, jitter_uv);

    // Source-space color separation and spatial horizontal blend.
    float2 chroma = float2(Chroma_Split / dims.x, 0.0);
    float3 split = float3(
        psx_hybrid_sample(jitter_uv + chroma).r,
        center.g,
        psx_hybrid_sample(jitter_uv - chroma).b
    );
    float2 smear_offset = float2(max(Pixel_Softness, 0.0) / dims.x, 0.0);
    float3 left = psx_hybrid_sample(jitter_uv - smear_offset);
    float3 right = psx_hybrid_sample(jitter_uv + smear_offset);
    float3 soft = (left + split * 2.0 + right) * 0.25;
    float3 col = lerp(split, soft, saturate(Pixel_Softness / 3.0));
    col = lerp(col, psx_hybrid_sample(jitter_uv - smear_offset * 2.0), Spatial_Ghost);

    // Slightly darken every other SOURCE scanline, without global bloom.
    float line = 0.5 + 0.5 * cos(3.14159265 * pixels.y);
    col *= 1.0 - Scanline * line;
    float grain = psx_hybrid_noise(floor(pixels) + frame * 7.13) - 0.5;
    col = saturate(col + grain * Film_Grain);

    float levels = pow(2.0, float(Color_Bits)) - 1.0;
    col = saturate(floor(col * levels + 0.5 + Dither * psx_hybrid_bayer(pixels)) / levels);

    return float4(lerp(original.rgb, col, Mix), lerp(original.a, center.a, Mix));
}
