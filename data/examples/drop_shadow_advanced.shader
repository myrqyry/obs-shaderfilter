uniform int shadow_offset_x<
    string label = "Shadow Offset X";
    string widget_type = "slider";
    int minimum = -100;
    int maximum = 100;
    int step = 1;
> = 8;
uniform int shadow_offset_y<
    string label = "Shadow Offset Y";
    string widget_type = "slider";
    int minimum = -100;
    int maximum = 100;
    int step = 1;
> = 8;
uniform float4 shadow_color;
uniform int blur_size<
    string label = "Blur Size";
    string widget_type = "slider";
    int minimum = 1;
    int maximum = 40;
    int step = 1;
> = 6;
uniform string notes<
    string widget_type = "info";
> = "EXPANSION REQUIRED. Set Horizontal Expansion (Left/Right) to at least  | OffsetX | + BlurSize  on each side where the shadow extends. Set Vertical Expansion (Top/Bottom) to at least  | OffsetY | + BlurSize . Example: Offset X=8, Y=8, Blur=6 => expand Right 14, Bottom 14. Tip: set shadow_color alpha to ~0.3-0.5 for a natural look.";

float4 mainImage(VertData v_in) : TARGET
{
    float4 source = image.Sample(textureSampler, v_in.uv);

    float2 shadow_uv = v_in.uv - float2(
        float(shadow_offset_x) * uv_pixel_interval.x,
        float(shadow_offset_y) * uv_pixel_interval.y
    );

    float shadow_alpha = 0.0;
    float kernel_samples = 0.0;

    [loop] for (int x = -blur_size; x <= blur_size; x++)
    {
        [loop] for (int y = -blur_size; y <= blur_size; y++)
        {
            float2 sample_uv = shadow_uv + float2(
                float(x) * uv_pixel_interval.x,
                float(y) * uv_pixel_interval.y
            );
            shadow_alpha += image.Sample(textureSampler, sample_uv).a;
            kernel_samples += 1.0;
        }
    }

    shadow_alpha /= kernel_samples;

    float4 shadow = float4(shadow_color.rgb, shadow_color.a * shadow_alpha);

    return shadow * (1.0 - source.a) + source;
}
