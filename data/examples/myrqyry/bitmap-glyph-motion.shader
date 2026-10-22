// Bitmap Glyph Motion — a fresh OBS ShaderFilter .shader by myrqyry + Aster
//
// Reimagines the author's original bitmap25.shader (SHA-256 in README).
// Preserves its seven original 5x5 glyph bitmask sets, but renders each
// glyph inside a fixed square cell. Motion translates *entire cells*;
// characters never get stretched by a varying image sampling transform.
// Source: self-authored bitmap25. This is not an upstream OBS example.
//
// OBS supplies image, textureSampler, uv_size, elapsed_time, VertData,
// mainTransform and technique Draw when loading a normal .shader file.
// Do not enable "Override Entire Effect" for this file.
// Local subset of data/stdlib/colors.glsl. Intentionally standalone:
// users can load this .shader from Downloads without adjacent assets.
#define blend_min3(a, b, c) min(min(a, b), c)
#define blend_max3(a, b, c) max(max(a, b), c)

float blendLuminance(float3 c) {
    return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b;
}

float3 blendSetLum(float3 c, float l) {
    // ClipColor from the non-separable blend specification. Black and white
    // targets are fixed points; never divide by l or 1-l at those endpoints.
    if (l <= 0.0) return float3(0.0, 0.0, 0.0);
    if (l >= 1.0) return float3(1.0, 1.0, 1.0);
    float3 r = c + (l - blendLuminance(c));
    float mn = blend_min3(r.r, r.g, r.b);
    if (mn < 0.0) r = l + (r - l) * (l / (l - mn));
    float mx = blend_max3(r.r, r.g, r.b);
    if (mx > 1.0) r = l + (r - l) * ((1.0 - l) / (mx - l));
    return saturate(r);
}

float blendSaturation(float3 c) {
    return blend_max3(c.r, c.g, c.b) - blend_min3(c.r, c.g, c.b);
}

float3 blendSetSat(float3 c, float s) {
    float mn = blend_min3(c.r, c.g, c.b);
    float mx = blend_max3(c.r, c.g, c.b);
    return (mx > mn) ? (c - mn) * s / (mx - mn) : float3(0.0, 0.0, 0.0);
}

float3 blendMultiply(float3 base, float3 blend) {
    return base * blend;
}

float3 blendScreen(float3 base, float3 blend) {
    return 1.0 - (1.0 - base) * (1.0 - blend);
}

float3 blendOverlay(float3 base, float3 blend) {
    float3 r;
    r.r = (base.r < 0.5) ? 2.0 * base.r * blend.r : 1.0 - 2.0 * (1.0 - base.r) * (1.0 - blend.r);
    r.g = (base.g < 0.5) ? 2.0 * base.g * blend.g : 1.0 - 2.0 * (1.0 - base.g) * (1.0 - blend.g);
    r.b = (base.b < 0.5) ? 2.0 * base.b * blend.b : 1.0 - 2.0 * (1.0 - base.b) * (1.0 - blend.b);
    return r;
}

float sqrtSafe(float x) { return sqrt(max(x, 0.0)); }

float3 blendSoftLight(float3 base, float3 blend) {
    float3 r;
    r.r = (blend.r < 0.5)
        ? base.r - (1.0 - 2.0 * blend.r) * base.r * (1.0 - base.r)
        : base.r + (2.0 * blend.r - 1.0) * (sqrtSafe(base.r) - base.r);
    r.g = (blend.g < 0.5)
        ? base.g - (1.0 - 2.0 * blend.g) * base.g * (1.0 - base.g)
        : base.g + (2.0 * blend.g - 1.0) * (sqrtSafe(base.g) - base.g);
    r.b = (blend.b < 0.5)
        ? base.b - (1.0 - 2.0 * blend.b) * base.b * (1.0 - base.b)
        : base.b + (2.0 * blend.b - 1.0) * (sqrtSafe(base.b) - base.b);
    return r;
}

float3 blendHue(float3 base, float3 blend) {
    return blendSetLum(blendSetSat(blend, blendSaturation(base)), blendLuminance(base));
}

float3 blendColor(float3 base, float3 blend) {
    return blendSetLum(blend, blendLuminance(base));
}


uniform string BitmapGlyphInfo<
    string widget_type = "info";
> = "Bitmap Glyph Motion | 5x5 glyph art from bitmap25; rebuilt cell motion and correct Hue/Color blending.";

uniform float Mix<
    string label = "Effect Mix";
    string group = "Appearance";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;

uniform float Cell_Pixels<
    string label = "Glyph Cell Size (px)";
    string group = "Glyphs";
    string widget_type = "slider";
    float minimum = 5.0;
    float maximum = 64.0;
    float step = 1.0;
> = 12.0;

uniform int Glyph_Set<
    string label = "Original 5x5 Glyphs";
    string group = "Glyphs";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "Sparkles";
    int option_1_value = 1;
    string option_1_label = "Moonspin";
    int option_2_value = 2;
    string option_2_label = "S T E P";
    int option_3_value = 3;
    string option_3_label = "Bubbles";
    int option_4_value = 4;
    string option_4_label = "Hearts";
    int option_5_value = 5;
    string option_5_label = "Music notes";
    int option_6_value = 6;
    string option_6_label = "Sparkles v2";
    int option_7_value = 7;
    string option_7_label = "Cycle sets";
> = 0;

uniform float Low_Threshold<
    string label = "Dark Cutoff";
    string group = "Glyphs";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.08;

uniform float High_Threshold<
    string label = "Bright Cutoff";
    string group = "Glyphs";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.95;

uniform bool Invert_Glyph<
    string label = "Invert Glyph Pixels";
    string group = "Glyphs";
> = false;

uniform int Ink_Mode<
    string label = "Glyph Color Source";
    string group = "Color";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "Sampled image";
    int option_1_value = 1;
    string option_1_label = "Solid ink";
    int option_2_value = 2;
    string option_2_label = "Duotone ink";
> = 0;

uniform float4 Ink_Color<
    string label = "Ink Color";
    string group = "Color";
> = {0.98, 0.62, 0.76, 1.0};

uniform float4 Accent_Color<
    string label = "Accent Color";
    string group = "Color";
> = {0.49, 0.87, 0.85, 1.0};

uniform float Background_Amount<
    string label = "Source Visible Behind Glyphs";
    string group = "Color";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.24;

uniform float Ink_Opacity<
    string label = "Ink Opacity";
    string group = "Color";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;

uniform int Blend_Mode<
    string label = "Ink Blend";
    string group = "Color";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "Normal";
    int option_1_value = 1;
    string option_1_label = "Multiply";
    int option_2_value = 2;
    string option_2_label = "Screen";
    int option_3_value = 3;
    string option_3_label = "Overlay";
    int option_4_value = 4;
    string option_4_label = "Soft Light";
    int option_5_value = 5;
    string option_5_label = "Color (HSL luminance)";
    int option_6_value = 6;
    string option_6_label = "Hue (HSL hue)";
> = 0;

uniform bool Animate<
    string label = "Animate Whole Glyph Cells";
    string group = "Motion";
> = false;

uniform int Motion_Mode<
    string label = "Motion Pattern";
    string group = "Motion";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "Flow";
    int option_1_value = 1;
    string option_1_label = "Orbit";
> = 0;

uniform float Motion_Pixels<
    string label = "Motion Range (px)";
    string group = "Motion";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 80.0;
    float step = 1.0;
> = 16.0;

uniform float Motion_Speed<
    string label = "Motion Speed";
    string group = "Motion";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 6.0;
    float step = 0.05;
> = 1.0;

// Exactly the seven original bitmap25 sets, levels 1–5.
int BitmaskFor(int glyphSet, int level)
{
    if (level <= 0) return 0;
    int n = clamp(level, 1, 5);
    if (glyphSet == 0) {
        if (n == 1) return 4096;
        if (n == 2) return 141440;
        if (n == 3) return 4353156;
        if (n == 4) return 4357252;
        if (n == 5) return 4681156;
    }
    if (glyphSet == 1) {
        if (n == 1) return 15715430;
        if (n == 2) return 15722252;
        if (n == 3) return 13395950;
        if (n == 4) return 6410222;
        if (n == 5) return 15715430;
    }
    if (glyphSet == 2) {
        if (n == 1) return 7420495;
        if (n == 2) return 14745134;
        if (n == 3) return 14815935;
        if (n == 4) return 15218734;
        if (n == 5) return 15715430;
    }
    if (glyphSet == 3) {
        if (n == 1) return 141440;
        if (n == 2) return 469440;
        if (n == 3) return 4539716;
        if (n == 4) return 15255086;
        if (n == 5) return 328000;
    }
    if (glyphSet == 4) {
        if (n == 1) return 4663296;
        if (n == 2) return 145728;
        if (n == 3) return 4685802;
        if (n == 4) return 4540074;
        if (n == 5) return 4554;
    }
    if (glyphSet == 5) {
        if (n == 1) return 202892;
        if (n == 2) return 4057694;
        if (n == 3) return 29215326;
        if (n == 4) return 26070622;
        if (n == 5) return 6492548;
    }
    if (glyphSet == 6) {
        if (n == 1) return 4096;
        if (n == 2) return 145536;
        if (n == 3) return 4353156;
        if (n == 4) return 141440;
        if (n == 5) return 4096;
    }
    return 0;
}

// Keep integer, exact 5x5 bitmap art instead of replacing it with ASCII.
float GlyphMask(float2 unitCell, int mask)
{
    int2 bit = int2(floor(saturate(unitCell) * 5.0));
    bit = clamp(bit, int2(0, 0), int2(4, 4));
    int index = bit.x + bit.y * 5;
    return float((mask >> index) & 1);
}

float3 ApplyInkBlend(float3 underneath, float3 ink, int mode)
{
    if (mode == 1) return blendMultiply(underneath, ink);
    if (mode == 2) return blendScreen(underneath, ink);
    if (mode == 3) return blendOverlay(underneath, ink);
    if (mode == 4) return blendSoftLight(underneath, ink);
    // This is genuine luminosity-aware HSL color/hue transfer,
    // not bitmap25's legacy RGB component swapping.
    if (mode == 5) return blendColor(underneath, ink);
    if (mode == 6) return blendHue(underneath, ink);
    return ink;
}

float4 mainImage(VertData v_in) : TARGET
{
    float4 source = image.Sample(textureSampler, v_in.uv);
    if (Mix <= 0.0) return source;

    float cellSize = max(Cell_Pixels, 5.0);
    float2 resolution = max(uv_size, float2(1.0, 1.0));
    float2 position = v_in.uv * resolution;

    // Time varies the *cell grid origin*, never the unit glyph coordinate
    // inside a cell. Thus motion cannot bend, rotate or shear a 5x5 glyph.
    float2 motion = float2(0.0, 0.0);
    if (Animate && Motion_Pixels > 0.0) {
        float t = elapsed_time * max(Motion_Speed, 0.0);
        if (Motion_Mode == 1) {
            motion = float2(cos(t * 0.75), sin(t * 0.75)) * Motion_Pixels;
        } else {
            motion = float2(sin(t * 0.8), cos(t * 0.6)) * Motion_Pixels;
        }
    }

    float2 gridPixel = position + motion;
    float2 cellIndex = floor(gridPixel / cellSize);
    float2 glyphUV = frac(gridPixel / cellSize);
    // Sample at the center of each cell, accounting for animated grid origin.
    float2 sampleUV = ((cellIndex + 0.5) * cellSize - motion) / resolution;
    float4 sampled = image.Sample(textureSampler, saturate(sampleUV));
    float tone = dot(sampled.rgb, float3(0.2126, 0.7152, 0.0722));
    float thresholdSpan = max(High_Threshold - Low_Threshold, 0.001);
    float normalizedTone = (tone - Low_Threshold) / thresholdSpan;
    int level = 0;
    if (normalizedTone > 0.0)
        level = min(5, 1 + int(floor(saturate(normalizedTone) * 5.0)));

    int glyphSet = clamp(Glyph_Set, 0, 7);
    if (glyphSet == 7) glyphSet = int(floor(max(elapsed_time, 0.0) * 0.2)) % 7;

    int glyphBits = BitmaskFor(glyphSet, level);
    float mask = GlyphMask(glyphUV, glyphBits);
    if (Invert_Glyph && level > 0) mask = 1.0 - mask;

    float3 ink = sampled.rgb;
    if (Ink_Mode == 1) ink = Ink_Color.rgb;
    if (Ink_Mode == 2) ink = lerp(Ink_Color.rgb, Accent_Color.rgb, saturate(normalizedTone));
    ink = saturate(ink);

    float3 base = source.rgb * saturate(Background_Amount);
    float3 withInk = ApplyInkBlend(base, ink, Blend_Mode);
    float3 glyphColor = lerp(base, withInk, mask * saturate(Ink_Opacity));

    // Keep the original source alpha, including partial transparency.
    // Blend in RGB only; do not double-multiply the alpha by Ink_Opacity.
    return float4(lerp(source.rgb, glyphColor, saturate(Mix)), source.a);
}
