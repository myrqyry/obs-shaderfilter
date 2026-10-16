// Orphic Escher Gate — OBS ShaderFilter port.
// Based on ORPHIC/js/scene-escher-gate.js (Aditya Rajashekaran, 2026).
// https://github.com/adityarajashekaran/orphic
// SPDX-License-Identifier: AGPL-3.0-or-later
// Original Poincare-disk triangle-group folding retained. ShaderFilter has
// no spectrum texture/beat detector; tiling selection is a manual control,
// lighting responds to audio peak and RMS only.

uniform float audio_peak;
uniform float audio_magnitude;
uniform int Tiling<
    string label = "Hyperbolic tiling";
    string widget_type = "select";
    int option_0_value = 0; string option_0_label = "{6,4}";
    int option_1_value = 1; string option_1_label = "{5,4}";
    int option_2_value = 2; string option_2_label = "{7,3}";
    int option_3_value = 3; string option_3_label = "{4,5}";
    int option_4_value = 4; string option_4_label = "{8,3}";
    int option_5_value = 5; string option_5_label = "{5,5}";
> = 0;
uniform float Zoom<
    string label = "Zoom";
    string widget_type = "slider";
    float minimum = 0.5; float maximum = 2.0; float step = 0.05;
> = 1.0;
uniform float Glide_Speed<
    string label = "Mobius glide speed";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.1;
uniform float Spin_Speed<
    string label = "Spin speed";
    string widget_type = "slider";
    float minimum = -0.5; float maximum = 0.5; float step = 0.01;
> = 0.02;
uniform float Line_Thickness<
    string label = "Line width";
    string widget_type = "slider";
    float minimum = 0.4; float maximum = 4.0; float step = 0.1;
> = 1.2;
uniform float Audio_Gain<
    string label = "Audio response";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 4.0; float step = 0.1;
> = 1.7;
uniform float Hue<
    string label = "Palette phase";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.32;
uniform float Glow<
    string label = "Lattice glow";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 3.0; float step = 0.05;
> = 1.1;
uniform float Mix_With_Source<
    string label = "Mix with source (1 = pattern)";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 0.9;
float2 complex_mul(float2 a,float2 b) {
    return float2(a.x*b.x-a.y*b.y,a.x*b.y+a.y*b.x);
}
float2 complex_div(float2 a,float2 b) {
    return complex_mul(a,float2(b.x,-b.y))/max(dot(b,b),0.00000001);
}
float3 pal_escher(float t,float3 a,float3 b,float3 c,float3 d) {
    return a+b*cos(6.28318*(c*t+d));
}
float3 aces_escher(float3 x) {
    x=max(x,float3(0,0,0));
    return saturate((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14));
}
float4 mainImage(VertData v_in) : TARGET {
    float2 uv=v_in.uv;
    float4 src=image.Sample(textureSampler,uv);
    float level=saturate(audio_magnitude*Audio_Gain);
    float hit=saturate(audio_peak*Audio_Gain);
    float2 z0=(uv-0.5)*float2(uv_size.x/max(uv_size.y,1.0),1.0)*2.15*Zoom;
    float rr=length(z0);
    float3 rim=pal_escher(Hue+0.5,float3(0.5,0.5,0.5),
        float3(0.5,0.5,0.5),float3(1,1,1),float3(0,0.33,0.67));
    float3 col=float3(0.006,0.006,0.016);
    if(rr>=0.985) {
        col+=rim*exp(-(rr-0.985)*14.0)*(0.20+hit*0.55);
    } else {
        float t=elapsed_time*Glide_Speed;
        float2 mob=0.42*float2(sin(t*0.83),sin(t*0.59+1.9));
        float2 z=z0*(1.0-hit*0.06);
        z=complex_div(z-mob,float2(1.0,0.0)-complex_mul(float2(mob.x,-mob.y),z));
        float a=elapsed_time*Spin_Speed;
        float cs=cos(a),sn=sin(a);
        z=float2(cs*z.x-sn*z.y,sn*z.x+cs*z.y);
        // Valid hyperbolic {p,q}: 1/p + 1/q < 1/2.
        float p=6.0,q=4.0;
        if(Tiling==1) {p=5.0;q=4.0;}
        else if(Tiling==2) {p=7.0;q=3.0;}
        else if(Tiling==3) {p=4.0;q=5.0;}
        else if(Tiling==4) {p=8.0;q=3.0;}
        else if(Tiling==5) {p=5.0;q=5.0;}
        float ap=3.14159265/p;
        float bp=3.14159265/q;
        float cq=cos(bp);
        float d2=(cq*cq)/max(cq*cq-sin(ap)*sin(ap),0.0000001);
        float cd=sqrt(d2),cr2=d2-1.0;
        float2 normal=float2(-sin(ap),cos(ap));
        float2 center=float2(cd,0.0);
        float tier=0.0;
        [loop]
        for(int i=0;i<24;++i) {
            z.y=abs(z.y);
            z-=2.0*normal*max(0.0,dot(z,normal));
            float2 dz=z-center;
            float d=dot(dz,dz);
            if(d<cr2) {
                z=center+dz*(cr2/max(d,0.00000001));
                tier+=1.0;
            }
        }
        float e1=abs(z.y);
        float e2=abs(dot(z,normal));
        float e3=abs(length(z-center)-sqrt(cr2));
        float edge=min(e1,min(e2,e3));
        float deriv=abs(ddx(edge))+abs(ddy(edge))+0.00001;
        float line=exp(-edge/(deriv*Line_Thickness));
        float hue=Hue+tier*0.075;
        float3 linecol=pal_escher(hue,float3(0.5,0.5,0.5),
            float3(0.5,0.5,0.5),float3(1,1,1),float3(0,0.33,0.67));
        col=linecol*line*(0.25+level*1.4+hit*0.8)*Glow;
        col+=pal_escher(hue+0.35,float3(0.45,0.45,0.45),
            float3(0.4,0.4,0.4),float3(1,1,1),float3(0,0.33,0.67))
            *level*level*0.1;
        float vert=exp(-(e1+e2+e3)*26.0);
        col+=float3(1.0,0.95,0.9)*vert*hit*0.8;
        col*=1.0-smoothstep(0.86,0.985,rr)*0.75;
        col+=rim*exp(-abs(rr-0.985)*18.0)*(0.15+hit*0.4);
        col*=0.65+level*0.65;
    }
    col=aces_escher(col);
    float mixAmount=saturate(Mix_With_Source);
    return float4(lerp(src.rgb,col,mixAmount),lerp(src.a,1.0,mixAmount));
}
