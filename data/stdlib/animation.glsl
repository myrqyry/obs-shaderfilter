// HyperShader Standard Library - Animation & Easing
// Include via: #include "stdlib/animation.glsl"
// Requires: math.glsl for PI

#ifndef _STDLIB_ANIMATION_H_
#define _STDLIB_ANIMATION_H_

#ifndef PI
#define PI 3.14159265359
#endif
#ifndef TAU
#define TAU 6.28318530718
#endif

float easeLinear(float t) { return t; }

float easeInQuad(float t) { return t * t; }
float easeOutQuad(float t) { return t * (2.0 - t); }
float easeInOutQuad(float t) {
    return t < 0.5 ? 2.0 * t * t : -1.0 + (4.0 - 2.0 * t) * t;
}

float easeInCubic(float t) { return t * t * t; }
float easeOutCubic(float t) {
    float f = t - 1.0;
    return f * f * f + 1.0;
}
float easeInOutCubic(float t) {
    return t < 0.5 ? 4.0 * t * t * t : (t - 1.0) * (2.0 * t - 2.0) * (2.0 * t - 2.0) + 1.0;
}

float easeInQuart(float t) { return t * t * t * t; }
float easeOutQuart(float t) {
    float f = t - 1.0;
    return 1.0 - f * f * f * f;
}

float easeInExpo(float t) {
    return t == 0.0 ? 0.0 : pow(2.0, 10.0 * (t - 1.0));
}
float easeOutExpo(float t) {
    return t == 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * t);
}

float easeInSine(float t) { return 1.0 - cos(t * PI * 0.5); }
float easeOutSine(float t) { return sin(t * PI * 0.5); }
float easeInOutSine(float t) { return 0.5 * (1.0 - cos(PI * t)); }

float easeOutElastic(float t) {
    if (t == 0.0 || t == 1.0) return t;
    return pow(2.0, -10.0 * t) * sin((t - 0.075) * TAU / 0.3) + 1.0;
}
float easeInElastic(float t) {
    if (t == 0.0 || t == 1.0) return t;
    return -pow(2.0, 10.0 * (t - 1.0)) * sin((t - 1.075) * TAU / 0.3);
}

float easeOutBounce(float t) {
    if (t < 1.0 / 2.75) {
        return 7.5625 * t * t;
    } else if (t < 2.0 / 2.75) {
        t -= 1.5 / 2.75;
        return 7.5625 * t * t + 0.75;
    } else if (t < 2.5 / 2.75) {
        t -= 2.25 / 2.75;
        return 7.5625 * t * t + 0.9375;
    } else {
        t -= 2.625 / 2.75;
        return 7.5625 * t * t + 0.984375;
    }
}
float easeInBounce(float t) {
    return 1.0 - easeOutBounce(1.0 - t);
}

float easeInBack(float t) {
    const float s = 1.70158;
    return t * t * ((s + 1.0) * t - s);
}
float easeOutBack(float t) {
    const float s = 1.70158;
    float f = t - 1.0;
    return f * f * ((s + 1.0) * f + s) + 1.0;
}

// GLSL-style positive modulo, also valid in OBS's Direct3D/HLSL backend.
float animationModPositive(float x, float period) {
    return x - period * floor(x / period);
}

float pingPong(float time, float period) {
    if (period <= 0.0) return 0.0;
    float t = animationModPositive(time, period * 2.0) / period;
    return t < 1.0 ? t : 2.0 - t;
}

float triangleWave(float t) {
    return abs(frac(t) * 2.0 - 1.0);
}

float sawtoothWave(float t) {
    return frac(t);
}

float squareWave(float t, float dutyCycle) {
    return frac(t) < dutyCycle ? 1.0 : 0.0;
}

float stepped(float t, float steps) {
    return floor(t * steps) / max(steps - 1.0, 1.0);
}

float smoothStepped(float t, float steps) {
    float step = 1.0 / steps;
    float segment = floor(t / step);
    float localT = frac(t / step);
    return (segment + smoothstep(0.0, 1.0, localT)) / max(steps - 1.0, 1.0);
}

float loopWithHold(float time, float animDuration, float holdDuration) {
    if (animDuration <= 0.0) return 1.0;
    float totalDuration = max(animDuration + holdDuration, animDuration);
    float t = animationModPositive(time, totalDuration);
    return clamp(t / animDuration, 0.0, 1.0);
}

float delayedStart(float time, float delay, float duration) {
    return duration > 0.0 ? clamp((time - delay) / duration, 0.0, 1.0) : step(delay, time);
}

float bezierBlend(float t, float p1, float p2) {
    float t2 = t * t;
    float t3 = t2 * t;
    float mt = 1.0 - t;
    float mt2 = mt * mt;
    float mt3 = mt2 * mt;

    return mt3 * 0.0 + 3.0 * mt2 * t * p1 + 3.0 * mt * t2 * p2 + t3 * 1.0;
}


#endif
