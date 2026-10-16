// OBS HLSL adaptation of Noisemaker filter/sine/sine.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/sine
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Sine wave distortion
 * RGB mode: apply sine to R, G, B independently
 * Non-RGB mode: convert to luminance, apply sine, output grayscale
 */
uniform float amount<
    string label = "Amount";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 20.0;
    float step = 0.01;
> = 7.0;
uniform float colorMode<
    string label = "Color mode";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 20.0;
    float step = 0.01;
> = 1.0;
float normalized_sine(float value) {
    return (sin(value) + 1.0) * 0.5;
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 texSize = uv_size;
    float2 uv = (v_in.uv * uv_size) / texSize;
    float4 color = nmSample(uv);

    bool use_rgb = colorMode > 0.5;

    if (use_rgb) {
        color.r = normalized_sine(color.r * amount);
        color.g = normalized_sine(color.g * amount);
        color.b = normalized_sine(color.b * amount);
    } else {
        float lum = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
        float result = normalized_sine(lum * amount);
        color.rgb = float3(result, result, result);
    }

    fragColor = color;
    return fragColor;
}
