// Original: shaders/CAS-modern-1080.glsl (Chinna95P, MIT).
// Original operates on mpv LUMA; this OBS port applies its luma delta
// back to RGB, leaving chroma and alpha unchanged, not naive RGB CAS.
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

uniform float cas_strength<
    string label = "CAS Peak";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.6;
uniform float amount<
    string label = "Sharpen Mix";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 1.0;
float4 mainImage(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float2 d = uv_pixel_interval;
    float4 center = mpvSample(uv);
    // Zero sharpen mix is a passthrough; no need for eight extra samples.
    if (amount <= 0.0) return center;
    float a = mpvLuma(mpvSample(uv + float2(-d.x,-d.y)).rgb);
    float b = mpvLuma(mpvSample(uv + float2(0,-d.y)).rgb);
    float c = mpvLuma(mpvSample(uv + float2(d.x,-d.y)).rgb);
    float l = mpvLuma(mpvSample(uv + float2(-d.x,0)).rgb);
    float e = mpvLuma(center.rgb);
    float r = mpvLuma(mpvSample(uv + float2(d.x,0)).rgb);
    float g = mpvLuma(mpvSample(uv + float2(-d.x,d.y)).rgb);
    float h = mpvLuma(mpvSample(uv + float2(0,d.y)).rgb);
    float i = mpvLuma(mpvSample(uv + float2(d.x,d.y)).rgb);
    float lo = min(min(min(l,e),min(r,b)),h);
    float hi = max(max(max(l,e),max(r,b)),h);
    float mn = lo + min(lo,min(min(a,c),min(g,i)));
    float mx = hi + max(hi,max(max(a,c),max(g,i)));
    float amp = clamp(min(mn, 2.0 - mx) / max(mx, 0.00001), 0.0, 1.0);
    float w = amp * (-1.0 / lerp(8.0,5.0,cas_strength));
    float sharpened = ((b+l+r+h)*w+e) / max(1.0+4.0*w,0.00001);
    return float4(center.rgb + (sharpened - e)*amount, center.a);
}
