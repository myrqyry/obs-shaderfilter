// Composite Signal — one-pass analog composite-video artifacts for OBS shaderfilter.
// Independent implementation inspired by ImWeb's signal-chain controls, not copied code.
// Models imperfect Y/C separation, finite chroma bandwidth, dot crawl, cross-colour
// and a delayed RF ghost. This is a stylized decoder, not a broadcast-standard emulator.
// All offsets are in source pixels. Source alpha is preserved.

uniform float signal_amount<
    string label = "Signal Strength";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.85;

uniform float chroma_blur<
    string label = "Chroma Bandwidth Loss";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.55;

uniform float chroma_delay<
    string label = "Chroma Delay (px)";
    string widget_type = "slider";
    float minimum = -8.0;
    float maximum = 8.0;
    float step = 0.25;
> = 1.5;

uniform float dot_crawl<
    string label = "Dot Crawl";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.5;

uniform float cross_color<
    string label = "Cross-Colour";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.35;

uniform float rf_ghost<
    string label = "RF Ghost";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.12;

uniform float ghost_delay<
    string label = "RF Ghost Delay (px)";
    string widget_type = "slider";
    float minimum = 1.0;
    float maximum = 48.0;
    float step = 1.0;
> = 14.0;

uniform float carrier_rate<
    string label = "Carrier Phase Rate (Hz)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 60.0;
    float step = 0.01;
> = 29.97;

float signal_luma(float3 rgb)
{
    return dot(rgb, float3(0.299, 0.587, 0.114));
}

float2 signal_chroma(float3 rgb)
{
    return float2(dot(rgb, float3(0.596, -0.274, -0.322)),
                  dot(rgb, float3(0.211, -0.523, 0.312)));
}

float3 signal_decode(float y, float2 iq)
{
    return float3(y + 0.956 * iq.x + 0.621 * iq.y,
                  y - 0.272 * iq.x - 0.647 * iq.y,
                  y - 1.106 * iq.x + 1.703 * iq.y);
}

float3 signal_sample(float2 uv)
{
    return image.Sample(textureSampler, saturate(uv)).rgb;
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float4 source = image.Sample(textureSampler, uv);

    // Exact identity bypass, including alpha and unclamped HDR RGB.
    if (signal_amount <= 0.0001 || source.a <= 0.0001)
        return source;

    float2 texel = max(uv_pixel_interval, float2(0.000001, 0.000001));
    float2 pos = uv / texel;
    float3 left_rgb = signal_sample(uv - float2(texel.x, 0.0));
    float3 right_rgb = signal_sample(uv + float2(texel.x, 0.0));

    float y = signal_luma(source.rgb);
    float left_y = signal_luma(left_rgb);
    float right_y = signal_luma(right_rgb);

    // The part of luminance a simple Y/C separator confuses with chroma:
    // high spatial frequencies, not arbitrary coloured screen noise.
    float high_y = y - 0.5 * (left_y + right_y);
    float line_parity = frac(floor(pos.y) * 0.5) * 2.0;
    float field_phase = frac(floor(elapsed_time * carrier_rate) * 0.5);
    float phase = (pos.x * 0.25 + line_parity * 0.5 + field_phase) * 6.2831853;
    float carrier_i = sin(phase);
    float carrier_q = cos(phase);

    // Separation errors appear near fine image detail, and alternate across
    // neighbouring scanlines. This remains static when carrier_rate = 0.
    float crawl = high_y * carrier_i * dot_crawl * 0.65;
    float colour_leak = high_y * cross_color * 0.9;
    y += crawl;

    // Luma is wide-band; I/Q chroma is delayed and horizontally low-passed.
    float2 chroma_uv = uv - float2(chroma_delay * texel.x, 0.0);
    float2 iq_center = signal_chroma(signal_sample(chroma_uv));
    float2 iq_near = 0.5 * (
        signal_chroma(signal_sample(chroma_uv - float2(2.0 * texel.x, 0.0))) +
        signal_chroma(signal_sample(chroma_uv + float2(2.0 * texel.x, 0.0))));
    float2 iq_far = 0.5 * (
        signal_chroma(signal_sample(chroma_uv - float2(4.0 * texel.x, 0.0))) +
        signal_chroma(signal_sample(chroma_uv + float2(4.0 * texel.x, 0.0))));
    float2 iq_blurred = iq_center * 0.42 + iq_near * 0.38 + iq_far * 0.20;
    float2 iq = lerp(iq_center, iq_blurred, chroma_blur);
    iq += float2(carrier_i, carrier_q) * colour_leak;

    // Multipath reception: a quieter delayed copy of luminance, keeping chroma
    // centred rather than generating an RGB split.
    float ghost_y = signal_luma(signal_sample(uv - float2(ghost_delay * texel.x, 0.0)));
    y += (ghost_y - y) * rf_ghost * 0.40;

    float3 decoded = saturate(signal_decode(y, iq));
    return float4(lerp(source.rgb, decoded, signal_amount), source.a);
}
