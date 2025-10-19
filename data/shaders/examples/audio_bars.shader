// Audio Bars - visualizes spectrum as vertical bars

uniform float4x4 ViewProj;
uniform texture2d image;
uniform float2 uv_offset;
uniform float2 uv_scale;
uniform float2 uv_size;
uniform float2 uv_pixel_interval;
uniform float elapsed_time;

uniform float audio_spectrum[256];
uniform int spectrum_bands = 64;

uniform float bar_width<
    string label = "Bar Width";
    string widget_type = "slider";
    float minimum = 0.001;
    float maximum = 0.1;
    float step = 0.001;
> = 0.02;

uniform float4 bar_color<
    string label = "Bar Color";
    string widget_type = "color";
> = {1.0, 0.5, 0.0, 1.0};

sampler_state textureSampler { Filter = Point; AddressU = Clamp; AddressV = Clamp; };

struct VertexIn { float4 pos : POSITION; float2 uv : TEXCOORD0; };
struct VertexOut { float4 pos : POSITION; float2 uv : TEXCOORD0; };

VertexOut VSDefault(VertexIn v_in) {
    VertexOut v_out;
    v_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
    v_out.uv = v_in.uv * uv_scale + uv_offset;
    return v_out;
}

float4 PSAudioBars(VertexOut v_in) : TARGET {
    float x = v_in.uv.x;
    int band = (int)(x * spectrum_bands);
    band = clamp(band, 0, spectrum_bands-1);
    float val = audio_spectrum[band];

    float center = (band + 0.5) / (float)spectrum_bands;
    float half_width = bar_width * 0.5;
    float alpha = smoothstep(center - half_width, center + half_width, x) - smoothstep(center + half_width, center + half_width*2.0, x);

    float height = val;
    if (v_in.uv.y < height) {
        return lerp(image.Sample(textureSampler, v_in.uv), bar_color, 0.9);
    }
    return image.Sample(textureSampler, v_in.uv);
}

technique Draw { pass { vertex_shader = VSDefault(v_in); pixel_shader = PSAudioBars(v_in); } }
