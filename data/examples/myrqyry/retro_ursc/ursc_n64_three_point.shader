// URSC N64 3-point filtering — OBS ShaderFilter standard wrapper.
// Adapted from shaders/ursc/spatial/utilities.gdshaderinc in
// https://github.com/Zorochase/ultimate-retro-shader-collection
// Commit 8cd971d0a275ef126151a99adf49cae1a64614c4
// Copyright (c) 2024-2026 Zorochase. SPDX-License-Identifier: MIT.
// This sampler originated in MenacingMecha's Godot N64 shaders, per URSC README.
// Original URSC license and attribution are in RETRO-URSC-PORTS.md.
//
// This is a screen-space adaptation for video, not the original mesh UV
// sampling: it cannot fix polygon texture warping, mipmaps or depth.
// The virtual texture grid samples the real image using point filtering;
// each triangle chooses 3 taps versus bilinear 4-tap blending.

uniform int Virtual_Width<
    string label="Virtual texture width";
    string widget_type="slider";
    int minimum=32; int maximum=640; int step=8;
> = 320;
uniform int Virtual_Height<
    string label="Virtual texture height";
    string widget_type="slider";
    int minimum=24; int maximum=480; int step=8;
> = 240;
uniform float Phase_X<
    string label="Grid offset X";
    string widget_type="slider";
    float minimum=-0.5; float maximum=0.5; float step=0.05;
> = 0.0;
uniform float Phase_Y<
    string label="Grid offset Y";
    string widget_type="slider";
    float minimum=-0.5; float maximum=0.5; float step=0.05;
> = 0.0;
uniform float Effect_Mix<
    string label="Three-point filtering mix";
    string widget_type="slider";
    float minimum=0.0; float maximum=1.0; float step=0.01;
> = 1.0;

sampler_state URSC_PointSampler {
    Filter = Point;
    AddressU = Clamp;
    AddressV = Clamp;
};

float4 ursc_nearest_cell(float2 cell,float2 size) {
    return image.Sample(URSC_PointSampler,saturate((cell+0.5)/size));
}
// Work in associated-alpha space during three-point filtering. This avoids
// invisible RGB from fully transparent taps contaminating visible edges.
float4 urscPremultiply(float4 c) {
    return float4(c.rgb*c.a,c.a);
}
float4 mainImage(VertData v_in) : TARGET {
    float2 uv=v_in.uv;
    float4 src=image.Sample(textureSampler,uv);
    if(Effect_Mix<=0.0)return src;
    float2 size=float2(max(float(Virtual_Width),2.0),
                       max(float(Virtual_Height),2.0));
    float2 pixel=uv*size-0.5+float2(Phase_X,Phase_Y);
    float2 cell=floor(pixel),f=frac(pixel);
    float4 right=urscPremultiply(ursc_nearest_cell(cell+float2(1.0,0.0),size));
    float4 down=urscPremultiply(ursc_nearest_cell(cell+float2(0.0,1.0),size));
    float4 filtered;
    if(f.x+f.y<1.0) {
        float4 low=urscPremultiply(ursc_nearest_cell(cell,size));
        filtered=low*(1.0-f.x-f.y)+right*f.x+down*f.y;
    } else {
        float4 diagonal=urscPremultiply(ursc_nearest_cell(cell+float2(1.0,1.0),size));
        filtered=diagonal*(f.x+f.y-1.0)+right*(1.0-f.y)+down*(1.0-f.x);
    }
    // Blend input and filtered colors in associated-alpha space as well.
    // Return straight-alpha color because the Shaderfilter wrapper expects it.
    float4 mixed=lerp(urscPremultiply(src),filtered,saturate(Effect_Mix));
    float3 rgb = mixed.a > 0.00001 ?
                 mixed.rgb/mixed.a : float3(0.0,0.0,0.0);
    return float4(saturate(rgb),saturate(mixed.a));
}
