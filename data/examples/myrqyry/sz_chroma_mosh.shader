// Chroma Mosh — OBS Shaderfilter standalone template-mode filter.
// Spatial color displacement using original luma and different source chroma; not a frame-codec datamosh.
// Source: SZION, src/editor/effects/builtins/chromaMosh.ts (adapted from Pixhell42/GLEECH, MIT)
// Set "Override Entire Effect" OFF; source texture comes from Shaderfilter.
// Source RGB is alpha-divided by Shaderfilter's standard input path;
// pass the original source alpha through without forcing opacity.
uniform float Mix<
    string label = "Effect Mix";
    string group = "Output";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 1.0;
uniform float Travel_Pixels<
    string label = "Chroma travel (px)";
    string group = "Displacement";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 75.0; float step = 1.0;
> = 22.0;
uniform float Cell_Pixels<
    string label = "Color block size (px)";
    string group = "Displacement";
    string widget_type = "slider";
    float minimum = 2.0; float maximum = 80.0; float step = 1.0;
> = 16.0;
uniform float Angle<
    string label = "Direction (degrees)";
    string group = "Displacement";
    string widget_type = "slider";
    float minimum = -180.0; float maximum = 180.0; float step = 5.0;
> = 0.0;
uniform float Density<
    string label = "Affected blocks";
    string group = "Displacement";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.9;
uniform float Color_Mix<
    string label = "Moved color";
    string group = "Color";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.95;
uniform float Rate<
    string label = "Refresh (Hz)";
    string group = "Motion";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 20.0; float step = 1.0;
> = 3.0;

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

    float2 size = max(uv_size, float2(1.0, 1.0));
    float2 pixel = uv * size;
    float2 cell = floor(pixel / max(Cell_Pixels, 1.0));
    float tick = floor(elapsed_time * Rate);
    float chance = rw_hash(cell + float2(tick, 17.0));
    if (chance >= Density) return original;
    float a = Angle * 0.01745329252;
    float2 axis = float2(cos(a), sin(a));
    float scatter = 0.5 + rw_hash(cell + float2(tick, 71.0));
    float2 centerUv = (cell + 0.5) * Cell_Pixels / size;
    float2 sourceUv = saturate(centerUv - axis * Travel_Pixels * scatter / size);
    float3 other = image.Sample(textureSampler, sourceUv).rgb;
    float3 lumaWeights = float3(0.299, 0.587, 0.114);
    float originalY = dot(original.rgb, lumaWeights);
    float otherY = dot(other, lumaWeights);
    float3 displacedChroma = other - otherY;
    float3 desired = original.rgb + (displacedChroma -
        (original.rgb - originalY)) * Color_Mix;
    // Preserve source brightness as far as output gamut permits.
    float3 processed = saturate(desired);
    return lerp(original, float4(processed, original.a), Mix);
}
