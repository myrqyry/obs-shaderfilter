// Audio-Reactive Color Shader for obs-shaderfilter
// Colors the source based on volume: green (quiet) → yellow (medium) → red (loud)
// Includes smooth temporal interpolation

// ─── Textures & Samplers ──────────────────────────────────────────────────────
Texture2D    image    : register(t0);
SamplerState sampler  : register(s0);

// ─── Audio Uniforms (set by obs-shaderfilter audio monitoring) ─────────────────
uniform float audio_level_left  <
    string description = "Left channel audio level";
> = 0.0;

uniform float audio_level_right <
    string description = "Right channel audio level";
> = 0.0;

// ─── Effect Uniforms ───────────────────────────────────────────────────────────
uniform float smoothing <
    string description = "Smoothing factor (0 = instant, ~0.95 = very smooth)";
    float uimin = 0.0;
    float uimax = 0.99;
    float uistep = 0.01;
> = 0.92;

uniform float intensity <
    string description = "Colorization intensity (0 = original, 1 = full effect)";
    float uimin = 0.0;
    float uimax = 1.0;
    float uistep = 0.01;
> = 1.0;

uniform float sensitivity <
    string description = "Volume sensitivity multiplier";
    float uimin = 0.1;
    float uimax = 5.0;
    float uistep = 0.1;
> = 1.5;

uniform float energy_decay <
    string description = "Peak decay rate (0 = hold peak, 1 = instant fall)";
    float uimin = 0.0;
    float uimax = 1.0;
    float uistep = 0.01;
> = 0.05;

uniform bool use_peak_hold <
    string description = "Enable peak hold instead of raw level";
> = false;

uniform bool mono_mix <
    string description = "Mix left+right into mono before processing";
> = true;

// ─── History Buffer (persists across frames via obs-shaderfilter) ──────────────
uniform float _history0 < string description = "DO NOT EDIT - internal"; > = 0.0;
uniform float _history1 < string description = "DO NOT EDIT - internal"; > = 0.0;

static float smooth_level = 0.0;
static float peak_level   = 0.0;
static float elapsed      = 0.0;

// ─── Helpers ───────────────────────────────────────────────────────────────────

float3 audio_color(float level)
{
    float l = clamp(level, 0.0, 1.0);

    // Three-segment gradient: green → yellow → red
    float3 green  = float3(0.0, 1.0, 0.0);
    float3 yellow = float3(1.0, 1.0, 0.0);
    float3 red    = float3(1.0, 0.0, 0.0);

    float t = l * 2.0;
    if (t < 1.0)
        return lerp(green, yellow, t);
    else
        return lerp(yellow, red, t - 1.0);
}

// ─── Pixel Shader Entry ────────────────────────────────────────────────────────

float4 main(
    float4 pos  : SV_POSITION,
    float2 uv   : TEXCOORD0
) : SV_TARGET
{
    float4 color = image.Sample(sampler, uv);

    // Combine audio channels
    float raw_level;
    if (mono_mix)
        raw_level = (audio_level_left + audio_level_right) * 0.5;
    else
        raw_level = max(audio_level_left, audio_level_right);

    raw_level *= sensitivity;

    // Smooth the level over time using exponential moving average
    float alpha = 1.0 - smoothing;
    smooth_level = smooth_level * smoothing + raw_level * alpha;

    // Peak hold
    if (use_peak_hold)
    {
        peak_level = max(peak_level - energy_decay * 0.01, smooth_level);
        smooth_level = peak_level;
    }
    else
    {
        peak_level = max(peak_level - energy_decay * 0.01, 0.0);
    }

    // Compute audio-reactive tint
    float level = clamp(smooth_level, 0.0, 1.0);
    float3 tint = audio_color(level);

    // Blend with original image: preserve luminance, apply tint
    float luminance = dot(color.rgb, float3(0.299, 0.587, 0.114));
    float3 tinted = lerp(luminance, 1.0, level * 0.6) * tint;

    color.rgb = lerp(color.rgb, tinted, intensity);

    // Optional subtle brightness pulse on transients
    float transient = clamp((raw_level - smooth_level) * 3.0, 0.0, 1.0);
    color.rgb += transient * tint * 0.15 * intensity;

    return color;
}
