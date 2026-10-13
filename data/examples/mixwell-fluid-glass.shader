// =============================================================================
// MIXWELL FLUID GLASS — OBS Shaderfilter (template mode, not Entire Effect)
// =============================================================================
// @name        Mixwell Fluid Glass
// @category    Distortion
// @tags        reverse drift, liquid glass, pigment flow, fluid, refraction
// @description Two bounded fluid brush paths gently deform the source image
//              without repeatedly resampling its texture.
// =============================================================================
//
// Inspired by MixwellBrush.glsl by Doug L. James and Ethan James, MIT (2026):
// https://github.com/dougjam/mixwell-2026
// The influence matrix and midpoint reverse integration are adapted here.
// See data/examples/MIXWELL_FLUID_GLASS.md and LICENSE-MIXWELL-MIT.txt.
//
// This is a real-time fixed-step approximation, not the original adaptive
// integrator, and not a volumetric simulation. The source is sampled once.
// Use as a Shaderfilter USER shader (template mode), not as Entire Effect.

uniform string FluidGlass_Info<
    string label = "About";
    string widget_type = "info";
> = "Two localized reverse-drift fluid brushes. Start with a low Strength and slow Speed. Zero Strength is neutral. Static when Speed is zero.";

uniform float FluidGlass_Strength<
    string label = "Strength";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.58;

uniform float FluidGlass_Radius<
    string label = "Brush radius";
    string widget_type = "slider";
    float minimum = 0.012;
    float maximum = 0.160;
    float step = 0.002;
> = 0.058;

uniform float FluidGlass_Length<
    string label = "Stroke length";
    string widget_type = "slider";
    float minimum = 0.08;
    float maximum = 0.90;
    float step = 0.01;
> = 0.48;

uniform float FluidGlass_Speed<
    string label = "Drift speed";
    string widget_type = "slider";
    float minimum = -2.0;
    float maximum = 2.0;
    float step = 0.01;
> = 0.24;

uniform float FluidGlass_CenterX<
    string label = "Center X";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.50;

uniform float FluidGlass_CenterY<
    string label = "Center Y";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.50;

uniform float FluidGlass_Rotation<
    string label = "Direction (degrees)";
    string widget_type = "slider";
    float minimum = -180.0;
    float maximum = 180.0;
    float step = 1.0;
> = 20.0;

uniform int FluidGlass_Strokes<
    string label = "Brush strokes";
    string widget_type = "select";
    int option_0_value = 1;
    string option_0_label = "One (lighter GPU)";
    int option_1_value = 2;
    string option_1_label = "Two (more folded)";
> = 2;

uniform int FluidGlass_Quality<
    string label = "Quality";
    string widget_type = "select";
    int option_0_value = 8;
    string option_0_label = "Fast (8 midpoint steps)";
    int option_1_value = 16;
    string option_1_label = "Detailed (16 midpoint steps)";
> = 8;

static const float FLUID_GLASS_PI = 3.14159265358979323846;

// Mixwell's softened brush influence matrix:
// K(v, r) = A*I + B*(v*v^T), evaluated as a matrix-vector product.
// Explicit scalar multiplication avoids HLSL/GLSL transpose conventions.
float2 fluidGlassBrushVelocity(float2 v, float radius, float2 db)
{
    float r2 = dot(v, v);
    float e2 = radius * radius;
    float s = max(r2 + e2, 1.0e-12);
    float invSqrt = rsqrt(s);
    float invD = invSqrt * invSqrt * invSqrt;
    float invR = rsqrt(max(r2, 1.0e-12));
    float r = r2 * invR;

    float afd = 1.0 - r * (r2 + 2.0 * e2) * invD;
    float bfd = e2 * invR * invD;
    float xx = bfd * v.x * v.x;
    float xy = bfd * v.x * v.y;
    float yy = bfd * v.y * v.y;

    return float2((afd + xx) * db.x + xy * db.y,
                  xy * db.x + (afd + yy) * db.y);
}

float fluidGlassDistanceToSegment(float2 p, float2 a, float2 b)
{
    float2 ab = b - a;
    float h = saturate(dot(p - a, ab) / max(dot(ab, ab), 1.0e-10));
    return length(p - a - ab * h);
}

// Bounded midpoint steps per segment (8 or 16). Hard cap: two segments,
// 32 steps and 64 brush-matrix evaluations per pixel in influence regions.
float2 fluidGlassReverseBrush(float2 p0, float radius, float2 a, float2 b)
{
    float d = fluidGlassDistanceToSegment(p0, a, b);
    float range = 4.0 * radius;
    if (d >= range)
        return p0;

    float mask = 1.0 - smoothstep(2.0 * radius, range, d);
    float2 db = (a - b) / float(FluidGlass_Quality);
    float2 brush = b;
    float2 pos = p0;

    [loop]
    for (int i = 0; i < 16; i++)
    {
        if (i >= FluidGlass_Quality) break;
        float2 v = pos - brush;
        float2 first = fluidGlassBrushVelocity(v, radius, db);
        float2 mid = v + 0.5 * (first - db);
        pos += fluidGlassBrushVelocity(mid, radius, db);
        brush += db;
    }

    return p0 + (pos - p0) * mask;
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float strength = saturate(FluidGlass_Strength);

    if (strength <= 0.0)
        return image.Sample(textureSampler, uv);

    float aspect = max(uv_size.x / max(uv_size.y, 1.0), 0.01);
    float2 center = float2(FluidGlass_CenterX, FluidGlass_CenterY);
    float2 p = (uv - center) * float2(aspect, 1.0);

    float phase = elapsed_time * FluidGlass_Speed * 0.52;
    float angle = FluidGlass_Rotation * (FLUID_GLASS_PI / 180.0);
    float reach = FluidGlass_Length * 0.5;
    float radius = max(FluidGlass_Radius, 0.001);

    float2 pivotA = float2(0.14 * sin(phase * 0.53),
                           0.13 * cos(phase * 0.43));
    float headingA = angle + phase;
    float2 dirA = float2(cos(headingA), sin(headingA));

    float2 pivotB = float2(0.22 * cos(phase * 0.31 + 1.8),
                           0.17 * sin(phase * 0.37 + 0.7));
    float headingB = angle + 1.75 - phase * 0.71;
    float2 dirB = float2(cos(headingB), sin(headingB));

    // Reverse chronological composition. Both brushes affect only a bounded
    // neighborhood. No framebuffer feedback or iterative image resampling.
    float2 sourcePos = p;
    if (FluidGlass_Strokes >= 2)
    {
        float2 prevB = fluidGlassReverseBrush(sourcePos, radius,
                                              pivotB - dirB * reach,
                                              pivotB + dirB * reach);
        sourcePos = lerp(sourcePos, prevB, strength);
    }

    float2 prevA = fluidGlassReverseBrush(sourcePos, radius,
                                          pivotA - dirA * reach,
                                          pivotA + dirA * reach);
    sourcePos = lerp(sourcePos, prevA, strength);

    float2 sampleUv = (sourcePos / float2(aspect, 1.0)) + center;
    // The plugin's default sampler uses a transparent border; clamp to keep
    // a gently moving source from accidentally gaining transparent seams.
    sampleUv = saturate(sampleUv);
    return image.Sample(textureSampler, sampleUv);
}
