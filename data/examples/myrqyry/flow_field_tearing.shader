// =============================================================================
// Flow Field Tearing — GLEECH-inspired still-image field + signal-tearing concept
// Original OBS/HLSL implementation for moving sources; not copied WGSL.
// Source concept: https://github.com/Pixhell42/GLEECH (MIT).
// @name Flow Field Tearing
// @category Distortion
// @tags field, vector, signal-tearing, displacement, procedural
// =============================================================================

uniform string Info <
    string label = "About";
    string widget_type = "info";
> = "Seeded signal slices steered by a procedural field or optional RG vector map. Hold Speed at zero for a still effect.";

uniform float Amount <
    string label = "Effect Mix";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.6;

uniform float Density <
    string label = "Active Slice Density";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.36;

uniform float BandPixels <
    string label = "Slice Spacing (pixels)";
    string widget_type = "slider";
    float minimum = 2.0;
    float maximum = 80.0;
    float step = 1.0;
> = 14.0;

uniform float Displacement <
    string label = "Displacement (pixels)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 1.0;
> = 17.0;

uniform float BandAngle <
    string label = "Slice Orientation (degrees)";
    string widget_type = "slider";
    float minimum = -180.0;
    float maximum = 180.0;
    float step = 1.0;
> = 0.0;

uniform float TravelAngle <
    string label = "Travel Direction (degrees)";
    string widget_type = "slider";
    float minimum = -180.0;
    float maximum = 180.0;
    float step = 1.0;
> = 0.0;

uniform float FieldInfluence <
    string label = "Flow Influence";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.45;

uniform float FlowScale <
    string label = "Flow Scale";
    string widget_type = "slider";
    float minimum = 1.0;
    float maximum = 25.0;
    float step = 0.25;
> = 7.0;

uniform float Softness <
    string label = "Slice Edge Feather";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.13;

uniform float HoldSpeed <
    string label = "Change Speed (steps/sec)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 24.0;
    float step = 0.5;
> = 4.0;

uniform float Seed <
    string label = "Seed";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1000.0;
    float step = 1.0;
> = 19.0;

uniform bool UseVectorMap <
    string label = "Use RG Vector Map";
> = false;

uniform texture2d VectorMap <
    string label = "RG Vector Map (128 neutral)";
>;

float field_hash(float2 p)
{
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float2 field_flow(float2 uv, float scale, float phase)
{
    float2 p = uv * scale;
    float a = sin(p.x * 2.31 + sin(p.y * 1.7 + phase))
            + cos(p.y * 2.07 + cos(p.x * 1.29 - phase));
    return float2(cos(a * 3.14159265), sin(a * 3.14159265));
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float4 original = image.Sample(textureSampler, uv);
    if (Amount <= 0.0 || Density <= 0.0 || Displacement <= 0.0)
        return original;

    float angle = BandAngle * 0.01745329252;
    float2 normal = float2(-sin(angle), cos(angle));
    // Pixel-space orientation keeps band widths unchanged across output sizes.
    float q = dot(uv * uv_size, normal);
    float width = max(2.0, BandPixels);
    float band = floor(q / width);
    float tick = (HoldSpeed > 0.0) ? floor(elapsed_time * HoldSpeed) : 0.0;
    float2 identity = float2(band + Seed * 0.27, tick + Seed * 0.79);
    if (field_hash(identity) >= Density)
        return original;

    float distance = (field_hash(identity + float2(83.0, 47.0)) * 2.0 - 1.0) * Displacement;
    float fraction = frac(q / width);
    float feather = 1.0;
    if (Softness > 0.0)
        feather = saturate(min(fraction, 1.0 - fraction) * 2.0 / max(Softness, 0.001));
    distance *= feather;

    float travel = TravelAngle * 0.01745329252;
    float2 base = float2(cos(travel), sin(travel));
    // Pixel-dependent flow is sampled at the original UV, never recursively.
    float2 flow = field_flow(uv, FlowScale, Seed * 0.017);
    if (UseVectorMap) {
        float4 map = VectorMap.Sample(textureSampler, uv);
        // GLEECH-compatible convention: red/green = X/Y; 128/255 = neutral.
        float2 vector = (map.rg * 255.0 - 128.0) / 127.0;
        flow = lerp(base, vector, map.a);
    }
    float2 steered = lerp(base, flow, saturate(FieldInfluence));
    float magnitude = max(length(steered), 0.0001);
    float2 offset = steered / magnitude * distance * uv_pixel_interval;
    float2 sampleUV = saturate(uv + offset);
    float4 shifted = image.Sample(textureSampler, sampleUV);
    // Keep source alpha; displacement cannot create opacity outside the source.
    return float4(lerp(original.rgb, shifted.rgb, saturate(Amount)), original.a);
}
