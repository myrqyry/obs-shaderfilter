// Shader Effects Watercolor -> OBS ShaderFilter standard template.
// Source: https://github.com/shader-effects-inc/shaders
// Commit: 81fd4ece5d493ca6c424a2af41f0e2c361ec8258
// Watercolor/index.ts, std/effects/stylize.ts, gpu/kit/stylizePaints.ts
// Copyright (c) 2026 Shader Effects Inc. SPDX-License-Identifier: MIT.
// Four overlapping Kuwahara quadrants, minimum color variance selection,
// time-wobbled bleed sample positions and pigment/paper-grain tint.
// Unlike the WebGPU RTT pipeline this reads the ShaderFilter source texture.
// Optimized for a small brush at default; R=8 can cost 100 texture fetches.
// Attach as a FILTER on video/images; standalone source has no image input.

uniform int Brush_Radius<
  string label="Brush radius (GPU cost)";
  string widget_type="slider";
  int minimum=1; int maximum=8; int step=1;
> = 3;
uniform float Bleed<
  string label="Pigment bleed";
  string widget_type="slider";
  float minimum=0.0; float maximum=3.0; float step=0.05;
> = 1.0;
uniform float Paper_Grain<
  string label="Paper texture amount";
  string widget_type="slider";
  float minimum=0.0; float maximum=1.0; float step=0.02;
> = 0.35;
uniform float4 Paper_Color<
  string label="Paper tint";
> = {0.984,0.969,0.925,1.0};
uniform float Effect_Mix<
  string label="Watercolor strength";
  string widget_type="slider";
  float minimum=0.0; float maximum=1.0; float step=0.01;
> = 1.0;

float se_wc_hash(float2 p) {
  float3 q=frac(float3(p.x,p.y,p.x)*float3(0.1031,0.1030,0.0973));
  q+=dot(q,q.yzx+33.33);
  return frac((q.x+q.y)*q.z);
}
float se_wc_value(float2 p) {
  float2 i=floor(p),f=frac(p);
  f=f*f*(3.0-2.0*f);
  return lerp(lerp(se_wc_hash(i),se_wc_hash(i+float2(1,0)),f.x),
              lerp(se_wc_hash(i+float2(0,1)),se_wc_hash(i+1.0),f.x),f.y);
}
float4 se_wc_sample(float2 uv) {
  return image.Sample(textureSampler,saturate(uv));
}
float4 mainImage(VertData v_in):TARGET {
  float2 uv=v_in.uv;
  float4 src=se_wc_sample(uv);
  if(Effect_Mix<=0.0 || src.a<=0.0001)return src;
  float2 dims=max(uv_size,float2(1.0,1.0));
  float2 warped=uv;
  if(Bleed>0.0) {
    float t=elapsed_time*0.03;
    float2 n=float2(se_wc_value(uv*5.0+float2(t,t)),
                     se_wc_value(uv*5.0+float2(31.4+t,31.4+t)));
    warped+=(n-0.5)*Bleed*8.0/dims;
  }
  float4 source=se_wc_sample(warped);
  int taps=max(2,min(5,(Brush_Radius+2)/2));
  float invN=1.0/float(taps*taps);
  float bestVar=1e9;
  float4 best=float4(0,0,0,0);
  // Source uses a stride of two logical pixels per tap and four overlapping
  // diagonal quadrants; each quadrant's lowest RGB variance wins.
  for(int quadrant=0;quadrant<4;quadrant++) {
    float dirX=(quadrant==0 || quadrant==2)?-1.0:1.0;
    float dirY=(quadrant==0 || quadrant==1)?-1.0:1.0;
    float4 sum=float4(0,0,0,0);
    float3 squared=float3(0,0,0);
    for(int y=0;y<5;y++) {
      if(y>=taps)break;
      for(int x=0;x<5;x++) {
        if(x>=taps)break;
        float2 offset=float2((2.0*float(x)+0.5)*dirX,
                              (2.0*float(y)+0.5)*dirY)/dims;
        float4 c=se_wc_sample(warped+offset);
        // Default ShaderFilter sampling is straight alpha; convert each tap
        // to premultiplied color before the source-inspired variance test.
        float3 pre=c.rgb*c.a;
        sum+=float4(pre,c.a);
        squared+=pre*pre;
      }
    }
    float4 mean=sum*invN;
    float3 variance=max(squared*invN-mean.rgb*mean.rgb,float3(0,0,0));
    float sigma=variance.r+variance.g+variance.b;
    if(sigma<bestVar) {
      bestVar=sigma;
      best=mean;
    }
  }
  // Source's compositing stage unpremultiplies the winning mean.
  float3 painted=best.rgb/max(best.a,0.0001);
  float grain=se_wc_value(uv*dims*0.5);
  float paper=saturate(Paper_Grain);
  painted*=lerp(1.0,grain,paper);
  painted=lerp(painted,painted*Paper_Color.rgb,paper*0.4);
  float3 color=lerp(source.rgb,painted,saturate(Effect_Mix));
  // Bleed affects pigment placement, not the input source transparency.
  return float4(saturate(color),src.a);
}
