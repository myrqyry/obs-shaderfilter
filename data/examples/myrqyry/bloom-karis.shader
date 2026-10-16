// Modern fixed-cost bloom for obs-shaderfilter.
//
// Inspired by the bloom structure in Luna5ama/Alpha-Piscium:
// - soft threshold instead of hard clipping
// - Karis weighting so isolated hot pixels do not dominate the blur
// - multiple spatial scales for a broad glow without dynamic nested loops
//
// This is intentionally a single-pass approximation. A true downsample/
// upsample pyramid requires host-side intermediate render targets (implemented
// in emuLensFX), which ordinary shader mode does not expose.

uniform float bloom_intensity<
    string label = "Intensity";
    string widget_type = "slider";
    string group = "Bloom";
    float minimum = 0.0;
    float maximum = 5.0;
    float step = 0.01;
> = 1.0;

uniform float bloom_threshold<
    string label = "Threshold";
    string widget_type = "slider";
    string group = "Bloom";
    float minimum = 0.0;
    float maximum = 1.5;
    float step = 0.01;
> = 0.65;

uniform float bloom_softness<
    string label = "Soft Knee";
    string widget_type = "slider";
    string group = "Bloom";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.35;

uniform float bloom_radius<
    string label = "Radius";
    string widget_type = "slider";
    string group = "Bloom";
    float minimum = 0.25;
    float maximum = 6.0;
    float step = 0.05;
> = 1.5;

uniform string bloom_notes<
    string widget_type = "info";
    string group = "Bloom";
> = "Fixed 39-sample Karis bloom. Increase the filter's extra pixels if the glow is clipped at source edges.";

float3 bloom_extract(float3 color)
{
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    float knee = max(bloom_softness, 0.0001);
    float mask = saturate((luma - (bloom_threshold - knee)) / knee);
    return max(color, 0.0) * mask;
}

float bloom_karis_weight(float3 color)
{
    float luma = dot(max(color, 0.0), float3(0.2126, 0.7152, 0.0722));
    return 1.0 / (1.0 + luma);
}

float4 bloom_tap(float2 uv, float spatial_weight)
{
    float3 bright = bloom_extract(image.Sample(textureSampler, uv).rgb);
    float weight = spatial_weight * bloom_karis_weight(bright);
    return float4(bright * weight, weight);
}

float3 bloom_gather13(float2 uv, float scale)
{
    float2 px = uv_pixel_interval * (bloom_radius * scale);
    float4 sum = float4(0.0, 0.0, 0.0, 0.0);

    sum += bloom_tap(uv, 0.125);

    sum += bloom_tap(uv + float2(-2.0,  0.0) * px, 0.0625);
    sum += bloom_tap(uv + float2( 2.0,  0.0) * px, 0.0625);
    sum += bloom_tap(uv + float2( 0.0, -2.0) * px, 0.0625);
    sum += bloom_tap(uv + float2( 0.0,  2.0) * px, 0.0625);

    sum += bloom_tap(uv + float2(-2.0, -2.0) * px, 0.03125);
    sum += bloom_tap(uv + float2( 2.0, -2.0) * px, 0.03125);
    sum += bloom_tap(uv + float2(-2.0,  2.0) * px, 0.03125);
    sum += bloom_tap(uv + float2( 2.0,  2.0) * px, 0.03125);

    sum += bloom_tap(uv + float2(-1.0, -1.0) * px, 0.125);
    sum += bloom_tap(uv + float2( 1.0, -1.0) * px, 0.125);
    sum += bloom_tap(uv + float2(-1.0,  1.0) * px, 0.125);
    sum += bloom_tap(uv + float2( 1.0,  1.0) * px, 0.125);

    return sum.rgb / max(sum.a, 0.0001);
}

float4 mainImage(VertData v_in) : TARGET
{
    float4 source = image.Sample(textureSampler, v_in.uv);

    float3 near_glow = bloom_gather13(v_in.uv, 1.0);
    float3 mid_glow = bloom_gather13(v_in.uv, 2.0);
    float3 far_glow = bloom_gather13(v_in.uv, 4.0);

    float3 glow = near_glow * 0.50 + mid_glow * 0.30 + far_glow * 0.20;
    return float4(source.rgb + glow * max(bloom_intensity, 0.0), source.a);
}
