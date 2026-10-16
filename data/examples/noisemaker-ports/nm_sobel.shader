// OBS HLSL adaptation of Noisemaker filter/sobel/sobel.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/sobel
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Sobel edge detection effect
 * Classic Sobel operator for edge detection
 */
uniform float amount<
    string label = "Amount";
    string widget_type = "slider";
    float minimum = 0.1;
    float maximum = 5.0;
    float step = 0.01;
> = 1.0;
// Fixed 1: OBS uses native output resolution, not Noisemaker 1.0.
uniform float alpha<
    string label = "Alpha";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;
float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 texSize = uv_size;
    // uv_size is a built-in uniform; no shadowing.
    float2 uv = globalCoord / uv_size;
    float2 texelSize = 1.0 / uv_size;

    float4 origColor = nmSample((v_in.uv * uv_size) / uv_size);

    // Sobel X kernel
    float sobel_x[9];
    sobel_x[0] = 1.0; sobel_x[1] = 0.0; sobel_x[2] = -1.0;
    sobel_x[3] = 2.0; sobel_x[4] = 0.0; sobel_x[5] = -2.0;
    sobel_x[6] = 1.0; sobel_x[7] = 0.0; sobel_x[8] = -1.0;

    // Sobel Y kernel
    float sobel_y[9];
    sobel_y[0] = 1.0;  sobel_y[1] = 2.0;  sobel_y[2] = 1.0;
    sobel_y[3] = 0.0;  sobel_y[4] = 0.0;  sobel_y[5] = 0.0;
    sobel_y[6] = -1.0; sobel_y[7] = -2.0; sobel_y[8] = -1.0;

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

    float3 convX = float3(0.0, 0.0, 0.0);
    float3 convY = float3(0.0, 0.0, 0.0);

    for (int i = 0; i < 9; i++) {
        float3 texSample = nmSample(((uv + offsets[i] * amount * 1.0) * uv_size - float2(0.0, 0.0)) / uv_size).rgb;
        convX += texSample * sobel_x[i];
        convY += texSample * sobel_y[i];
    }

    float dist = distance(convX, convY);

    // Multiply with original color
    float3 result = origColor.rgb * dist;

    // Blend between original input and sobel result
    float3 blended = lerp(origColor.rgb, result, alpha);

    fragColor = float4(blended, origColor.a);
    return fragColor;
}
