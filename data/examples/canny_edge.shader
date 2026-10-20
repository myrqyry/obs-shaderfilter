// Single-pass Canny-style edge overlay for obs-shaderfilter.
// Includes smoothed Sobel gradients, non-maximum suppression, double
// thresholds, and one-pixel local hysteresis. See the note below: full
// connected-edge hysteresis requires iterative passes unavailable here.

uniform float low_threshold<
    string label = "Low Threshold";
    string widget_type = "slider";
    float minimum = 0.001;
    float maximum = 0.20;
    float step = 0.001;
> = 0.025;

uniform float high_threshold<
    string label = "High Threshold";
    string widget_type = "slider";
    float minimum = 0.005;
    float maximum = 0.50;
    float step = 0.001;
> = 0.075;

uniform float4 edge_color = {1.0, 1.0, 1.0, 1.0};

uniform string canny_info<
    string widget_type = "info";
> = "Single-pass Canny stages with one-pixel local hysteresis. Global connected-edge hysteresis needs iterative/multipass processing.";

float canny_luma(float2 uv)
{
    return dot(image.Sample(textureSampler, uv).rgb, float3(0.299, 0.587, 0.114));
}

float canny_derivative_weight(int index)
{
    if (index == 0) return -1.0;
    if (index == 1) return -2.0;
    if (index == 3) return 2.0;
    if (index == 4) return 1.0;
    return 0.0;
}

float canny_smoothing_weight(int index)
{
    if (index == 0 || index == 4) return 1.0;
    if (index == 1 || index == 3) return 4.0;
    return 6.0;
}

float canny_blurred_sobel(float2 uv, out float gx, out float gy)
{
    // A 3x3 Gaussian blur convolved with Sobel gives separable 5x5
    // derivative/smoothing kernels. Combining them avoids two blur passes.
    gx = 0.0;
    gy = 0.0;

    for (int y = 0; y < 5; y++) {
        for (int x = 0; x < 5; x++) {
            float2 offset = float2(float(x) - 2.0, float(y) - 2.0) * uv_pixel_interval;
            float sample_luma = canny_luma(uv + offset);
            gx += sample_luma * canny_derivative_weight(x) * canny_smoothing_weight(y);
            gy += sample_luma * canny_smoothing_weight(x) * canny_derivative_weight(y);
        }
    }

    gx /= 128.0;
    gy /= 128.0;
    return length(float2(gx, gy));
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float gx;
    float gy;
    float magnitude = canny_blurred_sobel(uv, gx, gy);

    // Non-maximum suppression along the quantized gradient direction.
    float2 nms_direction;
    float ax = abs(gx);
    float ay = abs(gy);
    if (ay <= ax * 0.41421356) {
        nms_direction = float2(uv_pixel_interval.x, 0.0);
    } else if (ay >= ax * 2.41421356) {
        nms_direction = float2(0.0, uv_pixel_interval.y);
    } else {
        nms_direction = float2(uv_pixel_interval.x, uv_pixel_interval.y * ((gx * gy >= 0.0) ? 1.0 : -1.0));
    }

    float neighbor_gx;
    float neighbor_gy;
    float before = canny_blurred_sobel(uv - nms_direction, neighbor_gx, neighbor_gy);
    float after = canny_blurred_sobel(uv + nms_direction, neighbor_gx, neighbor_gy);
    bool is_ridge = magnitude >= before && magnitude >= after;
    float suppressed = is_ridge ? magnitude : 0.0;

    float effective_low = min(low_threshold, high_threshold);
    float effective_high = max(low_threshold, high_threshold);
    bool is_edge = suppressed >= effective_high;
    if (!is_edge && suppressed >= effective_low) {
        // Shaderfilter user shaders are single-pass. Promote weak candidates
        // touching a strong raw gradient; longer connected chains need
        // iterative hysteresis and cannot be resolved by one invocation.
        for (int y = -1; y <= 1 && !is_edge; y++) {
            for (int x = -1; x <= 1 && !is_edge; x++) {
                if (x != 0 || y != 0) {
                    float2 offset = float2(float(x), float(y)) * uv_pixel_interval;
                    // Use the same blurred-gradient scale as the current
                    // pixel; raw Sobel magnitudes are not threshold-compatible.
                    float neighbor_magnitude = canny_blurred_sobel(uv + offset, neighbor_gx, neighbor_gy);
                    is_edge = neighbor_magnitude >= effective_high;
                }
            }
        }
    }

    float4 base = image.Sample(textureSampler, uv);
    if (!is_edge)
        return base;

    float edge_alpha = saturate(edge_color.a);
    float out_alpha = edge_alpha + base.a * (1.0 - edge_alpha);
    float3 out_rgb = (edge_color.rgb * edge_alpha + base.rgb * base.a * (1.0 - edge_alpha)) / max(out_alpha, 0.0001);
    return float4(out_rgb, out_alpha);
}
