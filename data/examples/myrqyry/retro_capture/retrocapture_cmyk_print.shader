// RetroCapture / RetroArch four-screen CMYK halftone -> OBS ShaderFilter.
// Original public-domain shader: geldoronie/RetroCapture
// shaders/shaders_glsl/misc/cmyk-halftone-dot.glsl
// Original credits Stefan Gustavson's WebGL demo and hunterk RetroArch port.
// https://github.com/geldoronie/RetroCapture
// Standard-wrapper file-backed .shader. FILTER ONLY: needs source texture.
// Fidelity changes: image-height/aspect-correct dots, anti-aliased dot edges,
// configurable ink size/color, original alpha preservation, true dark K ink.
// Original generated a binary mask and blended K toward input pixel RGB.

uniform float Dot_Density<
    string label="Dots per image height"; string widget_type="slider";
    float minimum=8.0; float maximum=260.0; float step=2.0;
> = 52.0;
uniform float Screen_Rotation<
    string label="Screen rotation (degrees)"; string widget_type="slider";
    float minimum=-45.0; float maximum=45.0; float step=1.0;
> = 0.0;
uniform float Dot_Gain<
    string label="Ink dot size"; string widget_type="slider";
    float minimum=0.25; float maximum=1.50; float step=0.05;
> = 1.0;
uniform float Edge_Smoothing<
    string label="Dot edge antialiasing"; string widget_type="slider";
    float minimum=0.05; float maximum=2.0; float step=0.05;
> = 0.75;
uniform float Black_Ink<
    string label="Black ink coverage"; string widget_type="slider";
    float minimum=0.0; float maximum=1.0; float step=0.05;
> = 1.0;
uniform float4 Paper_Color<
    string label="Paper tint";
> = {1.0,0.97,0.91,1.0};
uniform float Effect_Mix<
    string label="Effect mix"; string widget_type="slider";
    float minimum=0.0; float maximum=1.0; float step=0.01;
> = 1.0;

float2 rc_rotate(float2 p,float angle) {
    float c=cos(angle),s=sin(angle);
    return float2(c*p.x-s*p.y,s*p.x+c*p.y);
}
float rc_screen(float2 p,float angle,float coverage,float density) {
    float2 cell=rc_rotate(p,angle)*density;
    float2 f=2.0*frac(cell)-1.0;
    // The original threshold tests sqrt(channel ink) against dot radius.
    float dist=length(f);
    float radius=sqrt(saturate(coverage))*Dot_Gain;
    float aa=max(0.0001,fwidth(dist)*Edge_Smoothing);
    return 1.0-smoothstep(radius-aa,radius+aa,dist);
}
float4 mainImage(VertData v_in):TARGET {
    float2 uv=v_in.uv;
    float4 src=image.Sample(textureSampler,uv);
    if(Effect_Mix<=0.0 || src.a<=0.0001)return src;
    float aspect=uv_size.x/max(uv_size.y,1.0);
    float2 coord=float2(uv.x*aspect,uv.y);
    float rot=Screen_Rotation*0.0174532925199433;
    float density=max(Dot_Density,1.0);
    float3 cmy=saturate(float3(1.0,1.0,1.0)-src.rgb);
    float black=min(cmy.x,min(cmy.y,cmy.z));
    // Four printing-screen orientations: C +15, M -15, Y 0, K +45.
    float c=rc_screen(coord,rot+0.2617993878,cmy.x,density);
    float m=rc_screen(coord,rot-0.2617993878,cmy.y,density);
    float y=rc_screen(coord,rot,            cmy.z,density);
    float k=rc_screen(coord,rot+0.7853981634,black,density)*Black_Ink;
    float3 printRgb=float3(1.0-c,1.0-m,1.0-y)*(1.0-k);
    printRgb*=Paper_Color.rgb;
    return float4(lerp(src.rgb,saturate(printRgb),saturate(Effect_Mix)),
                  src.a);
}
