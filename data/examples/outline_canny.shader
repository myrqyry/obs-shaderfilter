// Modern Canny-style Outline Filter
// Single-pass Sobel edge detection with thickness, color, and glow

uniform float Threshold<
    string label = "Edge Threshold";
    string widget_type = "slider";
    float minimum = 0.01;
    float maximum = 1.0;
    float step = 0.01;
> = 0.15;

uniform float Thickness<
    string label = "Thickness";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 4.0;
    float step = 0.1;
> = 1.0;

uniform float4 EdgeColor<
    string label = "Edge Color";
> = { 0.0, 0.0, 0.0, 1.0 };

uniform float Glow<
    string label = "Glow Amount";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 2.0;
    float step = 0.05;
> = 0.6;

uniform float GlowRadius<
    string label = "Glow Radius";
    string widget_type = "slider";
    float minimum = 1.0;
    float maximum = 8.0;
    float step = 0.5;
> = 3.0;

float4 mainImage(VertData v_in) : TARGET
{
    float2 px = uv_pixel_interval;

    // Sobel kernels
    float3 gx =
        -1.0 * image.Sample(textureSampler, v_in.uv + float2(-px.x, -px.y)).rgb +
        -2.0 * image.Sample(textureSampler, v_in.uv + float2(-px.x,  0.0)).rgb +
        -1.0 * image.Sample(textureSampler, v_in.uv + float2(-px.x,  px.y)).rgb +
         1.0 * image.Sample(textureSampler, v_in.uv + float2( px.x, -px.y)).rgb +
         2.0 * image.Sample(textureSampler, v_in.uv + float2( px.x,  0.0)).rgb +
         1.0 * image.Sample(textureSampler, v_in.uv + float2( px.x,  px.y)).rgb;

    float3 gy =
        -1.0 * image.Sample(textureSampler, v_in.uv + float2(-px.x, -px.y)).rgb +
        -2.0 * image.Sample(textureSampler, v_in.uv + float2( 0.0, -px.y)).rgb +
        -1.0 * image.Sample(textureSampler, v_in.uv + float2( px.x, -px.y)).rgb +
         1.0 * image.Sample(textureSampler, v_in.uv + float2(-px.x,  px.y)).rgb +
         2.0 * image.Sample(textureSampler, v_in.uv + float2( 0.0,  px.y)).rgb +
         1.0 * image.Sample(textureSampler, v_in.uv + float2( px.x,  px.y)).rgb;

    float edge = length(gx) + length(gy);
    float strength = saturate((edge - Threshold) * 10.0);

    // Thickness via distance
    float thick = max(0.0, Thickness - 1.0);
    if (thick > 0.0) {
        float d = 0.0;
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                float2 off = float2(x, y) * px * thick;
                float e = length(image.Sample(textureSampler, v_in.uv + off).rgb);
                d = max(d, e);
            }
        }
        strength = max(strength, saturate((d - Threshold) * 8.0));
    }

    float4 src = image.Sample(textureSampler, v_in.uv);

    // Glow
    float3 glowCol = 0.0;
    if (Glow > 0.0) {
        float gsum = 0.0;
        for (int x = -2; x <= 2; x++) {
            for (int y = -2; y <= 2; y++) {
                float2 off = float2(x, y) * px * GlowRadius;
                float e = length(image.Sample(textureSampler, v_in.uv + off).rgb);
                float w = 1.0 - length(float2(x, y)) / 3.0;
                glowCol += EdgeColor.rgb * saturate((e - Threshold) * 6.0) * w;
                gsum += w;
            }
        }
        glowCol /= max(gsum, 0.001);
    }

    float3 final = lerp(src.rgb, EdgeColor.rgb, strength);
    final += glowCol * Glow * (1.0 - strength);

    return float4(final, src.a);
}
