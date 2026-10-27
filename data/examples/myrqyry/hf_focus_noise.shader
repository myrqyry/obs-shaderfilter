// Focus Noise Field — OBS Shaderfilter standalone template-mode filter.
// Re-adapted from realworld_focus_noise.effect: grain outside a controllable clean aperture.
// Source: HyperShaderFX, /data/shaders/root/realworld_*.effect ; conceptual originals: Jan Kohlbach real-world-shader (MIT); see REAL-WORLD-SHADER-LICENSE.txt
// Set "Override Entire Effect" OFF; source texture comes from Shaderfilter.
// Source RGB is alpha-divided by Shaderfilter's standard input path;
// pass the original source alpha through without forcing opacity.
uniform float Noise_Strength<
    string label = "Noise amount";
    string group = "Noise";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.7; float step = 0.01;
> = 0.25;
uniform float Center_X<
    string label = "Center X";
    string group = "Aperture";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.5;
uniform float Center_Y<
    string label = "Center Y";
    string group = "Aperture";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.5;
uniform float Clean_Radius<
    string label = "Clean radius";
    string group = "Aperture";
    string widget_type = "slider";
    float minimum = 0.02; float maximum = 1.0; float step = 0.01;
> = 0.35;
uniform float Feather<
    string label = "Feather";
    string group = "Aperture";
    string widget_type = "slider";
    float minimum = 0.01; float maximum = 0.5; float step = 0.01;
> = 0.17;
uniform float Grain_Pixels<
    string label = "Grain size (px)";
    string group = "Noise";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 12.0; float step = 1.0;
> = 3.0;
uniform float Rate<
    string label = "Grain rate";
    string group = "Noise";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 30.0; float step = 1.0;
> = 13.0;

float rw_hash(float2 p) {
    float3 p3 = frac(float3(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}
float rw_noise(float2 p) {
    float2 cell = floor(p);
    float2 f = frac(p);
    f = f * f * (3.0 - 2.0 * f);
    float lo = lerp(rw_hash(cell), rw_hash(cell + float2(1.0, 0.0)), f.x);
    float hi = lerp(rw_hash(cell + float2(0.0, 1.0)), rw_hash(cell + 1.0), f.x);
    return lerp(lo, hi, f.y);
}

float4 mainImage(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 original = image.Sample(textureSampler, uv);

    float2 size = max(uv_size, float2(1.0, 1.0));
    float aspect = size.x / size.y;
    float2 relative = (uv - float2(Center_X, Center_Y)) * float2(aspect, 1.0);
    float outside = smoothstep(Clean_Radius, Clean_Radius + max(Feather, 0.001), length(relative));
    float2 cell = floor(uv * size / max(Grain_Pixels, 1.0));
    float tick = floor(elapsed_time * Rate);
    float3 grain = float3(rw_hash(cell + float2(tick, 0.0)),
                          rw_hash(cell + float2(13.0, tick)),
                          rw_hash(cell + float2(tick + 23.0, 17.0))) - 0.5;
    float3 processed = original.rgb + grain * Noise_Strength * outside;
    return float4(processed, original.a);
}
