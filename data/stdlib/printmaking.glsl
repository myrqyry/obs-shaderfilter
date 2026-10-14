// HyperShader Printmaking primitives (OBS HLSL-style effect code).
// Adapted from Noise Factor LLC's Noisemaker Hatch/Stipple procedural methods.
// Original code: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter
// Copyright (c) 2017-2026 Noise Factor LLC, MIT License.
// The copyright and license text are retained in
// data/examples/printmaking/NOISEMAKER-LICENSE.txt.
#ifndef _STDLIB_PRINTMAKING_H_
#define _STDLIB_PRINTMAKING_H_

// Seeded hash and smooth lattice noise. Floor/frac handle rotated negative
// pixel coordinates consistently. Names are namespaced to coexist with
// HyperShader's generic noise.glsl helpers.
float printHash(float2 p, float seed) {
    float3 q = frac(float3(p.x, p.y, p.x) * 0.1031 + seed * 0.071);
    float offset = dot(q, q.yzx + 33.33);
    q += float3(offset, offset, offset);
    return frac((q.x + q.y) * q.z);
}

float2 printHash2(float2 p, float seed) {
    return float2(
        printHash(p + float2(3.17, 7.31), seed),
        printHash(p + float2(17.71, 31.97), seed + 13.0)
    );
}

float printValueNoise(float2 p, float seed) {
    float2 cell = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float bottom = lerp(printHash(cell, seed),
                        printHash(cell + float2(1.0, 0.0), seed), u.x);
    float top = lerp(printHash(cell + float2(0.0, 1.0), seed),
                     printHash(cell + float2(1.0, 1.0), seed), u.x);
    return lerp(bottom, top, u.y);
}

float2 printRotate(float2 pixel, float radiansAngle) {
    float c = cos(radiansAngle);
    float s = sin(radiansAngle);
    return float2(c * pixel.x - s * pixel.y,
                  s * pixel.x + c * pixel.y);
}

// Elongated, continuous ink fiber field. Along the line, noise changes
// slowly; across it, near one pixel at a time. Works in absolute pixels,
// not normalized UVs, so aspect ratio and output size don't skew the grain.
float printHatchField(float2 pixel, float radiansAngle,
                      float strokeLengthPixels, float seed) {
    float2 rotated = printRotate(pixel, radiansAngle);
    float2 position = rotated *
        float2(1.0 / max(strokeLengthPixels, 1.0), 0.9);
    return printValueNoise(position, seed);
}

// Returns xy = closest point in cell-grid coordinates,
// zw = its integer lattice cell. Nine neighbor checks ensure the closest
// jittered seed is found even at cell borders.
float4 printNearestCell(float2 gridPosition, float jitter, float seed) {
    float2 base = floor(gridPosition);
    float bestDistanceSq = 1.0e12;
    float4 nearest = float4(0.0, 0.0, 0.0, 0.0);
    float amount = clamp(jitter, 0.0, 0.95);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 cell = base + float2(float(x), float(y));
            float2 point = cell + 0.5 +
                (printHash2(cell, seed) - 0.5) * amount;
            float2 delta = gridPosition - point;
            float distanceSq = dot(delta, delta);
            if (distanceSq < bestDistanceSq) {
                bestDistanceSq = distanceSq;
                nearest = float4(point, cell);
            }
        }
    }
    return nearest;
}
#endif
