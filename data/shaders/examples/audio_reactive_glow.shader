// audio_reactive_glow.shader - Enhanced glow that responds to audio
#define vec2 float2
#define vec3 float3
#define vec4 float4

uniform float Glow_Intensity<
    string label = "Glow Intensity";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 5.0;
    float step = 0.1;
> = 1.5;

uniform float Audio_Sensitivity<
    string label = "Audio Sensitivity";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 2.0;
    float step = 0.1;
> = 1.0;

uniform float4 Glow_Color<
    string label = "Glow Color";
> = {1.0, 0.5, 0.2, 1.0};

uniform bool Enable_Audio_Reactive<
    string label = "Enable Audio Reactive";
> = true;

// Audio spectrum data (populated by plugin)
uniform texture2d audio_spectrum;

float4 mainImage(VertData v_in) : TARGET {
    float4 original = image.Sample(textureSampler, v_in.uv);

    // Sample audio spectrum for reactivity
    float audio_level = 0.0;
    if (Enable_Audio_Reactive) {
        // Sample low frequency range for bass response
        float2 audio_uv = float2(0.1, 0.5); // Low frequency range
        float4 spectrum_sample = audio_spectrum.Sample(textureSampler, audio_uv);
        audio_level = spectrum_sample.r * Audio_Sensitivity;
    }

    // Create glow effect based on luminance
    float luminance = dot(original.rgb, float3(0.299, 0.587, 0.114));

    // Increase glow with audio
    float glow_strength = Glow_Intensity + (audio_level * 2.0);

    // Generate glow by sampling surrounding pixels
    float4 glow = float4(0, 0, 0, 0);
    float glow_samples = 0.0;

    for (int x = -3; x <= 3; x++) {
        for (int y = -3; y <= 3; y++) {
            if (x == 0 && y == 0) continue;

            float2 offset = float2(x, y) * uv_pixel_interval * glow_strength;
            float4 sample_color = image.Sample(textureSampler, v_in.uv + offset);
            float sample_luminance = dot(sample_color.rgb, float3(0.299, 0.587, 0.114));

            glow += sample_color * sample_luminance;
            glow_samples += 1.0;
        }
    }

    glow /= glow_samples;
    glow *= Glow_Color * luminance;

    // Combine original with glow
    return float4(original.rgb + glow.rgb, original.a);
}
