// OBS HLSL adaptation of Noisemaker filter/simpleAberration/chromaticAberration.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/simpleAberration
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}


/*
 * Chromatic aberration effect.
 */
uniform float displacement<
    string label = "Displacement";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.1;
    float step = 0.01;
> = 0.02;
float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalPixel = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 globalUV = globalPixel / uv_size;

    float maxDisplacementUV = 256.0 / uv_size.x;
    float boundedDisplacement = clamp(displacement, -maxDisplacementUV, maxDisplacementUV);

    float2 redGlobalUV = globalUV + float2(boundedDisplacement, 0.0);
    float2 redLocalUV = (redGlobalUV * uv_size - float2(0.0, 0.0)) / uv_size;
    float4 red = nmSample(redLocalUV);

    float2 greenLocalUV = (globalUV * uv_size - float2(0.0, 0.0)) / uv_size;
    float4 green = nmSample(greenLocalUV);

    float2 blueGlobalUV = globalUV - float2(boundedDisplacement, 0.0);
    float2 blueLocalUV = (blueGlobalUV * uv_size - float2(0.0, 0.0)) / uv_size;
    float4 blue = nmSample(blueLocalUV);

    fragColor = float4(red.r, green.g, blue.b, green.a);
    return fragColor;
}
