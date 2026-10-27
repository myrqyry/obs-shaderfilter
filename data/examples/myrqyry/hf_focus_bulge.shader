// Focus Bulge — OBS Shaderfilter standalone template-mode filter.
// Re-adapted from realworld_focus_bulge.effect: movable glass-like magnifier with signed strength.
// Source: HyperShaderFX, /data/shaders/root/realworld_*.effect ; conceptual originals: Jan Kohlbach real-world-shader (MIT); see REAL-WORLD-SHADER-LICENSE.txt
// Set "Override Entire Effect" OFF; source texture comes from Shaderfilter.
// Source RGB is alpha-divided by Shaderfilter's standard input path;
// pass the original source alpha through without forcing opacity.
uniform float Strength<
    string label = "Bulge strength";
    string group = "Lens";
    string widget_type = "slider";
    float minimum = -0.85; float maximum = 2.5; float step = 0.01;
> = 0.9;
uniform float Center_X<
    string label = "Center X";
    string group = "Lens";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.5;
uniform float Center_Y<
    string label = "Center Y";
    string group = "Lens";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.5;
uniform float Radius<
    string label = "Radius";
    string group = "Lens";
    string widget_type = "slider";
    float minimum = 0.05; float maximum = 1.2; float step = 0.01;
> = 0.45;


float4 mainImage(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 original = image.Sample(textureSampler, uv);

    float2 size = max(uv_size, float2(1.0, 1.0));
    float2 center = float2(Center_X, Center_Y);
    float2 p = (uv - center) * float2(size.x / size.y, 1.0);
    float unitDistance = length(p) / max(Radius, 0.001);
    float weight = 1.0 - smoothstep(0.0, 1.0, unitDistance);
    float scale = max(0.08, 1.0 + Strength * weight);
    float2 sourceUv = saturate(center + (uv - center) / scale);
    float4 sampled = image.Sample(textureSampler, sourceUv);
    return float4(sampled.rgb, original.a);
}
