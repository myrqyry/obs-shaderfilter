// Micro Noise Displacement — OBS Shaderfilter standalone template-mode filter.
// Accident 002 inspired: high-frequency noisy UV offsets, not color grain.
// Source: Jan Kohlbach, real-world-shader (MIT), https://github.com/jankohlbach/real-world-shader ; see REAL-WORLD-SHADER-LICENSE.txt
// Set "Override Entire Effect" OFF; source texture comes from Shaderfilter.
// Source RGB is alpha-divided by Shaderfilter's standard input path;
// pass the original source alpha through without forcing opacity.
uniform float Distortion<
    string label = "Displacement amount";
    string group = "Effect";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.15; float step = 0.002;
> = 0.075;
uniform float Detail_Pixels<
    string label = "Noise cell size (px)";
    string group = "Effect";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 16.0; float step = 1.0;
> = 2.0;
uniform float Updates_Per_Second<
    string label = "Noise refresh rate";
    string group = "Motion";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 30.0; float step = 1.0;
> = 12.0;

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
    float2 cell = floor(uv * size / max(Detail_Pixels, 1.0));
    float tick = floor(elapsed_time * Updates_Per_Second);
    float2 displacement = float2(rw_hash(cell + float2(tick, 7.0)),
                                 rw_hash(cell + float2(19.0, tick))) * 2.0 - 1.0;
    float4 sampled = image.Sample(textureSampler, saturate(uv + displacement * Distortion));
    return float4(sampled.rgb, original.a);
}
