// OBS HLSL adaptation of Noisemaker filter/chromaticAberration/chromaticAberration.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/chromaticAberration
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
uniform float aberrationAmt<
    string label = "Aberration amt";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 0.01;
> = 50.0;
uniform float passthru<
    string label = "Passthru";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 0.01;
> = 50.0;
#define PI 3.14159265359
#define aspectRatio uv_size.x / uv_size.y

float map(float value, float inMin, float inMax, float outMin, float outMax) {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 uv = globalCoord / uv_size;
    float2 fullRes = uv_size.x > 0.0 ? uv_size : uv_size;
    float2 globalUV = ((v_in.uv * uv_size) + float2(0.0, 0.0)) / fullRes;
    float globalAspect = fullRes.x / fullRes.y;

    float2 diff = float2(0.5 * globalAspect, 0.5) - float2(globalUV.x * globalAspect, globalUV.y);
    float centerDist = length(diff);

    float aberrationOffset = map(aberrationAmt, 0.0, 100.0, 0.0, 0.05) * centerDist * PI * 0.5;

    float redOffset = lerp(clamp(uv.x + aberrationOffset, 0.0, 1.0), uv.x, uv.x);
    float4 red = nmSample(((float2(redOffset, uv.y)) * uv_size - float2(0.0, 0.0)) / uv_size);

    float4 green = nmSample((v_in.uv * uv_size) / uv_size);

    float blueOffset = lerp(uv.x, clamp(uv.x - aberrationOffset, 0.0, 1.0), uv.x);
    float4 blue = nmSample(((float2(blueOffset, uv.y)) * uv_size - float2(0.0, 0.0)) / uv_size);

    // chromatic aberration - extract color fringing edges only
    float3 aberrated = float3(red.r, green.g, blue.b);
    float3 edges = aberrated - green.rgb;

    // scale original by passthru and add to edges
    float3 original = green.rgb * map(passthru, 0.0, 100.0, 0.0, 2.0);

    fragColor = float4(min(edges + original, 1.0), green.a);
    return fragColor;
}
