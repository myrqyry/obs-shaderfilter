// OBS HLSL adaptation of Noisemaker filter/pixels/pixels.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/pixels
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Pixelation effect
 * Reduces image uv_size for retro pixel art look
 */
uniform float size<
    string label = "Size";
    string widget_type = "slider";
    float minimum = 1.0;
    float maximum = 256.0;
    float step = 0.01;
> = 16.0;
float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 texSize = uv_size;
    float2 tileDims = texSize;
    float2 uv_size = uv_size.x > 0.0 ? uv_size : tileDims;
    float2 uv = (v_in.uv * uv_size) / tileDims;

    if (size < 1.0) {
        fragColor = nmSample(uv);
        return fragColor;
    }

    float pixelSize = size;

    float dx = pixelSize / uv_size.x;
    float dy = pixelSize / uv_size.y;

    // Use global UV so pixel grid aligns across tiles
    float2 globalUV = ((v_in.uv * uv_size) + float2(0.0, 0.0)) / uv_size;
    float2 centered = globalUV - 0.5;
    float2 globalCoord = float2(dx * floor(centered.x / dx), dy * floor(centered.y / dy));
    globalCoord += 0.5;

    // Convert back to tile-local UV for sampling
    float2 coord = (globalCoord * uv_size - float2(0.0, 0.0)) / tileDims;

    fragColor = nmSample(coord);
    return fragColor;
}
