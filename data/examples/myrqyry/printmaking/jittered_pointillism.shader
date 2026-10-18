// Jittered Pointillism — local-color dots on paper, with size set by tone.
// Adapted from the Stipple technique in Noisemaker by Noise Factor LLC.
// MIT notice: printmaking/NOISEMAKER-LICENSE.txt
// Uses the source image sampled at each dot's own center (one color/dot).
#include "../../../stdlib/printmaking.glsl"

uniform float cell_size<
    string label = "Dot spacing (pixels)";
    string widget_type = "slider";
    float minimum = 3.0;
    float maximum = 48.0;
    float step = 1.0;
> = 10.0;

uniform float jitter_amount<
    string label = "Dot jitter";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.95;
    float step = 0.01;
> = 0.65;

uniform float dot_scale<
    string label = "Dot size";
    string widget_type = "slider";
    float minimum = 0.25;
    float maximum = 1.3;
    float step = 0.01;
> = 0.95;

uniform float seed<
    string label = "Pattern seed";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 100.0;
    float step = 1.0;
> = 1.0;

uniform float4 paper_color<
    string label = "Paper color";
> = {0.97, 0.95, 0.89, 1.0};

uniform float opacity<
    string label = "Effect opacity";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;

float4 mainImage(VertData v_in) : TARGET {
    float4 source = image.Sample(textureSampler, v_in.uv);
    if (opacity <= 0.0 || source.a <= 0.0) return source;

    float size = max(cell_size, 1.0);
    float2 dimensions = max(uv_size, float2(1.0, 1.0));
    float2 pixel = v_in.uv * dimensions;
    float2 gridPosition = pixel / size;
    float4 cell = printNearestCell(gridPosition, jitter_amount, seed);

    // Sampling the local center makes a dot solid-colored rather than
    // smearing the image's underlying edge through every printed dot.
    // Nearest cells can have centers outside the frame at the edges.
    // Reuse the nearest edge texel, matching a clamp-to-edge sampler.
    float2 halfTexel = uv_pixel_interval * 0.5;
    float2 centerUV = clamp(cell.xy * size / dimensions,
                            halfTexel, 1.0 - halfTexel);
    float3 dotColor = image.Sample(textureSampler, centerUV).rgb;
    float darkness = 1.0 -
        saturate(dot(dotColor, float3(0.2126, 0.7152, 0.0722)));
    // Noisemaker-inspired dot radius: highlights ~0.34, shadows ~0.74 cells.
    float radius = (0.34 + 0.40 * darkness) * max(dot_scale, 0.01);
    float distanceToDot = length(gridPosition - cell.xy);

    // A 0.75-output-pixel antialiasing half-width in cell units;
    // avoids requiring GLSL fwidth().
    float feather = max(0.75 / size, 0.001);
    float mask = 1.0 -
        smoothstep(radius - feather, radius + feather, distanceToDot);
    float3 painted = lerp(paper_color.rgb, dotColor, mask);
    // Preserve original alpha; never add opaque paper outside the source.
    return float4(lerp(source.rgb, painted, opacity), source.a);
}
