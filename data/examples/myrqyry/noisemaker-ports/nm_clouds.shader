// OBS HLSL adaptation of Noisemaker filter/clouds/clouds.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/clouds
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// Noisemaker filter inputs use edge-clamped texture sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Clouds - Cloud texture overlay
 *
 * Ridged multi-octave 2D simplex noise shaped into clouds,
 * composited with offset shadow onto the input.
 */
uniform float seed<
    string label = "Seed";
    string widget_type = "slider";
    float minimum = 1.0;
    float maximum = 100.0;
    float step = 0.01;
> = 1.0;
uniform float scale<
    string label = "Scale";
    string widget_type = "slider";
    float minimum = 0.1;
    float maximum = 1.0;
    float step = 0.01;
> = 0.25;
uniform int speed<
    string label = "Speed";
    string widget_type = "slider";
    int minimum = 0;
    int maximum = 4;
    int step = 1;
> = 0;
#define TAU 6.28318530718

// Simplex 2D - MIT License (Ashima Arts)
float3 nmMod2893(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
float2 nmMod2892(float2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
float3 permute(float3 x) { return nmMod2893(((x * 34.0) + 1.0) * x); }

float simplex2d(float2 v) {
    const float4 C = float4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);

    float2 i  = floor(v + dot(v, C.yy));
    float2 x0 = v - i + dot(i, C.xx);
    float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;

    i = nmMod2892(i);
    float3 p = permute(permute(i.y + float3(0.0, i1.y, 1.0)) + i.x + float3(0.0, i1.x, 1.0));
    float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m = m * m;
    m = m * m;

    float3 x = 2.0 * frac(p * C.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);

    float3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;

    return 130.0 * dot(m, g);
}

// Multi-octave FBM simplex noise, returns [0, 1]
// When animSpeed > 0, each octave gets a circular elapsed_time offset for seamless morphing
float cloudNoise(float2 uv, float baseFreq, int octaves, float animPhase, float animSpeed) {
    float accum = 0.0;
    float totalAmp = 0.0;

    for (int i = 0; i < 8; i++) {
        if (i >= octaves) break;
        float freq = baseFreq * pow(2.0, float(i));
        float amp = 1.0 / pow(2.0, float(i));

        // Per-octave circular offset for morphing animation
        // Subtract initial position so offset is zero at elapsed_time=0
        float octavePhase = float(i) * 2.13;
        float octaveRadius = (0.25 + float(i) * 0.08) * animSpeed;
        float2 timeOffset = (float2(cos(animPhase + octavePhase), sin(animPhase + octavePhase))
                         - float2(cos(octavePhase), sin(octavePhase))) * octaveRadius;

        float n = simplex2d(uv * freq + float2(float(i) * 37.0, float(i) * 53.0) + timeOffset);
        n = n * 0.5 + 0.5;

        accum += n * amp;
        totalAmp += amp;
    }

    return accum / totalAmp;
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 texSize = uv_size;
    float2 tileDims = texSize;
    float2 dimensions = uv_size;
    float2 uv = (v_in.uv * uv_size) / tileDims;
    float2 globalUV = ((v_in.uv * uv_size) + float2(0.0, 0.0)) / uv_size;

    float4 inputColor = nmSample(uv);

    // Scale UV for cloud size, aspect-correct, offset by seed
    float aspect = uv_size.x / uv_size.y;
    float2 seedOffset = float2(seed * 17.31, seed * 23.71);

    // Animation phase (loops at 0-1 elapsed_time boundary)
    float animPhase = elapsed_time * TAU * float(speed);
    float animSpeed = float(speed);

    float2 cloudUV = globalUV * float2(aspect, 1.0) / scale + seedOffset;

    float cloud = cloudNoise(cloudUV, 1.0, 7, animPhase, animSpeed);

    // Shape into clouds: threshold for puffy shapes
    float cloudMask = smoothstep(0.45, 0.65, cloud);

    // Cloud shading: vary brightness within the cloud for depth
    // Thicker parts (higher noise) are brighter white, edges are slightly gray
    float cloudDepth = smoothstep(0.45, 0.85, cloud);
    float cloudBrightness = lerp(0.75, 1.0, cloudDepth);

    // Shadow: sample cloud at offset (light from upper-right)
    float shadowDist = min(uv_size.x, uv_size.y) * 0.008;
    float2 shadowOffset = float2(-shadowDist, shadowDist) / uv_size;
    float2 shadowUV = (globalUV + shadowOffset) * float2(aspect, 1.0) / scale + seedOffset;
    float shadowCloud = cloudNoise(shadowUV, 1.0, 7, animPhase, animSpeed);
    float shadowMask = smoothstep(0.45, 0.65, shadowCloud);

    // Shadow only where there's cloud nearby but not at current pixel
    float shadow = max(shadowMask - cloudMask, 0.0) * 0.5;

    // Composite: darken input by shadow, then overlay shaded clouds
    float3 result = inputColor.rgb * (1.0 - shadow);
    result = lerp(result, float3(cloudBrightness, cloudBrightness, cloudBrightness), cloudMask);

    fragColor = float4(result, inputColor.a);
    return fragColor;
}
