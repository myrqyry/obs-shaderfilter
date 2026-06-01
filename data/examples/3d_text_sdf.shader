// 3D Text SDF - 2.5D extruded procedural letters
// Default generative source (hard-coded text for cross-platform compatibility)

uniform float FontScale<
    string label = "Font Scale";
    string widget_type = "slider";
    float minimum = 0.1;
    float maximum = 3.0;
    float step = 0.05;
> = 1.0;

uniform float LetterSpacing<
    string label = "Letter Spacing";
    string widget_type = "slider";
    float minimum = 0.5;
    float maximum = 2.0;
    float step = 0.05;
> = 1.0;

uniform float CurveSimplify<
    string label = "Curve Simplify";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.0;

uniform float BevelDepth<
    string label = "Bevel Depth";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.5;
    float step = 0.01;
> = 0.15;

uniform float AnimSpeed<
    string label = "Animation Speed";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 5.0;
    float step = 0.1;
> = 1.0;

uniform float AnimAmount<
    string label = "Animation Amount";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.3;

uniform int AnimMode<
    string label = "Animation Mode";
    string widget_type = "select";
    int option_0_value = 0; string option_0_label = "Gentle Bob";
    int option_1_value = 1; string option_1_label = "Wave";
    int option_2_value = 2; string option_2_label = "Rotate";
    int option_3_value = 3; string option_3_label = "Jitter";
> = 0;

float sdCircle(float2 p, float r) { return length(p) - r; }
float sdBox(float2 p, float2 b) {
    float2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}
float sdLine(float2 p, float2 a, float2 b) {
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}
float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0);
    return min(a, b) - h * h * 0.25 / k;
}

float letterO(float2 p, float simplify) {
    float r = 0.22;
    float thick = 0.08;
    float d1 = sdCircle(p, r);
    float d2 = sdCircle(p, r - thick);
    float d = max(-d2, d1);
    float s = lerp(0.0, 0.06, simplify);
    return smin(d, sdCircle(p, r - thick + s), 0.03);
}

float letterB(float2 p, float simplify) {
    float bar = sdBox(p + float2(0.12, 0.0), float2(0.06, 0.28));
    float lobe1 = sdCircle(p + float2(-0.02, 0.12), 0.12);
    float lobe2 = sdCircle(p + float2(-0.02, -0.12), 0.12);
    return min(bar, min(lobe1, lobe2));
}

float letterS(float2 p, float simplify) {
    float d1 = sdCircle(p + float2(0.0, 0.1), 0.15);
    float d2 = sdCircle(p + float2(0.0, -0.1), 0.15);
    float cut = sdBox(p, float2(0.3, 0.05));
    return max(max(-d1, d2), -cut);
}

float letterM(float2 p, float simplify) {
    float d1 = sdLine(p, float2(-0.2, -0.25), float2(-0.05, 0.25));
    float d2 = sdLine(p, float2(-0.05, 0.25), float2(0.05, -0.1));
    float d3 = sdLine(p, float2(0.05, -0.1), float2(0.2, 0.25));
    return min(min(d1, d2), d3);
}

float letterR(float2 p, float simplify) {
    float bar = sdBox(p + float2(0.12, 0.0), float2(0.06, 0.28));
    float lobe = sdCircle(p + float2(-0.02, 0.1), 0.12);
    float cut = sdBox(p + float2(0.0, 0.12), float2(0.2, 0.12));
    return min(bar, max(lobe, -cut));
}

float textSDF(float2 p) {
    float d = 1e9;
    float x = 0.0;
    float t = elapsed_time * AnimSpeed;
    // Hard-coded "MQR" for cross-platform compatibility
    float2 lp;

    lp = p - float2(x, 0.0);
    float2 offM = float2(0.0, sin(t) * 0.08 * AnimAmount);
    d = min(d, letterM(lp + offM, CurveSimplify));
    x += 0.55 * LetterSpacing;

    lp = p - float2(x, 0.0);
    float2 offQ = float2(0.0, sin(t + 1.0) * 0.08 * AnimAmount);
    d = min(d, letterO(lp + offQ, CurveSimplify));
    x += 0.55 * LetterSpacing;

    lp = p - float2(x, 0.0);
    float2 offR = float2(0.0, sin(t + 2.0) * 0.08 * AnimAmount);
    d = min(d, letterR(lp + offR, CurveSimplify));

    return d;
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = (v_in.uv - 0.5) * uv_size.yx / uv_size.y;
    float scale = 1.0 / FontScale;
    float strW = 1.65 * LetterSpacing;
    scale *= min(1.0, 1.6 / max(strW, 0.1));
    float d = textSDF(uv * scale);
    float3 col = float3(0.95, 0.95, 1.0) * (1.0 - smoothstep(0.0, 0.012, d));
    float3 light = normalize(float3(0.6, 0.8, 1.0));
    float bevel = BevelDepth * (1.0 - smoothstep(0.0, 0.03, abs(d)));
    float3 n = normalize(float3(ddx(d), ddy(d), 0.6));
    float diff = max(dot(n, light), 0.2);
    float3 lit = col * diff + float3(0.1, 0.1, 0.15) * bevel;
    return float4(lit, 1.0 - step(0.0, d));
}
