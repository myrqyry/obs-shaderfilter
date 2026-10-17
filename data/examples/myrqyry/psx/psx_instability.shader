// PSX / Instability
// Entirely screen-space; does NOT vertex-snap meshes or affine-map UVs.
// Source-size-aware pixel snapping, occasional line jog, UV wobble and
// controllable R/B chroma split. No frame-history dependency.

uniform float Pixel_Cell<
    string label = "Screen pixel cell size";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 6.0; float step = 1.0;
> = 1.0;
uniform float Jitter_Pixels<
    string label = "Frame jitter (pixels)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 4.0; float step = 0.1;
> = 0.65;
uniform float Line_Jog<
    string label = "Horizontal line jog (pixels)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 4.0; float step = 0.1;
> = 0.45;
uniform float Band_Height<
    string label = "Jog band height (pixels)";
    string widget_type = "slider";
    float minimum = 2.0; float maximum = 64.0; float step = 1.0;
> = 14.0;
uniform float Wobble_Pixels<
    string label = "Smooth wobble (pixels)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 3.0; float step = 0.05;
> = 0.22;
uniform float Chroma_Pixels<
    string label = "Red / blue separation (pixels)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 3.0; float step = 0.05;
> = 0.32;
uniform float Motion_Rate<
    string label = "Jitter updates per second";
    string widget_type = "slider";
    float minimum = 1.0; float maximum = 60.0; float step = 1.0;
> = 30.0;
uniform float Mix<
    string label = "Effect strength";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 1.0;

float psx_inst_hash(float2 p) {
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float4 mainImage(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 original = image.Sample(textureSampler, uv);
    if (Mix <= 0.0) return original;

    float2 dims = max(uv_size, float2(1.0, 1.0));
    float2 pos = uv * dims;
    float frame = floor(elapsed_time * Motion_Rate);
    float band = floor(pos.y / max(Band_Height, 1.0));
    float jx = (psx_inst_hash(float2(frame, 17.0)) - 0.5) * 2.0 * Jitter_Pixels;
    float jy = (psx_inst_hash(float2(frame, 73.0)) - 0.5) * Jitter_Pixels * 0.5;
    float line = (psx_inst_hash(float2(band, frame)) - 0.5) * 2.0 * Line_Jog;
    float wave = sin(pos.y * 0.038 + elapsed_time * 4.1) * Wobble_Pixels;
    float2 moved = pos + float2(jx + line + wave, jy);
    float cell = max(Pixel_Cell, 1.0);
    moved = (floor(moved / cell) + 0.5) * cell;
    float2 shifted_uv = saturate(moved / dims);
    float4 shifted = image.Sample(textureSampler, shifted_uv);

    float2 chroma = float2(Chroma_Pixels / dims.x, 0.0);
    float red = image.Sample(textureSampler, saturate(shifted_uv + chroma)).r;
    float blue = image.Sample(textureSampler, saturate(shifted_uv - chroma)).b;
    float3 rgb = float3(red, shifted.g, blue);
    return lerp(original, float4(rgb, shifted.a), Mix);
}
