// HyperShader Standard Library - Blur Functions
// Include via: #include "stdlib/blur.glsl"
// Note: Requires 'image' (Texture2D) and 'textureSampler' (SamplerState)
//       to be in scope (they are in standard OBS shaderfilter shaders).
#ifndef _STDLIB_BLUR_H_
#define _STDLIB_BLUR_H_


#ifndef TAU
#define TAU 6.28318530718
#endif

float gaussian1D(float x, float sigma) {
    if (sigma < 0.0001) return 1.0;
    float twoSigmaSq = 2.0 * sigma * sigma;
    return exp(-(x * x) / twoSigmaSq) / (sqrt(TAU) * sigma);
}

float gaussian2D(float2 offset, float sigma) {
    return gaussian1D(offset.x, sigma) * gaussian1D(offset.y, sigma);
}

float4 boxBlur(float2 uv, float2 texelSize, int radius) {
    float4 sum = float4(0.0, 0.0, 0.0, 0.0);
    float count = 0.0;

    radius = clamp(radius, 0, 8);
    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            float2 offset = float2(x, y) * texelSize;
            sum += image.Sample(textureSampler, uv + offset);
            count += 1.0;
        }
    }
    return sum / count;
}

float4 gaussianBlur1D(float2 uv, float2 texelSize, float2 direction, float sigma, int samples) {
    float4 result = float4(0.0, 0.0, 0.0, 0.0);
    float weightSum = 0.0;

    float centerWeight = gaussian1D(0.0, sigma);
    result += image.Sample(textureSampler, uv) * centerWeight;
    weightSum += centerWeight;

    samples = clamp(samples, 0, 16);
    for (int i = 1; i <= samples; i++) {
        float weight = gaussian1D(float(i), sigma);
        float2 offset = direction * texelSize * float(i);

        result += image.Sample(textureSampler, uv + offset) * weight;
        result += image.Sample(textureSampler, uv - offset) * weight;
        weightSum += weight * 2.0;
    }

    return result / weightSum;
}

float4 directionalBlur(float2 uv, float2 texelSize, float angle, float strength, int samples) {
    float2 direction = float2(cos(angle), sin(angle));
    float4 result = float4(0.0, 0.0, 0.0, 0.0);
    float weightSum = 0.0;

    samples = clamp(samples, 1, 32);
    for (int i = 0; i < samples; i++) {
        float t = float(i) / float(max(samples - 1, 1)) - 0.5;
        float2 offset = direction * t * strength * texelSize;
        float weight = gaussian1D(t * 2.0, 0.4);

        result += image.Sample(textureSampler, uv + offset) * weight;
        weightSum += weight;
    }

    return result / weightSum;
}

float4 radialBlur(float2 uv, float2 center, float strength, int samples) {
    float4 result = float4(0.0, 0.0, 0.0, 0.0);
    float2 dir = uv - center;

    samples = clamp(samples, 1, 32);
    for (int i = 0; i < samples; i++) {
        float t = float(i) / float(max(samples - 1, 1));
        float scale = 1.0 - strength * t;
        float2 sampleUV = center + dir * scale;
        result += image.Sample(textureSampler, sampleUV);
    }

    return result / float(samples);
}

float4 kawaseBlur(float2 uv, float2 texelSize, float offset) {
    float4 result = float4(0.0, 0.0, 0.0, 0.0);

    result += image.Sample(textureSampler, uv + float2(-offset - 0.5, -offset - 0.5) * texelSize);
    result += image.Sample(textureSampler, uv + float2(-offset - 0.5,  offset + 0.5) * texelSize);
    result += image.Sample(textureSampler, uv + float2( offset + 0.5, -offset - 0.5) * texelSize);
    result += image.Sample(textureSampler, uv + float2( offset + 0.5,  offset + 0.5) * texelSize);

    return result * 0.25;
}

float4 dualKawaseDown(float2 uv, float2 texelSize) {
    float4 sum = image.Sample(textureSampler, uv) * 4.0;
    sum += image.Sample(textureSampler, uv - texelSize);
    sum += image.Sample(textureSampler, uv + texelSize);
    sum += image.Sample(textureSampler, uv + float2(texelSize.x, -texelSize.y));
    sum += image.Sample(textureSampler, uv + float2(-texelSize.x, texelSize.y));
    return sum / 8.0;
}

float4 dualKawaseUp(float2 uv, float2 texelSize) {
    float4 sum = float4(0.0, 0.0, 0.0, 0.0);
    sum += image.Sample(textureSampler, uv + float2(-texelSize.x * 2.0, 0.0));
    sum += image.Sample(textureSampler, uv + float2(-texelSize.x, texelSize.y)) * 2.0;
    sum += image.Sample(textureSampler, uv + float2(0.0, texelSize.y * 2.0));
    sum += image.Sample(textureSampler, uv + float2(texelSize.x, texelSize.y)) * 2.0;
    sum += image.Sample(textureSampler, uv + float2(texelSize.x * 2.0, 0.0));
    sum += image.Sample(textureSampler, uv + float2(texelSize.x, -texelSize.y)) * 2.0;
    sum += image.Sample(textureSampler, uv + float2(0.0, -texelSize.y * 2.0));
    sum += image.Sample(textureSampler, uv + float2(-texelSize.x, -texelSize.y)) * 2.0;
    return sum / 12.0;
}


#endif
