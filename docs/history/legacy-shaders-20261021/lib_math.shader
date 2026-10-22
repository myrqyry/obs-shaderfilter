// lib_math.shader
// Randomness, Noise, and Helper Math

// --- HELPERS ---

// Map a value from one range to another
// Example: map(sin(t), -1.0, 1.0, 0.0, 1.0) converts sine wave to 0-1 range
float map(float value, float min1, float max1, float min2, float max2) {
    return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

// --- RANDOMNESS ---

// 1D Random (Returns 0.0 - 1.0) based on a float seed
float rand(float n) {
    return frac(sin(n) * 43758.5453123);
}

// 2D Random (Returns 0.0 - 1.0) based on UV coordinates
// Useful for TV Static / Grain
float rand2(float2 p) {
    return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

// --- NOISE ---

// Simple Value Noise (Smoother than raw random)
float noise(float2 p) {
    float2 i = floor(p);
    float2 f = frac(p);
    
    // Four corners in 2D of a tile
    float a = rand2(i);
    float b = rand2(i + float2(1.0, 0.0));
    float c = rand2(i + float2(0.0, 1.0));
    float d = rand2(i + float2(1.0, 1.0));

    // Cubic Hermine Curve (Smoothstep)
    float2 u = f * f * (3.0 - 2.0 * f);

    return lerp(a, b, u.x) +
            (c - a) * u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}