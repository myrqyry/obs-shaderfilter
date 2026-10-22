// OBS HLSL adaptation of Noisemaker filter/sharpen/sharpen.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/sharpen
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Sharpen convolution effect
 * Enhances image detail and edges
 */
uniform float amount<
    string label = "Amount";
    string widget_type = "slider";
    float minimum = 0.1;
    float maximum = 5.0;
    float step = 0.01;
> = 1.0;
// Fixed 1: OBS uses native output resolution, not Noisemaker 1.0.
float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 texSize = uv_size;
    // uv_size is a built-in uniform; no shadowing.
    float2 uv = globalCoord / uv_size;
    float2 texelSize = 1.0 / uv_size;

    float4 origColor = nmSample((v_in.uv * uv_size) / uv_size);

    // Sharpen kernel
    // -1  0 -1
    //  0  5  0
    // -1  0 -1
    float kernel[9];
    kernel[0] = -1.0; kernel[1] = 0.0; kernel[2] = -1.0;
    kernel[3] = 0.0;  kernel[4] = 5.0; kernel[5] = 0.0;
    kernel[6] = -1.0; kernel[7] = 0.0; kernel[8] = -1.0;

    float2 offsets[9];
    offsets[0] = float2(-texelSize.x, -texelSize.y);
    offsets[1] = float2(0.0, -texelSize.y);
    offsets[2] = float2(texelSize.x, -texelSize.y);
    offsets[3] = float2(-texelSize.x, 0.0);
    offsets[4] = float2(0.0, 0.0);
    offsets[5] = float2(texelSize.x, 0.0);
    offsets[6] = float2(-texelSize.x, texelSize.y);
    offsets[7] = float2(0.0, texelSize.y);
    offsets[8] = float2(texelSize.x, texelSize.y);

    float3 conv = float3(0.0, 0.0, 0.0);

    for (int i = 0; i < 9; i++) {
        float3 texSample = nmSample(((uv + offsets[i] * amount * 1.0) * uv_size - float2(0.0, 0.0)) / uv_size).rgb;
        conv += texSample * kernel[i];
    }

    fragColor = float4(clamp(conv, 0.0, 1.0), origColor.a);
    return fragColor;
}
