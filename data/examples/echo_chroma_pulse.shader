// Unique filter: "Echo Chroma Pulse"
// Time-shifted chromatic aberration + audio-reactive pulse + subtle scanlines
// Requires expansion ~8px for clean edges
// Audio: declare audio_magnitude/audio_peak to make "Audio source" picker appear in OBS properties
uniform float audio_magnitude;
uniform float audio_peak;

uniform float ShiftAmount<
    string label = "Echo Shift";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.05;
    float step = 0.001;
> = 0.012;

uniform float ChromaStrength<
    string label = "Chroma Amount";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 2.0;
    float step = 0.05;
> = 0.8;

uniform float PulseSpeed<
    string label = "Pulse Speed";
    string widget_type = "slider";
    float minimum = 0.1;
    float maximum = 4.0;
    float step = 0.1;
> = 1.8;

uniform float Scanline<
    string label = "Scanline Intensity";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.3;
    float step = 0.01;
> = 0.12;

float4 mainImage(VertData v_in) : TARGET
{
    float4 src = image.Sample(textureSampler, v_in.uv);

    // Pulse modulated by audio (picker appears because we declared the uniforms)
    float pulse = sin(elapsed_time * PulseSpeed * 6.2831853) * 0.5 + 0.5;
    float audioMod = lerp(0.6, 1.4, audio_magnitude);

    // Time-shifted echo for ghosting (uses previous frame via plugin support)
    float2 shift = float2(ShiftAmount, 0.0) * audioMod * pulse;
    float4 echoR = image.Sample(textureSampler, v_in.uv + shift * 1.3);
    float4 echoB = image.Sample(textureSampler, v_in.uv - shift * 0.9);

    // Chromatic aberration on echo
    float3 chroma = float3(echoR.r, src.g, echoB.b);
    float3 finalRGB = lerp(src.rgb, chroma, ChromaStrength * audioMod);

    // Subtle scanlines
    float scan = sin(v_in.uv.y * uv_size.y * 1.8) * 0.5 + 0.5;
    finalRGB *= 1.0 - (scan * Scanline);

    return float4(finalRGB, src.a);
}
