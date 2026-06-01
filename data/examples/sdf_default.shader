// Nice default generative SDF shader for shader_source
// Animated smooth metaballs with soft edges and color cycling

uniform float Speed<
    string label = "Animation Speed";
    string widget_type = "slider";
    float minimum = 0.1;
    float maximum = 4.0;
    float step = 0.1;
> = 1.0;

uniform float Smoothness<
    string label = "Smooth Union";
    string widget_type = "slider";
    float minimum = 0.05;
    float maximum = 0.8;
    float step = 0.01;
> = 0.35;

uniform float Glow<
    string label = "Glow Amount";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 2.0;
    float step = 0.05;
> = 0.8;

float sdCircle(float2 p, float r)
{
    return length(p) - r;
}

float smin(float a, float b, float k)
{
    float h = max(k - abs(a - b), 0.0);
    return min(a, b) - h * h * 0.25 / k;
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = (v_in.uv - 0.5) * uv_size.yx / uv_size.y;
    float t = elapsed_time * Speed;

    // 5 animated metaballs
    float2 c1 = float2(sin(t * 0.7) * 0.35, cos(t * 0.9) * 0.28);
    float2 c2 = float2(sin(t * 1.1 + 1.0) * 0.32, cos(t * 0.8 + 2.0) * 0.25);
    float2 c3 = float2(sin(t * 0.6 + 3.0) * 0.30, cos(t * 1.2 + 1.5) * 0.30);
    float2 c4 = float2(sin(t * 0.95 + 4.0) * 0.28, cos(t * 0.75 + 0.5) * 0.27);
    float2 c5 = float2(sin(t * 0.85 + 2.5) * 0.33, cos(t * 1.05 + 3.5) * 0.24);

    float d1 = sdCircle(uv - c1, 0.18);
    float d2 = sdCircle(uv - c2, 0.15);
    float d3 = sdCircle(uv - c3, 0.17);
    float d4 = sdCircle(uv - c4, 0.16);
    float d5 = sdCircle(uv - c5, 0.14);

    float d = d1;
    d = smin(d, d2, Smoothness);
    d = smin(d, d3, Smoothness);
    d = smin(d, d4, Smoothness);
    d = smin(d, d5, Smoothness);

    // Soft edge + inner glow
    float edge = 1.0 - smoothstep(0.0, 0.012, d);
    float inner = 1.0 - smoothstep(-0.08, 0.0, d);

    // Color cycling
    float3 colA = float3(0.95, 0.35, 0.55);
    float3 colB = float3(0.35, 0.75, 0.95);
    float3 colC = float3(0.55, 0.95, 0.45);
    float3 col = lerp(colA, colB, sin(t * 0.3) * 0.5 + 0.5);
    col = lerp(col, colC, sin(t * 0.17 + 1.5) * 0.5 + 0.5);

    float3 final = col * (edge * 0.9 + inner * Glow * 0.6);
    float alpha = saturate(edge + inner * 0.3);

    return float4(final, alpha);
}
