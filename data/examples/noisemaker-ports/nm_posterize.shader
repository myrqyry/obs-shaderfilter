// OBS HLSL adaptation of Noisemaker filter/posterize/posterize.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/posterize
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}
float3 nmFwidth3(float3 x) { return abs(ddx(x)) + abs(ddy(x)); }

/*
 * Posterize: sRGB-aware color quantization with adjustable gamma
 */
uniform float levels<
    string label = "Levels";
    string widget_type = "slider";
    float minimum = 2.0;
    float maximum = 32.0;
    float step = 0.01;
> = 5.0;
uniform float gamma<
    string label = "Gamma";
    string widget_type = "slider";
    float minimum = 0.1;
    float maximum = 3.0;
    float step = 0.01;
> = 1.0;
uniform bool antialias<
    string label = "Antialias";
> = true;
#define MIN_LEVELS 1.0
#define MIN_GAMMA 1e-3

float clamp_01(float value) {
    return clamp(value, 0.0, 1.0);
}

float srgb_to_linear_component(float value) {
    if (value <= 0.04045) {
        return value / 12.92;
    }
    return pow((value + 0.055) / 1.055, 2.4);
}

float linear_to_srgb_component(float value) {
    if (value <= 0.0031308) {
        return value * 12.92;
    }
    return 1.055 * pow(value, 1.0 / 2.4) - 0.055;
}

float3 srgb_to_linear_rgb(float3 rgb) {
    return float3(
        srgb_to_linear_component(rgb.x),
        srgb_to_linear_component(rgb.y),
        srgb_to_linear_component(rgb.z)
    );
}

float3 linear_to_srgb_rgb(float3 rgb) {
    return float3(
        linear_to_srgb_component(rgb.x),
        linear_to_srgb_component(rgb.y),
        linear_to_srgb_component(rgb.z)
    );
}

float3 pow_vec3(float3 value, float exponent) {
    return pow(value, float3(exponent, exponent, exponent));
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 uv = (v_in.uv * uv_size) / uv_size;
    float4 texel = nmSample(uv);

    float levels_raw = max(levels, 0.0);
    float levels_quantized = max(round(levels_raw), MIN_LEVELS);
    if (levels_quantized <= 1.0) {
        fragColor = texel;
        return fragColor;
    }

    float level_factor = levels_quantized;
    float inv_factor = 1.0 / level_factor;
    float half_step = inv_factor * 0.5;
    float gamma_value = max(gamma, MIN_GAMMA);
    float inv_gamma = 1.0 / gamma_value;

    float3 working_rgb = srgb_to_linear_rgb(texel.xyz);
    working_rgb = pow_vec3(clamp(working_rgb, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0)), gamma_value);

    // Posterize with optional edge smoothing
    float3 scaled = working_rgb * level_factor + float3(half_step, half_step, half_step);
    float3 quantized_rgb;
    if (antialias) {
        float3 f = frac(scaled);
        float3 fw = nmFwidth3(scaled);
        float3 blend = smoothstep(0.5 - fw * 0.5, 0.5 + fw * 0.5, f);
        quantized_rgb = (floor(scaled) + blend) * inv_factor;
    } else {
        quantized_rgb = floor(scaled) * inv_factor;
    }
    quantized_rgb = pow_vec3(clamp(quantized_rgb, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0)), inv_gamma);

    quantized_rgb = linear_to_srgb_rgb(quantized_rgb);

    fragColor = float4(
        clamp_01(quantized_rgb.x),
        clamp_01(quantized_rgb.y),
        clamp_01(quantized_rgb.z),
        texel.w
    );
    return fragColor;
}
