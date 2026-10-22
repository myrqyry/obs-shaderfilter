// =============================================================================
// Pixel Sort
// =============================================================================
// @name        Pixel Sort
// @category    Stylization
// @tags        glitch, directional, pixel-sort
// @complexity  advanced
// @description Sorts bounded, contiguous above-threshold pixel runs by
//              luminance along a selected direction.
// =============================================================================

uniform string Notes_Header<
    string label = "About";
    string widget_type = "info";
> = "Sorts contiguous bright runs by luminance. Each run is limited by Max Sort Length.";

uniform float Threshold<
    string label = "Brightness Threshold";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.5;

uniform float Length<
    string label = "Max Sort Length (px)";
    string widget_type = "slider";
    float minimum = 4.0;
    float maximum = 64.0;
    float step = 1.0;
> = 32.0;

uniform int Direction<
    string label = "Direction";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "Horizontal";
    int option_1_value = 1;
    string option_1_label = "Vertical";
    int option_2_value = 2;
    string option_2_label = "Diagonal Down";
    int option_3_value = 3;
    string option_3_label = "Diagonal Up";
> = 0;

uniform bool Descending<
    string label = "Sort Bright-to-Dark";
> = false;

uniform float Amount<
    string label = "Amount";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;

float pixel_sort_luma(float3 color)
{
    return dot(color, float3(0.299, 0.587, 0.114));
}

bool pixel_sort_inside(float2 uv)
{
    return uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
}

float4 mainImage(VertData v_in) : TARGET
{
    float4 src = image.Sample(textureSampler, v_in.uv);
    float source_luma = pixel_sort_luma(src.rgb);
    if (src.a <= 0.001 || source_luma < Threshold || Amount <= 0.0)
        return src;

    float2 direction;
    if (Direction == 0) {
        direction = float2(1.0, 0.0);
    } else if (Direction == 1) {
        direction = float2(0.0, 1.0);
    } else if (Direction == 2) {
        direction = float2(0.70710678, 0.70710678);
    } else {
        direction = float2(0.70710678, -0.70710678);
    }
    direction *= uv_pixel_interval;

    int max_count = int(Length + 0.5);
    int backward_limit = (max_count - 1) / 2;
    int forward_limit = max_count - 1 - backward_limit;
    int backward_count = 0;
    int forward_count = 0;

    // Find this pixel's contiguous bright run, stopping at dark/transparent
    // pixels or the bounded sort window.
    for (int i = 1; i <= 63; i++) {
        if (i > backward_limit)
            break;
        float2 sample_uv = v_in.uv - direction * float(i);
        if (!pixel_sort_inside(sample_uv))
            break;
        float4 sample_color = image.Sample(textureSampler, sample_uv);
        if (sample_color.a <= 0.001 || pixel_sort_luma(sample_color.rgb) < Threshold)
            break;
        backward_count++;
    }

    for (int i = 1; i <= 63; i++) {
        if (i > forward_limit)
            break;
        float2 sample_uv = v_in.uv + direction * float(i);
        if (!pixel_sort_inside(sample_uv))
            break;
        float4 sample_color = image.Sample(textureSampler, sample_uv);
        if (sample_color.a <= 0.001 || pixel_sort_luma(sample_color.rgb) < Threshold)
            break;
        forward_count++;
    }

    int run_count = backward_count + 1 + forward_count;
    float4 run_pixels[64];
    float run_luminance[64];

    for (int i = 0; i < run_count; i++) {
        int run_offset = i - backward_count;
        float2 sample_uv = v_in.uv + direction * float(run_offset);
        float4 sample_color = image.Sample(textureSampler, sample_uv);
        run_pixels[i] = sample_color;
        run_luminance[i] = pixel_sort_luma(sample_color.rgb);
    }

    // Insertion-sort the bounded run by luminance, carrying whole pixels.
    for (int i = 1; i < run_count; i++) {
        float4 key_pixel = run_pixels[i];
        float key_luminance = run_luminance[i];
        int j = i - 1;
        while (j >= 0) {
            bool move_pixel = Descending
                ? run_luminance[j] < key_luminance
                : run_luminance[j] > key_luminance;
            if (!move_pixel)
                break;
            run_pixels[j + 1] = run_pixels[j];
            run_luminance[j + 1] = run_luminance[j];
            j--;
        }
        run_pixels[j + 1] = key_pixel;
        run_luminance[j + 1] = key_luminance;
    }

    int sorted_index = Descending ? run_count - 1 - backward_count : backward_count;
    float4 sorted_pixel = run_pixels[sorted_index];
    return lerp(src, sorted_pixel, Amount);
}
