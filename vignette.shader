uniform float VignetteRadius<
    string label = "Vignette Radius";
    string widget_type = "slider";
    float minimum = 0.1;
    float maximum = 1.5;
    float step = 0.01;
> = 0.6;

uniform float VignetteSoftness<
    string label = "Vignette Softness";
    string widget_type = "slider";
    float minimum = 0.01;
    float maximum = 1.0;
    float step = 0.01;
> = 0.4;

uniform float4 VignetteColor<
    string label = "Vignette Color";
> = { 0.0, 0.0, 0.0, 1.0 };

float4 mainImage(VertData v_in) : TARGET
{
    float4 original = image.Sample(textureSampler, v_in.uv);

    float2 center = v_in.uv - 0.5;
    float dist = length(center);

    float pulse = 1.0 + 0.05 * sin(elapsed_time * 1.5);
    float radius = VignetteRadius * pulse;
    float innerEdge = max(radius - VignetteSoftness, 0.001);

    float vignette = 1.0 - smoothstep(innerEdge, radius, dist);

    return lerp(VignetteColor, original, vignette);
}
