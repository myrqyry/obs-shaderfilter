// OBS HLSL adaptation of Noisemaker filter/translate/translate.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/translate
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}
float2 nmMod2(float2 x, float m) { return x - m * floor(x / m); }

/*
 * Translate image X and Y
 */
uniform float x<
    string label = "X";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.0;
uniform float y<
    string label = "Y";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.0;
uniform int wrap<
    string label = "Wrap";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "mirror";
    int option_1_value = 1;
    string option_1_label = "repeat";
    int option_2_value = 2;
    string option_2_label = "clamp";
> = 1;
float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 texSize = uv_size;
    float2 uv = (v_in.uv * uv_size) / texSize;

    // Apply translation
    uv.x = uv.x - x;
    uv.y = uv.y - y;

    // Apply wrap mode
    if (wrap == 0) {
        // mirror
        uv = abs(nmMod2(uv + 1.0, 2.0) - 1.0);
    } else if (wrap == 1) {
        // repeat
        uv = frac(uv);
    } else {
        // clamp
        uv = clamp(uv, 0.0, 1.0);
    }

    fragColor = nmSample(uv);
    return fragColor;
}
