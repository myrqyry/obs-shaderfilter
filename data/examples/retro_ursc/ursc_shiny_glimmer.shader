// URSC Shiny Glimmer screen-space color quantizer.
// Converted from SHINY/glimmer mechanism of shaders/ursc/spatial/common.gdshaderinc.
// https://github.com/Zorochase/ultimate-retro-shader-collection
// Source 8cd971d0a275ef126151a99adf49cae1a64614c4
// Copyright (c) 2024-2026 Zorochase. SPDX-License-Identifier: MIT.
// The original Shiny shader was adapted from Zacksly's PSX Pickup Shader.
// Full source license and attribution in RETRO-URSC-PORTS.md.
//
// A screen-space application of the original nearest brightness-level
// adjustment to rendered pixels. Godot's Shiny effect uses surface normals
// to generate specular and shadow light first; a postprocess cannot do that.
// This preserves hue ratios; it does not independently quantize R/G/B.

uniform int Brightness_Levels<
    string label="Brightness levels";
    string widget_type="slider";
    int minimum=4; int maximum=64; int step=1;
> = 16;
uniform float Highlight_Glimmer<
    string label="Highlight quantization";
    string widget_type="slider";
    float minimum=0.0; float maximum=2.0; float step=0.05;
> = 1.0;
uniform float Shadow_Glimmer<
    string label="Shadow quantization";
    string widget_type="slider";
    float minimum=0.0; float maximum=2.0; float step=0.05;
> = 0.35;
uniform float Highlight_Start<
    string label="Highlight threshold";
    string widget_type="slider";
    float minimum=0.0; float maximum=0.9; float step=0.02;
> = 0.60;
uniform float Cutoff_Feather<
    string label="Highlight softness";
    string widget_type="slider";
    float minimum=0.01; float maximum=0.35; float step=0.01;
> = 0.18;
uniform float Effect_Mix<
    string label="Effect strength";
    string widget_type="slider";
    float minimum=0.0; float maximum=1.0; float step=0.01;
> = 1.0;

float3 ursc_glimmer(float3 rgb,float levels) {
    rgb=saturate(rgb);
    float value=max(rgb.r,max(rgb.g,rgb.b));
    if(value<=0.00001)return rgb;
    float lower=floor(value*levels)/levels;
    float upper=ceil(value*levels)/levels;
    float nearest=abs(value-lower)<=abs(upper-value)?lower:upper;
    return saturate(rgb*(nearest/value));
}
float4 mainImage(VertData v_in) : TARGET {
    float4 src=image.Sample(textureSampler,v_in.uv);
    if(src.a<=0.0001 || Effect_Mix<=0.0)return src;
    float3 rgb=saturate(src.rgb);
    float value=max(rgb.r,max(rgb.g,rgb.b));
    float blend=smoothstep(Highlight_Start,
                         min(1.0,Highlight_Start+Cutoff_Feather),value);
    float intensity=lerp(Shadow_Glimmer,Highlight_Glimmer,blend);
    float3 quantized=ursc_glimmer(rgb,float(Brightness_Levels));
    float3 processed=lerp(rgb,quantized,saturate(intensity));
    return float4(lerp(src.rgb,processed,saturate(Effect_Mix)),src.a);
}
