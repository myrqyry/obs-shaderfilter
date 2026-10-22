// Shader Effects Engraving -> OBS ShaderFilter template-mode image filter.
// Source: https://github.com/shader-effects-inc/shaders
// Commit: 81fd4ece5d493ca6c424a2af41f0e2c361ec8258
// packages/core/src/shaders/Engraving/index.ts and std/effects/stylize.ts
// Copyright (c) 2026 Shader Effects Inc. SPDX-License-Identifier: MIT.
// Preserves the line/3-plate crosshatch/spiral tonal engraving math.
// Difference: the source's mxNoise domain warp is re-created with smooth
// value noise rather than the original generated GPU noise primitive.
// Use this as a FILTER on a video/image source, not as a standalone generator.

uniform int Style<
  string label="Style: 0 Lines, 1 Crosshatch, 2 Spiral";
  string widget_type="slider";
  int minimum=0; int maximum=2; int step=1;
> = 1;
uniform float Lines<
  string label="Lines per image height";
  string widget_type="slider";
  float minimum=20.0; float maximum=300.0; float step=5.0;
> = 90.0;
uniform float Angle<
  string label="Line angle (degrees)";
  string widget_type="slider";
  float minimum=0.0; float maximum=360.0; float step=1.0;
> = 8.0;
uniform float Relief<
  string label="Brightness-following relief";
  string widget_type="slider";
  float minimum=0.0; float maximum=2.0; float step=0.02;
> = 0.60;
uniform float Waviness<
  string label="Organic line wander";
  string widget_type="slider";
  float minimum=0.0; float maximum=1.0; float step=0.02;
> = 0.35;
uniform float Contrast<
  string label="Tonal contrast";
  string widget_type="slider";
  float minimum=0.25; float maximum=3.0; float step=0.05;
> = 1.15;
uniform float Center_X<
  string label="Spiral center X";
  string widget_type="slider";
  float minimum=0.0; float maximum=1.0; float step=0.01;
> = 0.50;
uniform float Center_Y<
  string label="Spiral center Y";
  string widget_type="slider";
  float minimum=0.0; float maximum=1.0; float step=0.01;
> = 0.50;
uniform float4 Ink_Color<
  string label="Ink color";
> = {0.102,0.078,0.063,1.0};
uniform float4 Paper_Color<
  string label="Paper color";
> = {0.957,0.933,0.886,1.0};
uniform float Effect_Mix<
  string label="Effect strength";
  string widget_type="slider";
  float minimum=0.0; float maximum=1.0; float step=0.01;
> = 1.0;

float hash_se(float2 p) {
  float3 k=frac(float3(p.x,p.y,p.x)*float3(0.1031,0.1030,0.0973));
  k+=dot(k,k.yzx+33.33);
  return frac((k.x+k.y)*k.z);
}
float smoothNoise_se(float2 p) {
  float2 i=floor(p),f=frac(p);
  f=f*f*(3.0-2.0*f);
  return lerp(lerp(hash_se(i),hash_se(i+float2(1,0)),f.x),
              lerp(hash_se(i+float2(0,1)),hash_se(i+1.0),f.x),f.y);
}
float hatch_se(float2 p,float deg,float frequency,float reliefPhase,float level,float aa) {
  float radians=deg*0.01745329252;
  float w=p.x*(-sin(radians))+p.y*cos(radians);
  float v=cos(w*frequency*6.2831853+reliefPhase);
  float threshold=lerp(-1.15,1.15,saturate(level));
  return smoothstep(threshold-aa,threshold+aa,v);
}
float spiral_se(float2 p,float2 c,float frequency,float reliefPhase,float level,float aa) {
  float2 delta=p-c;
  float theta=atan2(delta.y,delta.x);
  float v=cos((length(delta)*frequency-theta/6.2831853)*6.2831853+reliefPhase);
  float threshold=lerp(-1.15,1.15,saturate(level));
  return smoothstep(threshold-aa,threshold+aa,v);
}
float4 mainImage(VertData v_in):TARGET {
  float2 uv=v_in.uv;
  float4 source=image.Sample(textureSampler,uv);
  if(Effect_Mix<=0.0 || source.a<=0.0001)return source;
  // Normal ShaderFilter DrawAlphaDivide supplies straight-alpha RGB.
  float3 rgb=source.rgb;
  float level=saturate(0.5+(dot(rgb,float3(0.299,0.587,0.114))-0.5)*Contrast);
  float aspect=uv_size.x/max(uv_size.y,1.0);
  float2 p=float2(uv.x*aspect,uv.y);
  float2 noisePosition=p*3.1;
  p+=(float2(smoothNoise_se(noisePosition),
             smoothNoise_se(noisePosition+float2(7.31,3.77)))-0.5)*Waviness*0.06;
  float aa=clamp(Lines*6.2831853/max(uv_size.y,1.0),0.02,1.0);
  float reliefPhase=Relief*level*9.42;
  float cover;
  if(Style==2) {
    cover=spiral_se(p,float2(Center_X*aspect,Center_Y),
                     Lines,reliefPhase,level,aa);
  } else if(Style==1) {
    float a=hatch_se(p,Angle,Lines,reliefPhase,level,aa);
    float b=hatch_se(p,Angle+72.0,Lines*0.92,reliefPhase*0.7,
                     saturate(level/0.55),aa);
    float c=hatch_se(p,Angle-38.0,Lines*1.13,reliefPhase*0.5,
                     saturate(level/0.28),aa);
    cover=max(a,max(b,c));
  } else {
    cover=hatch_se(p,Angle,Lines,reliefPhase,level,aa);
  }
  float3 col=lerp(Paper_Color.rgb,Ink_Color.rgb,cover);
  float a=source.a*lerp(Paper_Color.a,Ink_Color.a,cover);
  // Straight-RGB in the standard source-filter pipeline; preserve coverage.
  return lerp(source,float4(col,a),saturate(Effect_Mix));
}
