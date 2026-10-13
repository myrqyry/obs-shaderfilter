// HyperShader Standard Library - Math Utilities
// Include via: #include "stdlib/math.glsl"

#ifndef _STDLIB_MATH_H_
#define _STDLIB_MATH_H_

#ifndef PI
#define PI 3.14159265359
#endif
#ifndef TAU
#define TAU 6.28318530718
#endif
#ifndef HALF_PI
#define HALF_PI 1.57079632679
#endif
#ifndef PHI
#define PHI 1.61803398875
#endif
#ifndef SQRT2
#define SQRT2 1.41421356237
#endif

// Rec. 601 luminance via manual component sum. Avoids dot() which can
// emit "cannot call a non-function" on some OBS backends.
float luma(float3 color) {
    return color.r * 0.299 + color.g * 0.587 + color.b * 0.114;
}

float sq(float x) { return x * x; }
float2 sq(float2 x) { return x * x; }
float3 sq(float3 x) { return x * x; }

float cube(float x) { return x * x * x; }

float safeDivide(float a, float b) {
    return b != 0.0 ? a / b : 0.0;
}

float remap(float v, float a, float b, float c, float d) {
    return b != a ? c + (d - c) * clamp((v - a) / (b - a), 0.0, 1.0) : c;
}

float remapUnclamped(float v, float a, float b, float c, float d) {
    return b != a ? c + (d - c) * ((v - a) / (b - a)) : c;
}

float normalize01(float v, float minVal, float maxVal) {
    return maxVal != minVal ? clamp((v - minVal) / (maxVal - minVal), 0.0, 1.0) : 0.0;
}

float2 rotate(float2 p, float a) {
    float s = sin(a);
    float c = cos(a);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}

float2 rotateAround(float2 p, float2 center, float angle) {
    return rotate(p - center, angle) + center;
}

float2 cartesianToPolar(float2 p) {
    return float2(length(p), atan2(p.y, p.x));
}

float2 polarToCartesian(float2 polar) {
    return polar.x * float2(cos(polar.y), sin(polar.y));
}

float angleFromCenter(float2 uv, float2 center) {
    float2 delta = uv - center;
    float angle = atan2(delta.y, delta.x);
    return angle < 0.0 ? angle + TAU : angle;
}

float smootherstep(float edge0, float edge1, float x) {
    x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

float smoothCubic(float t) {
    return t * t * (3.0 - 2.0 * t);
}

float smoothQuintic(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float expSmooth(float current, float target, float speed) {
    return lerp(current, target, 1.0 - exp(-max(speed, 0.0)));
}

float softClamp(float x, float limit) {
    // A zero limit means no soft-clamping, not an undefined division.
    if (limit == 0.0) return x;
    return limit * tanh(x / limit);
}

float bias(float t, float b) {
    // The bias curve is defined for 0 < b < 1. Outside that domain,
    // preserve the input instead of producing infinities or NaNs.
    if (b <= 0.0 || b >= 1.0) return t;
    return pow(t, log(b) / log(0.5));
}

float gain(float t, float g) {
    if (g <= 0.0 || g >= 1.0) return t;
    if (t < 0.5)
        return bias(2.0 * t, 1.0 - g) / 2.0;
    else
        return 1.0 - bias(2.0 - 2.0 * t, 1.0 - g) / 2.0;
}

float sinNorm(float x) {
    return sin(x) * 0.5 + 0.5;
}

float cosNorm(float x) {
    return cos(x) * 0.5 + 0.5;
}

float modPositive(float x, float m) {
    // Negative periods have the same positive remainder as their magnitude.
    float period = abs(m);
    if (period == 0.0) return x;
    return x - period * floor(x / period);
}

float2 aspectCorrect(float2 uv, float2 resolution) {
    float aspect = resolution.y != 0.0 ? resolution.x / resolution.y : 1.0;
    return float2((uv.x - 0.5) * aspect + 0.5, uv.y);
}

float distToSegment(float2 p, float2 a, float2 b) {
    float2 pa = p - a;
    float2 ba = b - a;
    float lenSq = dot(ba, ba);
    if (lenSq <= 0.0) return length(pa);
    float h = clamp(dot(pa, ba) / lenSq, 0.0, 1.0);
    return length(pa - ba * h);
}

float sdCircle(float2 p, float2 center, float radius) {
    return length(p - center) - radius;
}

float sdBox(float2 p, float2 center, float2 size) {
    float2 d = abs(p - center) - size;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

#endif