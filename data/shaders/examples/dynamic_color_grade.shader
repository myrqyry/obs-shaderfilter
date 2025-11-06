// dynamic_color_grade.shader - Professional color grading with presets
#define vec3 float3
#define vec4 float4

uniform float Exposure<
    string label = "Exposure";
    string widget_type = "slider";
    float minimum = -2.0;
    float maximum = 2.0;
    float step = 0.1;
> = 0.0;

uniform float Contrast<
    string label = "Contrast";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.0;

uniform float Saturation<
    string label = "Saturation";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 2.0;
    float step = 0.01;
> = 1.0;

uniform float Temperature<
    string label = "Temperature";
    string widget_type = "slider";
    float minimum = -1.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.0;

uniform int Color_Preset<
    string label = "Color Preset";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "None";
    int option_1_value = 1;
    string option_1_label = "Cinematic";
    int option_2_value = 2;
    string option_2_label = "Vibrant";
    int option_3_value = 3;
    string option_3_label = "Film Noir";
    int option_4_value = 4;
    string option_4_label = "Sunset";
> = 0;

// RGB to HSV conversion
float3 rgb2hsv(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV to RGB conversion
float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float4 mainImage(VertData v_in) : TARGET {
    float4 color = image.Sample(textureSampler, v_in.uv);

    // Apply exposure
    color.rgb *= pow(2.0, Exposure);

    // Apply contrast
    color.rgb = ((color.rgb - 0.5) * max(Contrast + 1.0, 0.0)) + 0.5;

    // Apply temperature adjustment
    if (Temperature > 0.0) {
        color.r *= 1.0 + Temperature * 0.3;
        color.b *= 1.0 - Temperature * 0.3;
    } else {
        color.r *= 1.0 + Temperature * 0.3;
        color.b *= 1.0 - Temperature * 0.3;
    }

    // Apply saturation in HSV space
    float3 hsv = rgb2hsv(color.rgb);
    hsv.y *= Saturation;
    color.rgb = hsv2rgb(hsv);

    // Apply color presets
    if (Color_Preset == 1) { // Cinematic
        color.rgb = lerp(color.rgb, color.rgb * float3(1.1, 0.95, 0.8), 0.3);
    } else if (Color_Preset == 2) { // Vibrant
        hsv = rgb2hsv(color.rgb);
        hsv.y *= 1.4;
        hsv.z *= 1.1;
        color.rgb = hsv2rgb(hsv);
    } else if (Color_Preset == 3) { // Film Noir
        float luma = dot(color.rgb, float3(0.299, 0.587, 0.114));
        color.rgb = lerp(color.rgb, float3(luma, luma, luma), 0.8);
        color.rgb *= 1.2; // Boost contrast
    } else if (Color_Preset == 4) { // Sunset
        color.rgb *= float3(1.3, 1.0, 0.7);
    }

    return float4(clamp(color.rgb, 0.0, 1.0), color.a);
}
