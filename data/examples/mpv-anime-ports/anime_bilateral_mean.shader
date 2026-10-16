// Original: shaders/Anime4K_Denoise_Bilateral_Mean.glsl
// Copyright (c) 2019-2021 bloc97. MIT.
// Original operates on all RGBA channels; OBS adaptation preserves alpha.
// Adapted from Chinna95P/mpv-anime-build MPV shader collection (MIT).
// Source: https://github.com/Chinna95P/mpv-anime-build/tree/main/shaders
// Licensed under MIT; see MPV-ANIME-LICENSE.txt.
// MPV hook sampling adapted to OBS Shaderfilter's image, textureSampler,
// uv_pixel_interval and uv_size. Alpha of source preserved.
float4 mpvSample(float2 uv) {
    float2 halfPixel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfPixel, 1.0 - halfPixel));
}

uniform float intensity_sigma<
    string label = "Color Similarity";
    string widget_type = "slider";
    float minimum = 0.01; float maximum = 0.5; float step = 0.005;
> = 0.1;
uniform float spatial_sigma<
    string label = "Spatial Radius";
    string widget_type = "slider";
    float minimum = 0.3; float maximum = 2.0; float step = 0.05;
> = 1.0;
uniform float blend_factor<
    string label = "Denoise Mix";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 1.0;
float4 mainImage(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 center = mpvSample(uv);
    // Avoid the 25-tap spatial/color kernel when the effect is disabled.
    if (blend_factor <= 0.0) return center;
    float3 sum = float3(0,0,0);
    float3 weights = float3(0,0,0);
    float3 colorSigma = max(center.rgb + 0.0001, 0.0001) * intensity_sigma;
    float ss = max(spatial_sigma, 0.001);
    // The upstream default SPATIAL_SIGMA=1 uses a fixed 5x5 kernel.
    // Keep that 25-tap support and expose sigma within this window.
    for (int y=-2; y<=2; y++) {
        for (int x=-2; x<=2; x++) {
            float2 offset = float2(x,y);
            float3 sampleRGB = mpvSample(uv + offset * uv_pixel_interval).rgb;
            float3 colorDist = (sampleRGB-center.rgb) / colorSigma;
            float spaceDist = dot(offset,offset) / (ss * ss);
            float3 weight = exp(-0.5 * (colorDist*colorDist + spaceDist));
            sum += weight * sampleRGB;
            weights += weight;
        }
    }
    float3 denoised = sum / max(weights, float3(0.000001,0.000001,0.000001));
    return float4(lerp(center.rgb, denoised, blend_factor), center.a);
}
