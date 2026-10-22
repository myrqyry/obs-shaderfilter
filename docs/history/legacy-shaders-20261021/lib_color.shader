// lib_color.shader
// Useful functions for color manipulation and blending

// Constants
static const float3 LUMA_COEFF = float3(0.2126, 0.7152, 0.0722);

// --- CONVERSIONS ---

// Get the brightness (luminance) of a color
float luma(float3 color) {
    return dot(color, LUMA_COEFF);
}

// Convert RGB to Grayscale
float3 toGrayscale(float3 color) {
    return float3(luma(color), luma(color), luma(color));
}

// RGB to HSV (Hue, Saturation, Value)
// Ranges: H [0, 1], S [0, 1], V [0, 1]
float3 rgb2hsv(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV to RGB
float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// --- BLENDING MODES ---
// Standard Photoshop-style blend modes

float3 blendScreen(float3 base, float3 blend) {
    return 1.0 - (1.0 - base) * (1.0 - blend);
}

float3 blendOverlay(float3 base, float3 blend) {
    return lerp(
        2.0 * base * blend,
        1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
        step(0.5, base)
    );
}

float3 blendMultiply(float3 base, float3 blend) {
    return base * blend;
}