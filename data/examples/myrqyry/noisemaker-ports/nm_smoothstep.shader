// OBS HLSL adaptation of Noisemaker filter/smoothstep/smoothstep.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/smoothstep
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// OBS sampler is border-black; explicitly clamp to WebGL2 source sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Smoothstep threshold effect
 * Creates smooth transition between edge0 and edge1
 */
uniform float edge0<
    string label = "Edge0";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.0;
uniform float edge1<
    string label = "Edge1";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;
float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 texSize = uv_size;
    float2 uv = (v_in.uv * uv_size) / texSize;
    float4 color = nmSample(uv);

    if (edge1 <= edge0) color.rgb = step(edge0, color.rgb);
    else color.rgb = smoothstep(edge0, edge1, color.rgb);

    fragColor = color;
    return fragColor;
}
