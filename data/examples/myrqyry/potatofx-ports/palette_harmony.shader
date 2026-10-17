// OBS-native perceptual palette harmonies. Adapted from potatoFX
// pPalettePosterize.fx by Gimle Larpes, MIT:
// https://github.com/GimleLarpes/potatoFX/tree/main/Shaders
// Notice: POTATOFX-LICENSE.txt. This adaptation is SDR sRGB ONLY,
// not equivalent to upstream's HDR10/HLG/scRGB ReShade path.
// Single-pass; source alpha is preserved, including transparent sources.
#include "../../../stdlib/oklab.glsl"

uniform int palette_type<
    string label = "Palette harmony";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "Monochrome";
    int option_1_value = 1;
    string option_1_label = "Analogous";
    int option_2_value = 2;
    string option_2_label = "Complementary";
    int option_3_value = 3;
    string option_3_label = "Triadic";
    int option_4_value = 4;
    string option_4_label = "Full spectrum";
> = 2;

uniform float3 base_color<
    string label = "Palette base color (sRGB)";
> = {0.52, 0.05, 0.05};

uniform int num_colors<
    string label = "Tonal levels";
    string widget_type = "slider";
    int minimum = 2;
    int maximum = 16;
    int step = 1;
> = 4;

uniform float palette_balance<
    string label = "Harmony balance";
    string widget_type = "slider";
    float minimum = 0.001;
    float maximum = 1.0;
    float step = 0.001;
> = 0.5;

uniform float dither_strength<
    string label = "Bayer dithering";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.1;
    float step = 0.001;
> = 0.02;

uniform bool desaturate_highlights<
    string label = "Soften highlight saturation";
> = false;

uniform float desaturate_amount<
    string label = "Highlight desaturation";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.75;

uniform float effect_mix<
    string label = "Effect mix";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;

float pfBayer2x2(float2 pixel) {
    int x = int(floor(pixel.x)) % 2;
    int y = int(floor(pixel.y)) % 2;
    // 2x2 Bayer matrix 0,2 / 3,1 from pPalettePosterize.
    if (y == 0) return x == 0 ? 0.0 : 2.0;
    return x == 0 ? 3.0 : 1.0;
}

float4 mainImage(VertData v_in) : TARGET {
    float4 source = image.Sample(textureSampler, v_in.uv);
    if (effect_mix <= 0.0 || source.a <= 0.0) return source;

    // INPUT CONTRACT: assumes the incoming RGB values are display-sRGB SDR.
    // The ReShade original switches transforms based on BUFFER_COLOR_SPACE;
    // Shaderfilter does not provide that metadata to this standalone shader.
    float3 lab = pfLinearToOklab(pfSrgbToLinear(source.rgb));
    float3 baseLch = pfOklabToLch(pfLinearToOklab(pfSrgbToLinear(base_color.rgb)));

    int levels = clamp(num_colors, 2, 16);
    // Original SDR compensation: 2.2 - SDR paper white (80/100) = 1.4.
    float control = 1.4 * max(palette_balance, 0.001);
    float dither = (pfBayer2x2(v_in.uv * uv_size) * 0.25 - 0.5) *
                   max(dither_strength, 0.0);
    float lightness = saturate(lab.x + dither);
    // Exactly `levels` lightness values including 0 and 1.
    float bins = float(levels - 1);
    float quantizedL = floor(lightness * bins + 0.5) / bins;

    float hueRange = 0.0;
    float hueOffset = 0.0;
    if (palette_type == 1) {
        hueRange = 1.5707963267948966;
    } else if (palette_type == 2) {
        hueRange = 1.5707963267948966;
        hueOffset = (lightness > 0.5 * control) ? 2.356194490192345 : 0.0;
    } else if (palette_type == 3) {
        hueRange = 1.5707963267948966;
        // Three bounded hue families, evenly spaced around Oklch.
        // Very small balance values must not repeat an unbounded index.
        float triadProgress = saturate(lightness / control);
        int triadIndex = min(2, int(floor(triadProgress * 3.0)));
        hueOffset = float(triadIndex) * 2.0943951023931953;
    } else if (palette_type >= 4) {
        hueRange = 6.283185307179586;
    }
    float chroma = baseLch.y;
    if (desaturate_highlights) {
        chroma *= max(0.0, 1.0 - lightness*lightness*saturate(desaturate_amount));
    }
    float hue = baseLch.z +
        (quantizedL - 1.0 / float(levels)) * hueRange + hueOffset;
    float3 graded = pfLinearToSrgb(pfOklabToLinear(
        pfLchToOklab(float3(quantizedL, chroma, hue))));
    return float4(lerp(source.rgb, saturate(graded), saturate(effect_mix)), source.a);
}
