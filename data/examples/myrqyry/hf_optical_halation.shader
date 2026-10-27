// Optical Halation — OBS Shaderfilter standalone template-mode filter.
// One-pass high-brightness scatter and warm halation; source driven, not procedural glare.
// Source: HyperShaderFX, /data/shaders/root/optical_halation.effect (our existing original OBS effect)
// Set "Override Entire Effect" OFF; source texture comes from Shaderfilter.
// Source RGB is alpha-divided by Shaderfilter's standard input path;
// pass the original source alpha through without forcing opacity.
uniform float Intensity<
    string label = "Bloom intensity";
    string group = "Light";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 3.0; float step = 0.05;
> = 1.1;
uniform float Threshold<
    string label = "Luma threshold";
    string group = "Light";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.5; float step = 0.02;
> = 0.46;
uniform float Soft_Knee<
    string label = "Threshold softness";
    string group = "Light";
    string widget_type = "slider";
    float minimum = 0.01; float maximum = 0.6; float step = 0.01;
> = 0.18;
uniform float Radius_Pixels<
    string label = "Halo radius (px)";
    string group = "Optics";
    string widget_type = "slider";
    float minimum = 0.5; float maximum = 12.0; float step = 0.5;
> = 5.0;
uniform float Spread<
    string label = "Outer halo scale";
    string group = "Optics";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 5.0; float step = 0.25;
> = 2.5;
uniform float Warmth<
    string label = "Warm halation";
    string group = "Color";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.05;
> = 0.65;


float3 halationBright(float2 uv) {
    float3 c = image.Sample(textureSampler, saturate(uv)).rgb;
    float y = dot(c, float3(0.2126, 0.7152, 0.0722));
    float knee = max(Soft_Knee, 0.001);
    return c * smoothstep(Threshold - knee, Threshold + knee, y);
}
float3 halationGather(float2 uv, float2 px) {
    float3 v = halationBright(uv) * 0.2;
    v += halationBright(uv + float2(px.x, 0.0)) * 0.125;
    v += halationBright(uv - float2(px.x, 0.0)) * 0.125;
    v += halationBright(uv + float2(0.0, px.y)) * 0.125;
    v += halationBright(uv - float2(0.0, px.y)) * 0.125;
    v += halationBright(uv + px) * 0.075;
    v += halationBright(uv - px) * 0.075;
    v += halationBright(uv + float2(px.x, -px.y)) * 0.075;
    v += halationBright(uv + float2(-px.x, px.y)) * 0.075;
    return v;
}

float4 mainImage(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 original = image.Sample(textureSampler, uv);

    float2 px = Radius_Pixels / max(uv_size, float2(1.0, 1.0));
    float3 nearHalo = halationGather(uv, px);
    float3 farHalo = halationGather(uv, px * Spread);
    float3 neutral = 0.6 * nearHalo + 0.4 * farHalo;
    float3 amber = farHalo * float3(1.0, 0.38, 0.18);
    float3 processed = original.rgb + Intensity *
        lerp(neutral, neutral * 0.6 + amber * 0.4, Warmth);
    return float4(processed, original.a);
}
