// HyperShader Standard Library — Color Utilities
// Color space conversions, full Photoshop blend mode suite, palettes, tonemapping
//
// Include via:  #include "stdlib/colors.glsl"
#ifndef _STDLIB_COLORS_H_
#define _STDLIB_COLORS_H_
// Requires:     math.glsl if using palette/rainbow (TAU)
//
// ===== BLEND MODES =====
// Every blend function follows:  float3 blendX(float3 base, float3 blend)
// where 'base' is the bottom layer and 'blend' is the top layer.
// Per-channel alpha variants are named blendX_alpha() where they exist.
//
// Standard formula references:
//   https://www.w3.org/TR/compositing-1/
//   https://docs.kde.org/trunk5/en/krita/reference_manual/blending_modes/


#ifndef TAU
#define TAU 6.28318530718
#endif

// Per-channel pow helper. Required because pow(float3, float) is not
// overloaded on the OpenGL backend, and float3(scalar) broadcast
// constructors are also rejected there. Used by rgb2lab, toGamma, toLinear.
float3 pow3(float3 base, float exp) {
    return float3(pow(base.r, exp), pow(base.g, exp), pow(base.b, exp));
}

// ###########################################################################
// COLOR SPACE CONVERSIONS
// ###########################################################################

// --- RGB <-> HSV ---
// H in [0,1), S/V in [0,1]. Fastest hue-space conversion.
float3 rgb2hsv(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = (c.g < c.b) ? float4(c.bg, K.wz) : float4(c.gb, K.xy);
    float4 q = (c.r < p.x) ? float4(p.xyw, c.r) : float4(c.r, p.yzx);
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// --- RGB <-> HSL ---
// H in [0,1), S/L in [0,1]. Luma-preserving — better for lightness adjustments.
float3 rgb2hsl(float3 rgb) {
    float h = 0.0, s = 0.0, l = 0.0;
    float cMin = min(rgb.r, min(rgb.g, rgb.b));
    float cMax = max(rgb.r, max(rgb.g, rgb.b));

    l = (cMax + cMin) * 0.5;

    if (cMax > cMin) {
        float cDelta = cMax - cMin;
        s = (l < 0.5) ? cDelta / (cMax + cMin) : cDelta / (2.0 - cMax - cMin);

        if (rgb.r == cMax)
            h = (rgb.g - rgb.b) / cDelta;
        else if (rgb.g == cMax)
            h = 2.0 + (rgb.b - rgb.r) / cDelta;
        else
            h = 4.0 + (rgb.r - rgb.g) / cDelta;

        h = h < 0.0 ? h + 6.0 : h;
        h = h / 6.0;
    }
    return float3(h, s, l);
}

float3 hsl2rgb(float3 hsl) {
    float3 rgb = clamp(
        abs(fmod(hsl.x * 6.0 + float3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0,
        0.0, 1.0
    );
    return hsl.z + hsl.y * (rgb - 0.5) * (1.0 - abs(2.0 * hsl.z - 1.0));
}

// --- RGB <-> YUV (BT.709) ---
// Luma (Y) is the Rec.709 weighted sum. UV are colour-difference channels.
// Great for luma-based effects, video pipeline, chroma keying.
float3 rgb2yuv(float3 rgb) {
    float y = dot(rgb, float3(0.2126, 0.7152, 0.0722));
    float u = dot(rgb, float3(-0.1146, -0.3854, 0.5)) + 0.5;
    float v = dot(rgb, float3(0.5, -0.4542, -0.0458)) + 0.5;
    return float3(y, u, v);
}

float3 yuv2rgb(float3 yuv) {
    yuv.yz -= 0.5;
    float r = yuv.x + 1.5748 * yuv.z;
    float g = yuv.x - 0.1873 * yuv.y - 0.4681 * yuv.z;
    float b = yuv.x + 1.8556 * yuv.y;
    return float3(r, g, b);
}

// --- RGB <-> LAB (simplified D65) ---
// Perceptually uniform — Euclidean distance in LAB ≈ perceived difference.
// Not pixel-precise sRGB but close enough for shader effects.
float3 rgb2lab(float3 rgb) {
    float3 xyz;
    rgb = pow3(max(rgb, 0.0), 2.2);
    xyz.x = dot(rgb, float3(0.4124, 0.3576, 0.1805));
    xyz.y = dot(rgb, float3(0.2126, 0.7152, 0.0722));
    xyz.z = dot(rgb, float3(0.0193, 0.1192, 0.9505));

    xyz = xyz / float3(0.9505, 1.0, 1.089);
    // OBS's HLSL-to-OpenGL backend does not accept a vector comparison
    // as a ternary condition; apply the LAB branch component-wise.
    xyz.x = xyz.x > 0.008856 ? pow(xyz.x, 1.0 / 3.0) : 7.787 * xyz.x + 16.0 / 116.0;
    xyz.y = xyz.y > 0.008856 ? pow(xyz.y, 1.0 / 3.0) : 7.787 * xyz.y + 16.0 / 116.0;
    xyz.z = xyz.z > 0.008856 ? pow(xyz.z, 1.0 / 3.0) : 7.787 * xyz.z + 16.0 / 116.0;

    float l = (116.0 * xyz.y) - 16.0;
    float a = 500.0 * (xyz.x - xyz.y);
    float b = 200.0 * (xyz.y - xyz.z);

    return float3(l / 100.0, a / 128.0 + 0.5, b / 128.0 + 0.5);
}

// ###########################################################################
// BASIC EFFECTS
// ###########################################################################

float3 invert(float3 color) { return 1.0 - color; }

// Rec. 601 luminance via manual component sum. Avoids dot() which can
// emit "cannot call a non-function" on some OBS backends.
float grayscaleLuminance(float3 color) {
    return color.r * 0.299 + color.g * 0.587 + color.b * 0.114;
}

float3 grayscale(float3 color) {
    float lum = grayscaleLuminance(color);
    return float3(lum, lum, lum);
}

float3 posterize(float3 color, float levels) {
    return floor(color * levels) / max(levels - 1.0, 1.0);
}

float3 threshold(float3 color, float thresh) {
    float lum = grayscaleLuminance(color);
    return lum > thresh ? float3(1.0, 1.0, 1.0) : float3(0.0, 0.0, 0.0);
}

float3 sepia(float3 color) {
    float3 r;
    r.r = dot(color, float3(0.393, 0.769, 0.189));
    r.g = dot(color, float3(0.349, 0.686, 0.168));
    r.b = dot(color, float3(0.272, 0.534, 0.131));
    return r;
}

// ###########################################################################
// BLEND MODE UTILITIES
// ###########################################################################

// Per-channel min/max helpers used by several blend modes.
#define blend_min3(a, b, c) min(min(a, b), c)
#define blend_max3(a, b, c) max(max(a, b), c)

float blendLuminance(float3 c) {
    return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b;
}

float3 blendSetLum(float3 c, float l) {
    float d = l - blendLuminance(c);
    float3 r = c + d;
    float mn = blend_min3(r.r, r.g, r.b);
    float mx = blend_max3(r.r, r.g, r.b);
    if (mn < 0.0) r = lerp((l / (l - mn)) * r, float3(0.0, 0.0, 0.0), -mn / l);
    if (mx > 1.0) r = lerp(((1.0 - l) / (mx - l)) * r, float3(1.0, 1.0, 1.0), (mx - 1.0) / (1.0 - l));
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

// ###########################################################################
// BLEND MODES — NORMAL / BASIC
// ###########################################################################

float3 blendNormal(float3 base, float3 blend) {
    return blend;
}

float3 blendDissolve(float3 base, float3 blend, float coverage, float2 random) {
    return coverage > random ? blend : base;
}

// Simple average of base and blend — smooth, muted.
float3 blendAverage(float3 base, float3 blend) {
    return (base + blend) * 0.5;
}

// ###########################################################################
// BLEND MODES — DARKEN GROUP
// ###########################################################################

// Keeps the darker of each channel.
float3 blendDarken(float3 base, float3 blend) {
    return min(base, blend);
}

// Multiplies base by blend — always darker (except with white).
float3 blendMultiply(float3 base, float3 blend) {
    return base * blend;
}

// Burns base by increasing contrast based on blend.
// Darker blend = stronger burn. White blend = no effect.
float3 blendColorBurn(float3 base, float3 blend) {
    float3 r;
    r.r = (blend.r > 0.0) ? 1.0 - min(1.0, (1.0 - base.r) / blend.r) : 0.0;
    r.g = (blend.g > 0.0) ? 1.0 - min(1.0, (1.0 - base.g) / blend.g) : 0.0;
    r.b = (blend.b > 0.0) ? 1.0 - min(1.0, (1.0 - base.b) / blend.b) : 0.0;
    return r;
}

// Inverse of Color Dodge — base + blend - 1.
float3 blendLinearBurn(float3 base, float3 blend) {
    return max(base + blend - 1.0, 0.0);
}

// Compares the luminance of base and blend, keeps whichever is darker.
float3 blendDarkerColor(float3 base, float3 blend) {
    return blendLuminance(base) < blendLuminance(blend) ? base : blend;
}

// ###########################################################################
// BLEND MODES — LIGHTEN GROUP
// ###########################################################################

// Keeps the lighter of each channel.
float3 blendLighten(float3 base, float3 blend) {
    return max(base, blend);
}

// Inverse of Multiply — always lightens (except with black).
float3 blendScreen(float3 base, float3 blend) {
    return 1.0 - (1.0 - base) * (1.0 - blend);
}

// Divides base by inverse of blend. Lighter blend = stronger dodge.
float3 blendColorDodge(float3 base, float3 blend) {
    float3 r;
    r.r = (blend.r < 1.0) ? min(1.0, base.r / max(1.0 - blend.r, 0.001)) : 1.0;
    r.g = (blend.g < 1.0) ? min(1.0, base.g / max(1.0 - blend.g, 0.001)) : 1.0;
    r.b = (blend.b < 1.0) ? min(1.0, base.b / max(1.0 - blend.b, 0.001)) : 1.0;
    return r;
}

// Base + blend (additive). Simple and bright.
float3 blendLinearDodge(float3 base, float3 blend) {
    return min(base + blend, 1.0);
}

// Reflect — shiny dodge: base^2 / inverse of blend. Intense highlights.
float3 blendReflect(float3 base, float3 blend) {
    float3 r;
    r.r = (blend.r < 1.0) ? min(base.r * base.r / max(1.0 - blend.r, 0.001), 1.0) : 1.0;
    r.g = (blend.g < 1.0) ? min(base.g * base.g / max(1.0 - blend.g, 0.001), 1.0) : 1.0;
    r.b = (blend.b < 1.0) ? min(base.b * base.b / max(1.0 - blend.b, 0.001), 1.0) : 1.0;
    return r;
}

// Glow — reflect with swapped args: blend^2 / inverse of base.
float3 blendGlow(float3 base, float3 blend) {
    return blendReflect(blend, base);
}

// Compares luminance — keeps lighter.
float3 blendLighterColor(float3 base, float3 blend) {
    return blendLuminance(blend) < blendLuminance(base) ? base : blend;
}

// ###########################################################################
// BLEND MODES — CONTRAST GROUP
// ###########################################################################

// Soft version of Hard Light. Uses a smooth curve.
float3 blendOverlay(float3 base, float3 blend) {
    float3 r;
    r.r = (base.r < 0.5) ? 2.0 * base.r * blend.r : 1.0 - 2.0 * (1.0 - base.r) * (1.0 - blend.r);
    r.g = (base.g < 0.5) ? 2.0 * base.g * blend.g : 1.0 - 2.0 * (1.0 - base.g) * (1.0 - blend.g);
    r.b = (base.b < 0.5) ? 2.0 * base.b * blend.b : 1.0 - 2.0 * (1.0 - base.b) * (1.0 - blend.b);
    return r;
}

float sqrtSafe(float x) { return sqrt(max(x, 0.0)); }

// Soft light — soft contrast boost. Uses the Pegtop formula.
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
// Hard light — same as Overlay with base/blend swapped. Strong contrast.
float3 blendHardLight(float3 base, float3 blend) {
    return blendOverlay(blend, base);
}

// Vivid light — combines Color Dodge and Color Burn.
float3 blendVividLight(float3 base, float3 blend) {
    float3 r;
    r.r = (blend.r < 0.5)
        ? (blend.r > 0.0) ? 1.0 - min(1.0, (1.0 - base.r) / (2.0 * blend.r)) : 0.0
        : (blend.r < 1.0) ? min(1.0, base.r / (2.0 * (1.0 - blend.r))) : 1.0;
    r.g = (blend.g < 0.5)
        ? (blend.g > 0.0) ? 1.0 - min(1.0, (1.0 - base.g) / (2.0 * blend.g)) : 0.0
        : (blend.g < 1.0) ? min(1.0, base.g / (2.0 * (1.0 - blend.g))) : 1.0;
    r.b = (blend.b < 0.5)
        ? (blend.b > 0.0) ? 1.0 - min(1.0, (1.0 - base.b) / (2.0 * blend.b)) : 0.0
        : (blend.b < 1.0) ? min(1.0, base.b / (2.0 * (1.0 - blend.b))) : 1.0;
    return r;
}

// Linear light — combines Linear Dodge and Linear Burn.
float3 blendLinearLight(float3 base, float3 blend) {
    return saturate(base + 2.0 * blend - 1.0);
}

// Pin light — replaces base with blend depending on brightness.
float3 blendPinLight(float3 base, float3 blend) {
    float3 r;
    r.r = (blend.r < 0.5)
        ? min(base.r, 2.0 * blend.r)
        : max(base.r, 2.0 * (blend.r - 0.5));
    r.g = (blend.g < 0.5)
        ? min(base.g, 2.0 * blend.g)
        : max(base.g, 2.0 * (blend.g - 0.5));
    r.b = (blend.b < 0.5)
        ? min(base.b, 2.0 * blend.b)
        : max(base.b, 2.0 * (blend.b - 0.5));
    return r;
}

// Hard mix — posterize to 0 or 1 per channel. Extreme contrast.
float3 blendHardMix(float3 base, float3 blend) {
    float3 r = blendVividLight(base, blend);
    return floor(r + 0.5);
}

// ###########################################################################
// BLEND MODES — COMPARATIVE GROUP
// ###########################################################################

// Absolute difference. Good for invert/highlight edges.
float3 blendDifference(float3 base, float3 blend) {
    return abs(base - blend);
}

// Negation — inverted Difference: 1 - |1 - base - blend|. Retro, photo-negative feel.
float3 blendNegation(float3 base, float3 blend) {
    return 1.0 - abs(1.0 - base - blend);
}

// Phoenix — extreme inversion: min - max + 1. Inverts base on blend edges.
float3 blendPhoenix(float3 base, float3 blend) {
    return min(base, blend) - max(base, blend) + 1.0;
}

// Softer version of Difference — lower contrast.
float3 blendExclusion(float3 base, float3 blend) {
    return base + blend - 2.0 * base * blend;
}

// Subtract — blend subtracted from base.
float3 blendSubtract(float3 base, float3 blend) {
    return max(base - blend, 0.0);
}

// Divide — base divided by blend.
float3 blendDivide(float3 base, float3 blend) {
    return min(base / max(blend, 0.001), 1.0);
}

// ###########################################################################
// BLEND MODES — HSL GROUP (Photoshop)
// ###########################################################################

// Hue: takes hue from blend, saturation/luminance from base.
float3 blendHue(float3 base, float3 blend) {
    return blendSetLum(blendSetSat(blend, blendSaturation(base)), blendLuminance(base));
}

// Saturation: takes saturation from blend, hue/luminance from base.
float3 blendSaturation(float3 base, float3 blend) {
    return blendSetLum(blendSetSat(base, blendSaturation(blend)), blendLuminance(base));
}

// Color: takes hue+saturation from blend, luminance from base.
float3 blendColor(float3 base, float3 blend) {
    return blendSetLum(blend, blendLuminance(base));
}

// Luminosity: takes luminance from blend, hue+saturation from base.
float3 blendLuminosity(float3 base, float3 blend) {
    return blendSetLum(base, blendLuminance(blend));
}

// ###########################################################################
// ALPHA-AWARE BLEND
// ###########################################################################

float3 blendWithOpacity(float3 base, float3 blend, float opacity) {
    return lerp(base, blend, opacity);
}

// No function-pointer version — call the blend function directly, then composite:
//   float3 mixed = blendMultiply(base.rgb, blend.rgb);
//   float3 result = lerp(base.rgb, mixed, blend.a);
//   float4(result, base.a + blend.a * (1.0 - base.a));

// ###########################################################################
// PALETTES
// ###########################################################################

// IQ Cosine Palette: http://iquilezles.org/articles/palettes
float3 palette(float t, float3 a, float3 b, float3 c, float3 d) {
    return a + b * cos(TAU * (c * t + d));
}

float3 rainbow(float t) {
    return 0.5 + 0.5 * cos(TAU * (t + float3(0.0, 0.33, 0.67)));
}

float3 heatmap(float t) {
    t = saturate(t);
    if (t < 0.25)
        return lerp(float3(0, 0, 1), float3(0, 1, 1), t * 4.0);
    else if (t < 0.5)
        return lerp(float3(0, 1, 1), float3(0, 1, 0), (t - 0.25) * 4.0);
    else if (t < 0.75)
        return lerp(float3(0, 1, 0), float3(1, 1, 0), (t - 0.5) * 4.0);
    else
        return lerp(float3(1, 1, 0), float3(1, 0, 0), (t - 0.75) * 4.0);
}

// ###########################################################################
// TONEMAPPING & GAMMA
// ###########################################################################

float3 tonemapACES(float3 x) {
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

float3 tonemapReinhard(float3 x) {
    return x / (x + 1.0);
}

float3 tonemapFilmic(float3 x) {
    float3 X = max(float3(0.0, 0.0, 0.0), x - 0.004);
    return (X * (6.2 * X + 0.5)) / (X * (6.2 * X + 1.7) + 0.06);
}

float3 toGamma(float3 color, float gamma) {
    return pow3(max(color, 0.0), 1.0 / gamma);
}

float3 toLinear(float3 color, float gamma) {
    return pow3(max(color, 0.0), gamma);
}

float3 postProcess(float3 col, float exposure, float gamma) {
    col *= exposure;
    col = tonemapACES(col);
    col = toGamma(col, gamma);
    return col;
}


#endif
