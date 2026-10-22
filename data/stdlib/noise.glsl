// HyperShader Standard Library — Noise & Randomness
//
// Include via:  #include "stdlib/noise.glsl"
//
#ifndef _STDLIB_NOISE_H_
#define _STDLIB_NOISE_H_
// ===== FAMILIES =====
// HASH     — hash11/12/13/22/33 — Per-pixel pseudo-random
// VALUE    — valueNoise()       — Smoothed random grid
// GRADIENT — perlinNoise()      — Lattice gradient noise
// FBM      — fbm*()             — Fractal Brownian Motion (all families)
// CURL     — curlNoise()        — Divergence-free vector noise
// CELLULAR — worley()           — Distance-to-point cells
// VORONOI  — voronoiCell/Edge   — Voronoi features
// SIMPLEX  — simplexNoise()     — Compact gradient noise
// WARP     — domainWarp()       — Noise-in-noise flow
// VARIANT  — ridge/billow/bump  — Modified spectral content


// ###########################################################################
// PSEUDO-RANDOM HASH
// ###########################################################################

float hash11(float p) {
    p = frac(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

float hash12(float2 p) {
    float3 p3 = frac(float3(p.xyx) * 0.1031);
    float d = dot(p3, p3.yzx + 33.33);
    p3 += float3(d, d, d);
    return frac((p3.x + p3.y) * p3.z);
}

float hash13(float3 p3) {
    p3 = frac(p3 * 0.1031);
    float d = dot(p3, p3.zyx + 31.32);
    p3 += float3(d, d, d);
    return frac((p3.x + p3.y) * p3.z);
}

float2 hash22(float2 p) {
    float3 p3 = frac(float3(p.xyx) * float3(0.1031, 0.1031, 0.1031));
    float d = dot(p3, p3.yzx + 33.33);
    p3 += float3(d, d, d);
    return frac((p3.xx + p3.yz) * p3.zy);
}

float3 hash33(float3 p3) {
    p3 = frac(p3 * 0.1031);
    float d = dot(p3, p3.zyx + 31.32);
    p3 += float3(d, d, d);
    return frac((p3.xxy + p3.yzz) * p3.zyx);
}

// ###########################################################################
// VALUE NOISE
// ###########################################################################

float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return lerp(
        lerp(hash12(i + float2(0.0, 0.0)), hash12(i + float2(1.0, 0.0)), u.x),
        lerp(hash12(i + float2(0.0, 1.0)), hash12(i + float2(1.0, 1.0)), u.x),
        u.y
    );
}

// ###########################################################################
// PERLIN GRADIENT NOISE
// ###########################################################################

float perlinNoise(float2 p) {
    float2 i = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);

    float2 ga = normalize(hash22(i + float2(0.0, 0.0)) * 2.0 - 1.0);
    float2 gb = normalize(hash22(i + float2(1.0, 0.0)) * 2.0 - 1.0);
    float2 gc = normalize(hash22(i + float2(0.0, 1.0)) * 2.0 - 1.0);
    float2 gd = normalize(hash22(i + float2(1.0, 1.0)) * 2.0 - 1.0);

    float va = dot(ga, f - float2(0.0, 0.0));
    float vb = dot(gb, f - float2(1.0, 0.0));
    float vc = dot(gc, f - float2(0.0, 1.0));
    float vd = dot(gd, f - float2(1.0, 1.0));

    return 0.5 + 0.5 * lerp(lerp(va, vb, u.x), lerp(vc, vd, u.x), u.y);
}

// ###########################################################################
// SIMPLEX NOISE 2D
// ###########################################################################

float simplexNoise(float2 p) {
    const float K1 = 0.366025404;
    const float K2 = 0.211324865;

    float2 i = floor(p + (p.x + p.y) * K1);
    float2 a = p - (i - (i.x + i.y) * K2);
    float2 o = (a.x < a.y) ? float2(0.0, 1.0) : float2(1.0, 0.0);
    float2 b = a - o + K2;
    float2 c = a - 1.0 + 2.0 * K2;

    float3 h = max(0.5 - float3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    float3 n = h * h * h * h * float3(
        dot(a, hash22(i) * 2.0 - 1.0),
        dot(b, hash22(i + o) * 2.0 - 1.0),
        dot(c, hash22(i + 1.0) * 2.0 - 1.0)
    );

    return dot(n, float3(1.0, 1.0, 1.0)) * 41.0 + 0.5;
}

// ###########################################################################
// CELLULAR / WORLEY NOISE
// ###########################################################################

float4 worley(float2 p) {
    float2 i = floor(p);

    float min1 = 8.0, min2 = 8.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 cell = i + float2(x, y);
            float2 cellPos = cell + hash22(cell);
            float2 diff = cellPos - p;
            float dist = dot(diff, diff);

            if (dist < min1) {
                min2 = min1;
                min1 = dist;
            } else if (dist < min2) {
                min2 = dist;
            }
        }
    }

    return float4(sqrt(min1), sqrt(min2), sqrt(min2) - sqrt(min1), 0.0);
}

// ###########################################################################
// VORONOI
// ###########################################################################

float4 voronoiCells(float2 p) {
    float2 i = floor(p);
    float minDist = 8.0;
    float2 cellId = float2(0.0, 0.0);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 cell = i + float2(x, y);
            float2 cellPos = cell + hash22(cell);
            float2 diff = cellPos - p;
            float dist = dot(diff, diff);
            if (dist < minDist) {
                minDist = dist;
                cellId = cell;
            }
        }
    }
    return float4(cellId, sqrt(minDist), 0.0);
}

float voronoiEdge(float2 p) {
    return worley(p).z;
}

// ###########################################################################
// FRACTAL BROWNIAN MOTION
// ###########################################################################

float fbm(float2 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    float2 shift = float2(100.0, 100.0);
    float c05 = cos(0.5);
    float s05 = sin(0.5);

    for (int i = 0; i < min(max(octaves, 0), 8); i++) {
        v += a * perlinNoise(p);
        float2 rotated = float2(p.x * c05 - p.y * s05, p.x * s05 + p.y * c05);
        p = rotated * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

float fbmValue(float2 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    float2 shift = float2(100.0, 100.0);
    float c05 = cos(0.5);
    float s05 = sin(0.5);

    for (int i = 0; i < min(max(octaves, 0), 8); i++) {
        v += a * valueNoise(p);
        float2 rotated = float2(p.x * c05 - p.y * s05, p.x * s05 + p.y * c05);
        p = rotated * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

float fbmSimplex(float2 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    float2 shift = float2(100.0, 100.0);
    float c05 = cos(0.5);
    float s05 = sin(0.5);

    for (int i = 0; i < min(max(octaves, 0), 8); i++) {
        v += a * simplexNoise(p);
        float2 rotated = float2(p.x * c05 - p.y * s05, p.x * s05 + p.y * c05);
        p = rotated * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

float fbmWorley(float2 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    float2 shift = float2(100.0, 100.0);
    float c05 = cos(0.5);
    float s05 = sin(0.5);

    for (int i = 0; i < min(max(octaves, 0), 8); i++) {
        v += a * worley(p).x;
        float2 rotated = float2(p.x * c05 - p.y * s05, p.x * s05 + p.y * c05);
        p = rotated * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

float fbmConfig(float2 p, int octaves, float lacunarity, float gain) {
    float v = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    float c05 = cos(0.5);
    float s05 = sin(0.5);

    for (int i = 0; i < min(max(octaves, 0), 8); i++) {
        v += amp * perlinNoise(p * freq);
        float2 rotated = float2(p.x * c05 - p.y * s05, p.x * s05 + p.y * c05);
        p = rotated + float2(100.0, 100.0);
        freq *= lacunarity;
        amp *= gain;
    }
    return v;
}

// ###########################################################################
// CURL NOISE (divergence-free vector fields)
// ###########################################################################

float2 curlDirection(float2 delta) {
    float lenSq = dot(delta, delta);
    if (lenSq <= 1.0e-12) return float2(0.0, 0.0);
    return delta * rsqrt(lenSq);
}

float2 curlNoise(float2 p, float eps) {
    if (abs(eps) <= 1.0e-6) return float2(0.0, 0.0);
    float n0 = perlinNoise(p);
    float nx = perlinNoise(p + float2(eps, 0.0));
    float ny = perlinNoise(p + float2(0.0, eps));
    return curlDirection(float2(n0 - ny, nx - n0));
}

float2 curlFbm(float2 p, int octaves, float eps) {
    if (octaves <= 0 || abs(eps) <= 1.0e-6) return float2(0.0, 0.0);
    float n0 = fbm(p, octaves);
    float nx = fbm(p + float2(eps, 0.0), octaves);
    float ny = fbm(p + float2(0.0, eps), octaves);
    return curlDirection(float2(n0 - ny, nx - n0));
}

// ###########################################################################
// DOMAIN WARPING
// ###########################################################################

float domainWarp(float2 p, int octaves, float warpStrength) {
    float2 q = float2(fbm(p, octaves), fbm(p + float2(5.2, 1.3), octaves));
    float2 r = float2(
        fbm(p + warpStrength * q + float2(1.7, 9.2), octaves),
        fbm(p + warpStrength * q + float2(8.3, 2.8), octaves)
    );
    return fbm(p + warpStrength * r, octaves);
}

// ###########################################################################
// NOISE VARIANTS (spectral modification)
// ###########################################################################

float ridgeNoise(float2 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    float2 shift = float2(100.0, 100.0);
    float c05 = cos(0.5);
    float s05 = sin(0.5);

    for (int i = 0; i < min(max(octaves, 0), 8); i++) {
        float n = 1.0 - abs(2.0 * perlinNoise(p) - 1.0);
        v += a * n * n;
        float2 rotated = float2(p.x * c05 - p.y * s05, p.x * s05 + p.y * c05);
        p = rotated * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

float billowNoise(float2 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    float2 shift = float2(100.0, 100.0);
    float c05 = cos(0.5);
    float s05 = sin(0.5);

    for (int i = 0; i < min(max(octaves, 0), 8); i++) {
        float n = abs(2.0 * perlinNoise(p) - 1.0);
        v += a * n;
        float2 rotated = float2(p.x * c05 - p.y * s05, p.x * s05 + p.y * c05);
        p = rotated * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

float bumpNoise(float2 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    float2 shift = float2(100.0, 100.0);
    float c05 = cos(0.5);
    float s05 = sin(0.5);

    for (int i = 0; i < min(max(octaves, 0), 8); i++) {
        float n = 2.0 * perlinNoise(p) - 1.0;
        n = 1.0 - abs(n);
        n = n * n;
        v += a * n;
        float2 rotated = float2(p.x * c05 - p.y * s05, p.x * s05 + p.y * c05);
        p = rotated * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

// ###########################################################################
// VALUE NOISE 3D
// ###########################################################################

float valueNoise3D(float3 p) {
    float3 i = floor(p);
    float3 f = frac(p);
    float3 u = f * f * (3.0 - 2.0 * f);

    float va = lerp(lerp(hash13(i + float3(0,0,0)), hash13(i + float3(1,0,0)), u.x),
                    lerp(hash13(i + float3(0,1,0)), hash13(i + float3(1,1,0)), u.x), u.y);
    float vb = lerp(lerp(hash13(i + float3(0,0,1)), hash13(i + float3(1,0,1)), u.x),
                    lerp(hash13(i + float3(0,1,1)), hash13(i + float3(1,1,1)), u.x), u.y);
    return lerp(va, vb, u.z);
}

// ###########################################################################
// PERLIN GRADIENT NOISE 3D
// ###########################################################################

float perlinNoise3D(float3 p) {
    float3 i = floor(p);
    float3 f = frac(p);
    float3 u = f * f * (3.0 - 2.0 * f);
    float3 ONE = float3(1.0, 1.0, 1.0);

    float3 ga = normalize(hash33(i + float3(0,0,0)) * 2.0 - ONE);
    float3 gb = normalize(hash33(i + float3(1,0,0)) * 2.0 - ONE);
    float3 gc = normalize(hash33(i + float3(0,1,0)) * 2.0 - ONE);
    float3 gd = normalize(hash33(i + float3(1,1,0)) * 2.0 - ONE);
    float3 ge = normalize(hash33(i + float3(0,0,1)) * 2.0 - ONE);
    float3 gf = normalize(hash33(i + float3(1,0,1)) * 2.0 - ONE);
    float3 gg = normalize(hash33(i + float3(0,1,1)) * 2.0 - ONE);
    float3 gh = normalize(hash33(i + float3(1,1,1)) * 2.0 - ONE);

    float3 f0 = f;
    float3 f1 = f - float3(1,0,0);
    float3 f2 = f - float3(0,1,0);
    float3 f3 = f - float3(1,1,0);
    float3 f4 = f - float3(0,0,1);
    float3 f5 = f - float3(1,0,1);
    float3 f6 = f - float3(0,1,1);
    float3 f7 = f - float3(1,1,1);

    float va = lerp(lerp(dot(ga, f0), dot(gb, f1), u.x),
                    lerp(dot(gc, f2), dot(gd, f3), u.x), u.y);
    float vb = lerp(lerp(dot(ge, f4), dot(gf, f5), u.x),
                    lerp(dot(gg, f6), dot(gh, f7), u.x), u.y);
    return 0.5 + 0.5 * lerp(va, vb, u.z);
}

// ###########################################################################
// FRACTAL BROWNIAN MOTION 3D
// ###########################################################################

float fbm3D(float3 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    float c05 = cos(0.5);
    float s05 = sin(0.5);

    for (int i = 0; i < min(max(octaves, 0), 8); i++) {
        v += a * perlinNoise3D(p);
        float x = p.x * c05 - p.y * s05;
        float y = p.x * s05 + p.y * c05;
        p = float3(x, y, p.z) * 2.0 + 100.0;
        a *= 0.5;
    }
    return v;
}

// ###########################################################################
// NOISE VARIANTS 3D
// ###########################################################################

float ridgeNoise3D(float3 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < min(max(octaves, 0), 8); i++) {
        float n = 1.0 - abs(2.0 * perlinNoise3D(p) - 1.0);
        v += a * n * n;
        float x = p.x * cos(0.5) - p.y * sin(0.5);
        float y = p.x * sin(0.5) + p.y * cos(0.5);
        p = float3(x, y, p.z) * 2.0 + 100.0;
        a *= 0.5;
    }
    return v;
}

float billowNoise3D(float3 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < min(max(octaves, 0), 8); i++) {
        float n = abs(2.0 * perlinNoise3D(p) - 1.0);
        v += a * n;
        float x = p.x * cos(0.5) - p.y * sin(0.5);
        float y = p.x * sin(0.5) + p.y * cos(0.5);
        p = float3(x, y, p.z) * 2.0 + 100.0;
        a *= 0.5;
    }
    return v;
}

float bumpNoise3D(float3 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < min(max(octaves, 0), 8); i++) {
        float n = 2.0 * perlinNoise3D(p) - 1.0;
        n = 1.0 - abs(n);
        n = n * n;
        v += a * n;
        float x = p.x * cos(0.5) - p.y * sin(0.5);
        float y = p.x * sin(0.5) + p.y * cos(0.5);
        p = float3(x, y, p.z) * 2.0 + 100.0;
        a *= 0.5;
    }
    return v;
}

float domainWarp3D(float3 p, int octaves, float warpStrength) {
    float3 q = float3(fbm3D(p, octaves), fbm3D(p + float3(5.2, 1.3, 0.0), octaves), 0.0);
    float3 r = float3(
        fbm3D(p + warpStrength * q + float3(1.7, 9.2, 0.0), octaves),
        fbm3D(p + warpStrength * q + float3(8.3, 2.8, 0.0), octaves),
        0.0
    );
    return fbm3D(p + warpStrength * r, octaves);
}

// ###########################################################################
// SIMPLEX 3D
// ###########################################################################

float simplexNoise3D(float3 p) {
    const float F = 1.0 / 3.0;
    const float G = 1.0 / 6.0;
    const float3 ONE = float3(1.0, 1.0, 1.0);

    float s = (p.x + p.y + p.z) * F;
    float3 skew = float3(s, s, s);
    float3 i = floor(p + skew);
    float t = (i.x + i.y + i.z) * G;
    float3 unskew = float3(t, t, t);
    float3 a = p - (i - unskew);

    // Rank the coordinates so the two intermediate vertices are distinct,
    // with each gradient sampled at the same vertex as its displacement.
    float3 g = step(a.yzx, a);
    float3 l = ONE - g;
    float3 o1 = min(g, l.zxy);
    float3 o2 = max(g, l.zxy);
    float3 b = a - o1 + G;
    float3 c = a - o2 + 2.0 * G;
    float3 d = a - ONE + 3.0 * G;

    float4 h = max(float4(0.6, 0.6, 0.6, 0.6) -
        float4(dot(a, a), dot(b, b), dot(c, c), dot(d, d)), 0.0);
    float4 falloff = h * h * h * h;
    float4 gradients = float4(
        dot(hash33(i) * 2.0 - ONE, a),
        dot(hash33(i + o1) * 2.0 - ONE, b),
        dot(hash33(i + o2) * 2.0 - ONE, c),
        dot(hash33(i + ONE) * 2.0 - ONE, d)
    );
    return 0.5 + 0.5 * dot(falloff, gradients) * 32.0;
}

// ###########################################################################
// WORLEY 3D
// ###########################################################################

float4 worley3D(float3 p) {
    float3 i = floor(p);
    float min1 = 8.0, min2 = 8.0;

    for (int z = -1; z <= 1; z++) {
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                float3 cell = i + float3(x, y, z);
                float3 cellPos = cell + hash33(cell);
                float3 diff = cellPos - p;
                float dist = dot(diff, diff);
                if (dist < min1) { min2 = min1; min1 = dist; }
                else if (dist < min2) { min2 = dist; }
            }
        }
    }
    return float4(sqrt(min1), sqrt(min2), sqrt(min2) - sqrt(min1), 0.0);
}


#endif
