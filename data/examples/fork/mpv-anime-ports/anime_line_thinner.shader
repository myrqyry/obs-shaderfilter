// Original: shaders/Anime-Line-Thinner.glsl (Chinna95P, MIT).
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

uniform float blend_factor<
    string label = "Line Thinning Strength";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.2;
uniform float threshold<
    string label = "Brightness Difference Threshold";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 0.3; float step = 0.005;
> = 0.08;
float4 mainImage(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float2 px = uv_pixel_interval;
    float4 center = mpvSample(uv);
    float4 n = mpvSample(uv + float2(0, px.y));
    float4 s = mpvSample(uv - float2(0, px.y));
    float4 e = mpvSample(uv + float2(px.x, 0));
    float4 w = mpvSample(uv - float2(px.x, 0));
    float centerY = mpvLuma(center.rgb);
    float brightestY = centerY;
    float4 brightest = center;
    float y = mpvLuma(n.rgb);
    if (y > brightestY) { brightest = n; brightestY = y; }
    y = mpvLuma(s.rgb);
    if (y > brightestY) { brightest = s; brightestY = y; }
    y = mpvLuma(e.rgb);
    if (y > brightestY) { brightest = e; brightestY = y; }
    y = mpvLuma(w.rgb);
    if (y > brightestY) { brightest = w; brightestY = y; }
    if (brightestY > centerY + threshold) {
        center.rgb = lerp(center.rgb, brightest.rgb, blend_factor);
    }
    return center;
}
