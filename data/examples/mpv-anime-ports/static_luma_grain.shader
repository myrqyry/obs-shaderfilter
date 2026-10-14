// Original: shaders/noise_static_luma.hook
// MPV LUMA plane's static spatial grain adapted as equal RGB luma noise.
// Adapted from Chinna95P/mpv-anime-build MPV shader collection (MIT).
// Source: https://github.com/Chinna95P/mpv-anime-build/tree/main/shaders
// Licensed under MIT; see MPV-ANIME-LICENSE.txt.
// MPV hook sampling adapted to OBS Shaderfilter's image, textureSampler,
// uv_pixel_interval and uv_size. Alpha of source preserved.
float4 mpvSample(float2 uv) {
    float2 halfPixel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfPixel, 1.0 - halfPixel));
}
float mpvLuma(float3 rgb) { return dot(rgb, float3(0.299, 0.587, 0.114)); }

uniform float strength<
    string label = "Luma Grain";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 256.0; float step = 1.0;
> = 48.0;
float mpvPermute(float x) {
    float p = (34.0*x+1.0)*x;
    return p - floor(p / 289.0)*289.0;
}
float mainNoise(float2 uv) {
    // Source uses normalized HOOKED_pos (not pixel coordinates).
    float h = mpvPermute(mpvPermute(mpvPermute(uv.x+1.0)+(uv.y+1.0))+2.0);
    return frac(h / 41.0) - 0.5;
}
float4 mainImage(VertData v_in) : TARGET {
    float4 center = mpvSample(v_in.uv);
    float n = mainNoise(v_in.uv) * (strength / 8192.0);
    return float4(center.rgb + float3(n,n,n), center.a);
}
