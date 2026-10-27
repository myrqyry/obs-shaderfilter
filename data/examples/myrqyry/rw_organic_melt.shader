// Organic Noise Melt — OBS Shaderfilter standalone template-mode filter.
// Accident 005 inspired: smooth deforming low-frequency noise field with time modulation.
// Source: Jan Kohlbach, real-world-shader (MIT), https://github.com/jankohlbach/real-world-shader ; see REAL-WORLD-SHADER-LICENSE.txt
// Set "Override Entire Effect" OFF; source texture comes from Shaderfilter.
// Source RGB is alpha-divided by Shaderfilter's standard input path;
// pass the original source alpha through without forcing opacity.
uniform float Mix<
    string label = "Effect Mix";
    string group = "Output";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 1.0;
uniform float Displacement<
    string label = "Warp amplitude";
    string group = "Motion";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.3; float step = 0.005;
> = 0.11;
uniform float Noise_Scale<
    string label = "Organic noise scale";
    string group = "Detail";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 30.0; float step = 0.5;
> = 9.0;
uniform float Speed<
    string label = "Flow rate";
    string group = "Motion";
    string widget_type = "slider";
    float minimum = -3.0; float maximum = 3.0; float step = 0.05;
> = 0.6;

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
    if (Mix <= 0.0) return original;

    float2 p = uv * Noise_Scale;
    float t = elapsed_time * Speed;
    float noiseX = rw_noise(p + float2(t, 0.0)) * 2.0 - 1.0;
    float noiseY = rw_noise(p + float2(19.7, -t + 7.3)) * 2.0 - 1.0;
    float2 movedUv = saturate(uv + float2(noiseX, noiseY) * Displacement);
    float4 warped = image.Sample(textureSampler, movedUv);
    return lerp(original, float4(warped.rgb, original.a), Mix);
}
