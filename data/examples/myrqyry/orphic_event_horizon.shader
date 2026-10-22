// Orphic Event Horizon — OBS ShaderFilter standard-wrapper port.
// Based on ORPHIC/js/scene-event-horizon.js by Aditya Rajashekaran.
// https://github.com/adityarajashekaran/orphic (source revision 47a8d5d)
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// True fragment-space geodesic integration (not a UV lens-distortion fake):
// the ray direction bends via -1.5*h^2*x/r^5, intercepts an emissive disk,
// falls into the r=1 horizon, or escapes into a procedurally generated sky.
// Changes from ORPHIC: no FFT spectrogram or chroma/key, no CPU beat-driven
// shock queues, no half-res adaptive buffer or four-tap post-processing.
// Peak and RMS drive disk luminosity/lensing; orbit follows elapsed_time.
// EXPENSIVE: 64 marching steps by default. Start at small OBS source sizes.

uniform float audio_peak;
uniform float audio_magnitude;
uniform int Ray_Steps<
    string label="Geodesic steps (GPU cost)";
    string widget_type="slider";
    int minimum=24; int maximum=160; int step=8;
> = 64;
uniform float Mass<
    string label="Lensing mass";
    string widget_type="slider";
    float minimum=0.55; float maximum=2.0; float step=0.05;
> = 1.0;
uniform float Disk_Brightness<
    string label="Accretion brightness";
    string widget_type="slider";
    float minimum=0.0; float maximum=4.0; float step=0.1;
> = 1.3;
uniform float Photon_Halo<
    string label="Photon-sphere halo";
    string widget_type="slider";
    float minimum=0.0; float maximum=2.5; float step=0.05;
> = 0.75;
uniform float Camera_Distance<
    string label="Camera distance";
    string widget_type="slider";
    float minimum=10.0; float maximum=23.0; float step=0.5;
> = 15.5;
uniform float Inclination<
    string label="Disk view elevation";
    string widget_type="slider";
    float minimum=0.2; float maximum=7.0; float step=0.1;
> = 1.7;
uniform float Orbit_Speed<
    string label="Camera orbit";
    string widget_type="slider";
    float minimum=-0.25; float maximum=0.25; float step=0.01;
> = 0.025;
uniform float Disk_Spin<
    string label="Disk swirl speed";
    string widget_type="slider";
    float minimum=-3.0; float maximum=3.0; float step=0.1;
> = 0.45;
uniform float Hue<
    string label="Disk outer hue";
    string widget_type="slider";
    float minimum=0.0; float maximum=1.0; float step=0.01;
> = 0.12;
uniform float Audio_Gain<
    string label="Audio response";
    string widget_type="slider";
    float minimum=0.0; float maximum=4.0; float step=0.1;
> = 1.7;
uniform float Mix_With_Source<
    string label="Mix with source (1 = black hole)";
    string widget_type="slider";
    float minimum=0.0; float maximum=1.0; float step=0.01;
> = 1.0;

float hash_eh(float2 p) {
    float3 z=frac(float3(p.x,p.y,p.x)*float3(0.1031,0.1030,0.0973));
    z+=dot(z,z.yzx+33.33);
    return frac((z.x+z.y)*z.z);
}
float vnoise_eh(float2 p) {
    float2 i=floor(p),f=frac(p);
    f=f*f*(3.0-2.0*f);
    return lerp(lerp(hash_eh(i),hash_eh(i+float2(1.0,0.0)),f.x),
                lerp(hash_eh(i+float2(0.0,1.0)),hash_eh(i+1.0),f.x),f.y);
}
float fbm_eh(float2 p) {
    float v=0.0,a=0.5;
    for(int i=0;i<4;++i) {
        v+=a*vnoise_eh(p);
        p=p*2.03+13.7;
        a*=0.5;
    }
    return v;
}
float3 palette_eh(float t,float3 a,float3 b,float3 c,float3 d) {
    return a+b*cos(6.2831853*(c*t+d));
}
float3 aces_eh(float3 x) {
    x=max(x,float3(0.0,0.0,0.0));
    return saturate((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14));
}
float3 sky_eh(float3 d,float time,float level) {
    float az=atan2(d.z,d.x)/6.2831853+0.5;
    float el=asin(clamp(d.y,-1.0,1.0))/3.14159265+0.5;
    float2 grid=float2(az*64.0,el*32.0);
    float2 id=floor(grid);
    float star=pow(hash_eh(id+3.1),92.0);
    float tw=0.65+0.35*sin(time*(1.4+hash_eh(id+9.2)*2.8)+hash_eh(id+7.0)*32.0);
    float dist=length(frac(grid)-0.5);
    float glow=exp(-dist*dist*28.0);
    float3 color=float3(0.010,0.013,0.030)+float3(0.80,0.88,1.0)*star*tw*glow;
    float cloud=fbm_eh(float2(az*7.0,el*4.0)+time*0.012);
    color+=palette_eh(Hue+el*0.35,float3(0.22,0.22,0.22),
        float3(0.20,0.20,0.20),float3(1,1,1),float3(0,0.33,0.67))
        *cloud*cloud*(0.08+level*0.18);
    return color;
}
float3 disk_eh(float3 p,float3 rd,float time,float level) {
    const float inner=3.2,outer=13.0;
    float r=length(p.xz);
    if(r<inner || r>outer)return float3(0,0,0);
    float theta=atan2(p.z,p.x);
    float u=(r-inner)/(outer-inner);
    float phase=time*Disk_Spin;
    float swirl=fbm_eh(float2(r*1.3-phase*1.4,theta*2.2+r*0.7-phase));
    float den=(0.45+0.9*swirl)*smoothstep(0.0,0.12,u)
              *(1.0-smoothstep(0.70,1.0,u));
    float temp=pow(saturate(1.0-u),1.4);
    float3 ember=palette_eh(Hue,float3(0.55,0.32,0.26),
            float3(0.45,0.30,0.22),float3(1,1,1),float3(0,0.20,0.45));
    float3 col=lerp(ember,float3(1.0,0.76,0.42),smoothstep(0.0,0.5,temp));
    col=lerp(col,float3(0.82,0.90,1.08),smoothstep(0.5,1.0,temp));
    float3 tang=normalize(float3(-p.z,0.0,p.x));
    float beam=dot(tang,-normalize(rd))/sqrt(max(r,inner));
    col*=max(0.1,1.0+beam*(1.0+level*0.8));
    col+=float3(0.25,0.45,1.0)*max(beam,0.0)*0.45;
    col=lerp(col,col*float3(1.15,0.60,0.35),max(-beam,0.0)*0.5);
    return max(col,float3(0,0,0))*den*Disk_Brightness;
}
float4 mainImage(VertData v_in):TARGET {
    float2 uv=v_in.uv;
    float4 src=image.Sample(textureSampler,uv);
    float level=saturate(audio_magnitude*Audio_Gain);
    float hit=saturate(audio_peak*Audio_Gain);
    float t=elapsed_time;
    float2 p=(uv-0.5)*float2(uv_size.x/max(uv_size.y,1.0),1.0);
    float angle=t*Orbit_Speed;
    float radius=Camera_Distance-hit*1.0;
    float3 ro=float3(cos(angle)*radius,Inclination+0.65*sin(t*0.15),
                     sin(angle)*radius);
    float3 fwd=normalize(-ro);
    float3 right=normalize(cross(fwd,float3(0,1,0)));
    float3 up=cross(right,fwd);
    float3 rd=normalize(fwd/(1.15+0.04*hit)+p.x*right-p.y*up);
    float3 pos=ro,dir=rd;
    float3 cr=cross(pos,dir);
    float h2=dot(cr,cr)*(Mass+hit*0.20);
    float3 disk_acc=float3(0,0,0);
    float near_r=1e4;
    bool escaped=false;
    [loop]
    for(int i=0;i<160;++i) {
        if(i>=Ray_Steps)break;
        float r2=dot(pos,pos);
        float r=sqrt(r2);
        near_r=min(near_r,r);
        if(r<1.0)break;
        if(r>46.0){escaped=true;break;}
        float dl=clamp(0.16*(r-1.0),0.022,1.7);
        float3 before=pos;
        float3 acc=-1.5*h2*pos/max(r2*r2*r,1e-8);
        dir+=acc*dl;
        pos+=dir*dl;
        if(before.y*pos.y<0.0) {
            float cross_t=before.y/(before.y-pos.y);
            disk_acc+=disk_eh(lerp(before,pos,cross_t),dir,t,level);
        }
    }
    float3 col=disk_acc*(0.62+0.50*level);
    if(escaped)col+=sky_eh(normalize(dir),t,level);
    float halo=1.0-smoothstep(0.0,0.22,abs(near_r-1.5));
    col+=float3(1.0,0.96,0.88)*halo*Photon_Halo*(0.5+level*0.7);
    col*=0.7+level*0.6;
    col=aces_eh(col);
    float2 d=uv-0.5;
    col*=1.0-saturate(dot(d,d)*0.60);
    float mix_amount=saturate(Mix_With_Source);
    return float4(lerp(src.rgb,col,mix_amount),
                  lerp(src.a,1.0,mix_amount));
}
