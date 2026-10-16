// Orphic Obsidian Sanctum — single-pass OBS ShaderFilter port.
// Original raymarched Mandelbox and orbit-trap lighting:
// ORPHIC/js/scene-obsidian-sanctum.js by Aditya Rajashekaran.
// https://github.com/adityarajashekaran/orphic (commit 47a8d5d)
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This one-pass version omits original adaptive half-resolution raymarch,
// FFT spectral textures, and final image-space chromatic smoothing. Quality
// steps are deliberately bounded; keep low on streaming-resolution sources.
// File-backed ordinary .shader (standard wrapper, not .effect mode).

uniform float audio_peak;
uniform float audio_magnitude;
uniform float Audio_Gain<
    string label="Audio response"; string widget_type="slider";
    float minimum=0.0; float maximum=4.0; float step=0.1;
> = 1.5;
uniform int March_Steps<
    string label="Raymarch steps (performance)"; string widget_type="slider";
    int minimum=20; int maximum=72; int step=4;
> = 40;
uniform int Fractal_Iterations<
    string label="Fractal detail (performance)"; string widget_type="slider";
    int minimum=5; int maximum=11; int step=1;
> = 8;
uniform float Morph_Scale<
    string label="Mandelbox fold scale"; string widget_type="slider";
    float minimum=1.8; float maximum=3.1; float step=0.05;
> = 2.4;
uniform float Fold<
    string label="Box fold"; string widget_type="slider";
    float minimum=0.7; float maximum=1.5; float step=0.02;
> = 1.05;
uniform float Camera_Distance<
    string label="Camera distance"; string widget_type="slider";
    float minimum=7.0; float maximum=22.0; float step=0.5;
> = 12.5;
uniform float Orbit_Speed<
    string label="Camera orbit"; string widget_type="slider";
    float minimum=-0.4; float maximum=0.4; float step=0.01;
> = 0.06;
uniform float Hue<
    string label="Color phase"; string widget_type="slider";
    float minimum=0.0; float maximum=1.0; float step=0.01;
> = 0.17;
uniform float Emission<
    string label="Fractal emission"; string widget_type="slider";
    float minimum=0.0; float maximum=3.0; float step=0.05;
> = 0.85;
uniform float Mix_With_Source<
    string label="Mix with source (1 = pattern)"; string widget_type="slider";
    float minimum=0.0; float maximum=1.0; float step=0.01;
> = 1.0;

float3 orb_palette(float t,float3 a,float3 b,float3 c,float3 d) {
    return a+b*cos(6.2831853*(c*t+d));
}
float3 aces_orb(float3 x) {
    x=max(x,float3(0.0,0.0,0.0));
    return saturate((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14));
}
float mandelboxDE(float3 p,float scale,float fold,float minR2,
                  int iterations,out float4 trap) {
    float3 z=p;
    float dr=1.0;
    trap=float4(1e6,1e6,1e6,1e6);
    [loop]
    for(int i=0;i<11;++i) {
        if(i>=iterations)break;
        z=clamp(z,-fold,fold)*2.0-z;
        float r2=dot(z,z);
        trap=min(trap,float4(abs(z),r2));
        if(r2<minR2){
            float f=1.0/minR2;
            z*=f;dr*=f;
        } else if(r2<1.0){
            float f=1.0/max(r2,1e-6);
            z*=f;dr*=f;
        }
        z=z*scale+p;
        dr=dr*abs(scale)+1.0;
    }
    return length(z)/max(abs(dr),1e-6);
}
float3 mandelboxNormal(float3 p,float t,float scale,float fold,
                        float minR2,int iterations) {
    float h=0.0008*(t*0.5+0.2);
    float2 e=float2(h,-h);
    float4 trap;
    float3 v=e.xyy*mandelboxDE(p+e.xyy,scale,fold,minR2,iterations,trap)
            +e.yyx*mandelboxDE(p+e.yyx,scale,fold,minR2,iterations,trap)
            +e.yxy*mandelboxDE(p+e.yxy,scale,fold,minR2,iterations,trap)
            +e.xxx*mandelboxDE(p+e.xxx,scale,fold,minR2,iterations,trap);
    return normalize(v+float3(1e-9,0,0));
}
float4 mainImage(VertData v_in):TARGET {
    float2 uv=v_in.uv;
    float4 src=image.Sample(textureSampler,uv);
    float level=saturate(audio_magnitude*Audio_Gain);
    float hit=saturate(audio_peak*Audio_Gain);
    float2 pos=(uv-0.5)*float2(uv_size.x/max(uv_size.y,1.0),1.0);
    float time=elapsed_time;
    float radius=Camera_Distance-hit*0.8;
    float angle=time*Orbit_Speed;
    float3 ro=float3(cos(angle)*radius,
                     radius*(0.34+0.05*sin(time*0.12)),
                     sin(angle)*radius);
    float3 fwd=normalize(float3(0,-0.5,0)-ro);
    float3 right=normalize(cross(fwd,float3(0,1,0)));
    float3 up=cross(right,fwd);
    float fov=0.78+hit*0.04;
    float3 rd=normalize(fwd/fov+pos.x*right-pos.y*up);
    float3 bg=float3(0.010,0.012,0.028)*(1.2-pos.y*0.6);
    float3 col=bg;
    float morph=Morph_Scale+0.14*sin(time*0.12)+level*0.2;
    float fold=Fold+level*0.07;
    float minR2=0.28+0.08*sin(time*0.035);
    float bq=dot(ro,rd);
    float disc=bq*bq-dot(ro,ro)+64.0;
    if(disc>=0.0) {
        float sq=sqrt(disc);
        float tExit=-bq+sq;
        float t=max(-bq-sq,0.0);
        float3 p=ro;
        float4 trap=float4(0,0,0,0);
        bool hitFractal=false;
        float steps=0.0;
        [loop]
        for(int i=0;i<72;++i) {
            if(i>=March_Steps)break;
            p=ro+rd*t;
            float d=mandelboxDE(p,morph,fold,minR2,Fractal_Iterations,trap);
            steps=float(i);
            if(d<0.0008*(t*0.5+0.2)){hitFractal=true;break;}
            t+=d*0.85;
            if(t>tExit)break;
        }
        if(hitFractal) {
            float3 n=mandelboxNormal(p,t,morph,fold,minR2,Fractal_Iterations);
            float ao=pow(max(0.0,1.0-steps/max(float(March_Steps),1.0)),1.5);
            float3 l1=normalize(float3(0.7,0.9,-0.4));
            float3 l2=normalize(float3(-0.6,-0.25,0.8));
            float3 dif=max(dot(n,l1),0.0)*(1.1+hit*0.4)*float3(1,0.86,0.72)
                      +max(dot(n,l2),0.0)*0.4*float3(0.45,0.65,1);
            float fres=pow(1.0-max(dot(n,-rd),0.0),3.0);
            float hue=Hue+p.y*0.035+length(p.xz)*0.02+trap.x*0.08;
            float3 base=orb_palette(hue,float3(0.5,0.5,0.5),
                                   float3(0.5,0.5,0.5),
                                   float3(1,1,1),float3(0,0.33,0.67));
            float cavity=1.0-smoothstep(0.2,0.8,trap.w);
            float glow=Emission*(0.14+level*1.6+hit*0.6);
            float3 emis=orb_palette(hue+0.45,float3(0.55,0.55,0.55),
                                   float3(0.45,0.45,0.45),
                                   float3(1,1,1),float3(0,0.33,0.67))
                        *cavity*glow;
            col=base*(float3(0.07,0.07,0.07)+dif)*ao
                +base*fres*0.6+emis*ao;
            col=lerp(col,bg,smoothstep(9.0,28.0,t));
        }
    }
    col*=0.7+level*0.7;
    float2 d=uv-0.5;
    col*=1.0-saturate(dot(d,d)*0.7);
    col=aces_orb(col);
    float opacity=saturate(Mix_With_Source);
    return float4(lerp(src.rgb,col,opacity),lerp(src.a,1.0,opacity));
}
