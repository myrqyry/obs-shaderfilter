// Ink Hatching — tonal, color-preserving procedural strokes.
// Adapted from the Hatch technique in Noisemaker by Noise Factor LLC.
// MIT notice: printmaking/NOISEMAKER-LICENSE.txt
// Requires Shaderfilter's built-in image/textureSampler; use as an OBS filter.
#include "../../../stdlib/printmaking.glsl"

uniform float ink_strength<
    string label = "Ink strength";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.7;

uniform float stroke_length<
    string label = "Stroke length (pixels)";
    string widget_type = "slider";
    float minimum = 4.0;
    float maximum = 60.0;
    float step = 1.0;
> = 26.0;

uniform float stroke_angle<
    string label = "Stroke angle (degrees)";
    string widget_type = "slider";
    float minimum = -180.0;
    float maximum = 180.0;
    float step = 1.0;
> = 45.0;

uniform float tone_balance<
    string label = "Tone balance";
    string widget_type = "slider";
    float minimum = -0.5;
    float maximum = 0.5;
    float step = 0.01;
> = 0.0;

uniform float stroke_seed<
    string label = "Stroke seed";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 1.0;
> = 3.0;

float4 mainImage(VertData v_in) : TARGET {
    float4 source = image.Sample(textureSampler, v_in.uv);
    if (ink_strength <= 0.0 || source.a <= 0.0) return source;

    float2 pixel = v_in.uv * max(uv_size, float2(1.0, 1.0));
    float tone = saturate(dot(source.rgb, float3(0.2126, 0.7152, 0.0722))
                          + tone_balance);
    float angle = radians(stroke_angle);
    float crossAngle = radians(45.0);

    float primary = printHatchField(pixel, angle, stroke_length, stroke_seed);
    float crossing = printHatchField(pixel, angle + crossAngle,
                                    stroke_length, stroke_seed + 11.0);
    float deep = printHatchField(pixel, angle - crossAngle,
                                stroke_length, stroke_seed + 29.0);

    // Tone bands are artistic coverage ramps: the first inks midtones and
    // shadows; the next two gradually accumulate only in deeper shadows.
    float firstBand = 1.0 - smoothstep(0.62, 0.86, tone);
    float secondBand = 1.0 - smoothstep(0.34, 0.57, tone);
    float thirdBand = 1.0 - smoothstep(0.08, 0.28, tone);
    float firstInk = 1.0 - ink_strength * firstBand * (1.0 - primary);
    float secondInk = 1.0 - ink_strength * secondBand * (1.0 - crossing);
    float thirdInk = 1.0 - ink_strength * thirdBand * (1.0 - deep);
    return float4(saturate(source.rgb * firstInk * secondInk * thirdInk),
                  source.a);
}
