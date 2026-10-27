// Interactive RGB Shift — OBS Shaderfilter standalone template-mode filter.
// Re-adapted from realworld_rgb_shift.effect: center-directed chroma separation.
// Source: HyperShaderFX, /data/shaders/root/realworld_*.effect ; conceptual originals: Jan Kohlbach real-world-shader (MIT); see REAL-WORLD-SHADER-LICENSE.txt
// Set "Override Entire Effect" OFF; source texture comes from Shaderfilter.
// Source RGB is alpha-divided by Shaderfilter's standard input path;
// pass the original source alpha through without forcing opacity.
uniform float Mix<
    string label = "Effect Mix";
    string group = "Output";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 1.0;
uniform float Shift<
    string label = "Channel offset";
    string group = "Color";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.1; float step = 0.001;
> = 0.044;
uniform float Center_X<
    string label = "Center X";
    string group = "Center";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.5;
uniform float Center_Y<
    string label = "Center Y";
    string group = "Center";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.5;
uniform float Radius<
    string label = "Influence radius";
    string group = "Center";
    string widget_type = "slider";
    float minimum = 0.05; float maximum = 1.5; float step = 0.01;
> = 0.75;


float4 mainImage(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 original = image.Sample(textureSampler, uv);
    if (Mix <= 0.0) return original;

    float2 offset = uv - float2(Center_X, Center_Y);
    float dist = length(offset);
    float falloff = saturate(1.0 - dist / max(Radius, 0.001));
    float2 direction = offset / max(dist, 0.001);
    float2 channelShift = direction * Shift * falloff;
    float r = image.Sample(textureSampler, saturate(uv + channelShift)).r;
    float b = image.Sample(textureSampler, saturate(uv - channelShift)).b;
    return lerp(original, float4(r, original.g, b, original.a), Mix);
}
