// Original: shaders/noise_static_chroma.hook (MPV CHROMA plane).
// RGB adaptation computes independent R/B chroma perturbations and
// adjusts G to preserve Rec.601 luma. Keeps source alpha untouched.
// Adapted from Chinna95P/mpv-anime-build MPV shader collection (MIT).
// Source: https://github.com/Chinna95P/mpv-anime-build/tree/main/shaders
// Licensed under MIT; see MPV-ANIME-LICENSE.txt.
// MPV hook sampling adapted to OBS Shaderfilter's image, textureSampler,
// uv_pixel_interval and uv_size. Alpha of source preserved.
float4 mpvSample(float2 uv) {
    float2 halfPixel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfPixel, 1.0 - halfPixel));
}

uniform float strength<
    string label = "Chroma Grain";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 256.0; float step = 1.0;
> = 48.0;
float mpvPermute(float x) {
    float p = (34.0*x+1.0)*x;
    return p - floor(p / 289.0)*289.0;
}
float4 mainImage(VertData v_in) : TARGET {
    float4 center = mpvSample(v_in.uv);
    float2 uv = v_in.uv;
    float h = mpvPermute(mpvPermute(mpvPermute(uv.x+1.0)+(uv.y+1.0))+1.5);
    float nr = frac(h/41.0)-0.5;
    h = mpvPermute(h);
    float nb = frac(h/41.0)-0.5;
    float scale = strength/8192.0;
    float dr = nr * scale;
    float db = nb * scale;
    float dg = -(0.299*dr+0.114*db)/0.587;
    return float4(center.rgb + float3(dr,dg,db), center.a);
}
