// OBS HLSL adaptation of Noisemaker filter/invert/inv.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/invert
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Invert brightness effect
 * mode 0 (full, default): simple RGB inversion, 1.0 - value
 * mode 1 (solarize): Solarize parity, min(v, 1.0 - v) per channel
 *   (PS: output = v <= 128 ? v : 255 - v, equivalent to min(v, 1-v) in 0..1)
 */
uniform int mode<
    string label = "Mode";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "full";
    int option_1_value = 1;
    string option_1_label = "solarize";
> = 0;
float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 texSize = uv_size;
    float2 uv = (v_in.uv * uv_size) / texSize;
    float4 color = nmSample(uv);

    // Invert the underlying color and retain premultiplied coverage.
    if (mode == 1) {
        color.rgb = min(color.rgb, color.a - color.rgb);
    } else {
        color.rgb = color.a - color.rgb;
    }

    fragColor = color;
    return fragColor;
}
