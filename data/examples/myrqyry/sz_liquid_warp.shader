// Liquid Warp — OBS Shaderfilter standalone template-mode filter.
// Screen-space translation of SZION multi-frequency liquid sine displacements.
// Source: SZION, src/editor/effects/builtins/liquidWarp.ts (our WGSL effect)
// Set "Override Entire Effect" OFF; source texture comes from Shaderfilter.
// Source RGB is alpha-divided by Shaderfilter's standard input path;
// pass the original source alpha through without forcing opacity.
uniform float Mix<
    string label = "Effect Mix";
    string group = "Output";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 1.0;
uniform float Amount<
    string label = "Displacement";
    string group = "Warp";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.08; float step = 0.001;
> = 0.025;
uniform float Scale<
    string label = "Wave scale";
    string group = "Warp";
    string widget_type = "slider";
    float minimum = 0.5; float maximum = 14.0; float step = 0.1;
> = 3.5;
uniform float Speed<
    string label = "Flow speed";
    string group = "Motion";
    string widget_type = "slider";
    float minimum = -3.0; float maximum = 3.0; float step = 0.05;
> = 0.35;


float4 mainImage(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 original = image.Sample(textureSampler, uv);
    if (Mix <= 0.0) return original;

    float phase = elapsed_time * Speed;
    float frequency = max(Scale, 0.1);
    float waveX = sin((uv.y * frequency + phase) * 6.2831853) +
        0.45 * sin((uv.y * frequency * 0.47 - phase * 1.3) * 6.2831853);
    float waveY = cos((uv.x * frequency * 0.83 - phase * 0.8) * 6.2831853) +
        0.35 * sin((uv.x * frequency * 1.7 + phase) * 6.2831853);
    float2 sourceUv = saturate(uv + float2(waveX, waveY) * Amount);
    float4 warped = image.Sample(textureSampler, sourceUv);
    return lerp(original, float4(warped.rgb, original.a), Mix);
}
