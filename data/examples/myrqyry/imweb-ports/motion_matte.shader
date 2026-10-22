// Motion Matte — frame-difference mask for OBS Shaderfilter.
// An independent implementation inspired by ImWeb's MotionExtract concept.
// This is FRAME DIFFERENCING against previous_image, not a learned background
// model or ImWeb's running-background/trail algorithm. Stopped subjects fade
// from the matte immediately. Use on a video filter, not a generative source.
//
// In Matte mode, bright means movement; in Cutout, moving pixels retain their
// video with alpha; in Highlight, moving pixels tint the unaltered source.

// Required for Shaderfilter to retain and bind the previous INPUT frame.
uniform texture2d previous_image;

uniform float gain<
    string label = "Motion Sensitivity";
    string widget_type = "slider";
    float minimum = 0.25;
    float maximum = 16.0;
    float step = 0.05;
> = 5.0;

uniform float threshold<
    string label = "Motion Threshold";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.5;
    float step = 0.005;
> = 0.08;

uniform float feather<
    string label = "Threshold Feather";
    string widget_type = "slider";
    float minimum = 0.005;
    float maximum = 0.5;
    float step = 0.005;
> = 0.10;

uniform float blur_pixels<
    string label = "Before-Difference Blur (px)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 6.0;
    float step = 0.25;
> = 1.0;

uniform int comparison<
    string label = "Difference Channel";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "Luminance";
    int option_1_value = 1;
    string option_1_label = "Strongest RGB Channel";
> = 1;

uniform int display_mode<
    string label = "Output";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "Motion Matte";
    int option_1_value = 1;
    string option_1_label = "Moving Cutout";
    int option_2_value = 2;
    string option_2_label = "Motion Highlight";
> = 0;

uniform float highlight_strength<
    string label = "Highlight Blend";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.75;

// Suppress a flash at startup AND each disabled-to-enabled transition.
// This is a startup suppression, not a stored background image.
uniform float warmup_seconds<
    string label = "History Warmup (s)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.025;
> = 0.1;

float3 current_smoothed(float2 uv, float2 offset)
{
    float3 c = image.Sample(textureSampler, uv).rgb;
    if (blur_pixels <= 0.001)
        return c;
    float3 n = image.Sample(textureSampler, saturate(uv + float2(offset.x, 0.0))).rgb;
    float3 s = image.Sample(textureSampler, saturate(uv - float2(offset.x, 0.0))).rgb;
    float3 e = image.Sample(textureSampler, saturate(uv + float2(0.0, offset.y))).rgb;
    float3 w = image.Sample(textureSampler, saturate(uv - float2(0.0, offset.y))).rgb;
    return (c * 4.0 + n + s + e + w) * 0.125;
}

float3 previous_smoothed(float2 uv, float2 offset)
{
    float3 c = previous_image.Sample(textureSampler, uv).rgb;
    if (blur_pixels <= 0.001)
        return c;
    float3 n = previous_image.Sample(textureSampler, saturate(uv + float2(offset.x, 0.0))).rgb;
    float3 s = previous_image.Sample(textureSampler, saturate(uv - float2(offset.x, 0.0))).rgb;
    float3 e = previous_image.Sample(textureSampler, saturate(uv + float2(0.0, offset.y))).rgb;
    float3 w = previous_image.Sample(textureSampler, saturate(uv - float2(0.0, offset.y))).rgb;
    return (c * 4.0 + n + s + e + w) * 0.125;
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float4 live = image.Sample(textureSampler, uv);
    float2 offset = uv_pixel_interval * blur_pixels;
    float3 a = current_smoothed(uv, offset);
    float3 b = previous_smoothed(uv, offset);
    float3 d = abs(a - b);
    // Luminance mode compares brightness, not weighted RGB magnitudes.
    // Equiluminant hue changes therefore remain quiet in Luminance mode.
    float raw = (comparison == 0) ?
                abs(dot(a, float3(0.299, 0.587, 0.114)) -
                    dot(b, float3(0.299, 0.587, 0.114))) :
                max(d.r, max(d.g, d.b));
    float amount = saturate(raw * gain);
    float motion = smoothstep(threshold, threshold + max(0.001, feather), amount);
    if (warmup_seconds > 0.0001)
        motion *= saturate(elapsed_time_enable / warmup_seconds);

    if (display_mode == 1) {
        // Shaderfilter provides straight-alpha RGB in the standard wrapper.
        // Scale alpha only: premultiplying RGB here would darken the moving
        // subject twice when Shaderfilter applies compositing.
        return float4(live.rgb, live.a * motion);
    }
    if (display_mode == 2) {
        return float4(lerp(live.rgb, float3(1.0, 0.32, 0.06), motion * highlight_strength), live.a);
    }
    return float4(motion, motion, motion, live.a);
}
