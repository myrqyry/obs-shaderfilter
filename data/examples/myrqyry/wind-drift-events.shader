// Wind Drift Events — procedural petals, leaves and feathers for OBS Shaderfilter
// MIT-inspired wind, tumbling and vortex vocabulary from Profesor Shader (2026):
// https://github.com/profesorshader/shader-wind-driven-falling-leaves-petals-feathers
// This shader uses an independent stateless 2D implementation, not Godot's particle engine.
// Guide, attribution and license: docs/shaders/wind-drift-events/README.md
// Standard Shaderfilter .shader template (Entire Effect OFF).
// No extra textures or framebuffer feedback. Overlay Only outputs premultiplied RGBA.
// On ordinary filtered camera/video, composite is the default to preserve content.

uniform string Wind_About<
 string label="Trigger";
 string widget_type="info";
> = "Burst: disable then enable this filter for each alert. Continuous runs while enabled. For a transparent effect use Shaderfilter Source, or filter a transparent full-frame source.";

uniform int Wind_Mode<
 string label="Playback";
 string widget_type="select";
 int option_0_value=0; string option_0_label="Burst on enable";
 int option_1_value=1; string option_1_label="Continuous";
> = 0;

uniform int Wind_Style<
 string label="Shape";
 string widget_type="select";
 int option_0_value=0; string option_0_label="Sakura petals";
 int option_1_value=1; string option_1_label="Leaves";
 int option_2_value=2; string option_2_label="Feathers";
> = 0;

uniform int Wind_Count<
 string label="Particle count (GPU cost)";
 string widget_type="slider";
 int minimum=1; int maximum=24; int step=1;
> = 12;

uniform float Wind_Size<
 string label="Particle size";
 string widget_type="slider";
 float minimum=0.003; float maximum=0.045; float step=0.001;
> = 0.016;

uniform float Wind_Fall<
 string label="Fall speed";
 string widget_type="slider";
 float minimum=0.10; float maximum=2.0; float step=0.01;
> = 0.55;

uniform float Wind_Direction<
 string label="Wind direction (degrees)";
 string widget_type="slider";
 float minimum=-180.0; float maximum=180.0; float step=1.0;
> = 20.0;

uniform float Wind_Force<
 string label="Wind force";
 string widget_type="slider";
 float minimum=0.0; float maximum=1.5; float step=0.01;
> = 0.30;

uniform float Wind_Gust<
 string label="Gust variation";
 string widget_type="slider";
 float minimum=0.0; float maximum=1.0; float step=0.01;
> = 0.38;

uniform float Wind_Swirl<
 string label="Swirl";
 string widget_type="slider";
 float minimum=0.0; float maximum=1.0; float step=0.01;
> = 0.22;

uniform float Wind_Tumble<
 string label="Tumbling";
 string widget_type="slider";
 float minimum=0.0; float maximum=2.5; float step=0.01;
> = 0.70;

uniform float Wind_Duration<
 string label="Burst duration (seconds)";
 string widget_type="slider";
 float minimum=1.0; float maximum=15.0; float step=0.25;
> = 5.0;

uniform float Wind_Opacity<
 string label="Opacity";
 string widget_type="slider";
 float minimum=0.0; float maximum=1.0; float step=0.01;
> = 0.80;

uniform float4 Wind_Tint<
 string label="Color tint";
 string widget_type="color";
> = {1.0, 1.0, 1.0, 1.0};

uniform int Wind_Seed<
 string label="Arrangement seed";
 string widget_type="slider";
 int minimum=0; int maximum=999; int step=1;
> = 21;

uniform bool Wind_OverlayOnly<
 string label="Transparent overlay only";
 string widget_type="checkbox";
> = false;

static const float WIND_PI = 3.14159265358979323846;

float windHash(float n) {
 return frac(sin(n * 127.1 + 78.233) * 43758.5453);
}

// Shape coordinates: y=-1 at top, +1 at bottom; x is horizontal.
// Each profile has a physically distinct silhouette, not a generic circle.
float windSilhouette(float2 q, int style, float aa) {
 float y=abs(q.y);
 if (y >= 1.0 + aa) return 0.0;
 float width=0.0;
 if (style == 0) {
   // Round-bellied petal with a tapered base and off-center shoulder.
   float taper=sqrt(max(0.0,1.0-y*y));
   width=0.76*taper*(0.88-0.24*q.y);
 } else if (style == 1) {
   // Pointed leaf with gently irregular lobed margins.
   float taper=max(0.0,1.0-y);
   width=(0.88*taper+0.03)* (0.92+0.08*cos(q.y*18.0));
 } else {
   // Narrow feather with tapered ends and a slightly ragged edge.
   float taper=max(0.0,1.0-y);
   width=(0.15+0.50*sqrt(taper))* (0.96+0.04*cos(q.y*32.0));
 }
 float edge=1.0-smoothstep(width-aa,width+aa,abs(q.x));
 float cap=1.0-smoothstep(1.0-aa,1.0+aa,y);
 return saturate(edge*cap);
}

float4 mainImage(VertData v_in) : TARGET
{
 float2 uv=v_in.uv;
 // A single final source sample, only if compositing onto existing imagery.
 float aspect=max(uv_size.x/max(uv_size.y,1.0),0.01);
 float2 p=float2(uv.x*aspect,uv.y);
 float t=max(0.0, (Wind_Mode==0) ? elapsed_time_enable : elapsed_time);
 float duration=max(Wind_Duration,1.0);
 float fall=max(Wind_Fall,0.1);
 float2 direction=float2(cos(Wind_Direction*WIND_PI/180.0),
                         sin(Wind_Direction*WIND_PI/180.0));
 float3 baseColor=(Wind_Style==0)?float3(0.99,0.76,0.83):
                  ((Wind_Style==1)?float3(0.79,0.60,0.35):float3(0.91,0.88,0.78));
 float3 colorSum=float3(0.0,0.0,0.0);
 float alpha=0.0;
 // Strict bound (24 candidates per output pixel). Each particle uses stateless position
 // evaluation from index, seed and time. No hidden simulation state.
 [loop]
 for (int i=0;i<24;i++) {
   if (i>=Wind_Count) break;
   float id=float(i)+float(Wind_Seed)*37.0;
   float h0=windHash(id+1.0);
   float h1=windHash(id+12.0);
   float h2=windHash(id+27.0);
   float h3=windHash(id+43.0);
   float h4=windHash(id+72.0);
   float h5=windHash(id+109.0);
   float depth=lerp(0.60,1.30,h2);
   float size=Wind_Size*depth;
   float styleFall=(Wind_Style==2)?0.72:((Wind_Style==0)?0.89:1.0);
   float styleSpin=(Wind_Style==2)?0.48:((Wind_Style==1)?1.45:0.82);
   float life=duration*(0.72+0.50*h1);
   float delay=(0.08+0.80*h0);
   float age=0.0;
   float eventFade=1.0;
   if (Wind_Mode==0) {
     // Each activation creates one finite burst, spread across 0.8s.
     age=t-delay;
     if (age<0.0 || age>life) continue;
     eventFade=(1.0-smoothstep(life*0.78,life,age));
   } else {
     // Continuous, temporally seamless respawn, unique phase per particle.
     age=frac((t*fall/max(duration,1.0))+h0)*life;
     eventFade=1.0-smoothstep(life*0.85,life,age);
     eventFade*=smoothstep(0.0,life*0.11,age);
   }
   float u=saturate(age/max(life,0.001));
   float height=1.15+size*3.0;
   // Wind growth from time integrated displacement plus two low-frequency gusts.
   float lateral=Wind_Force*age*0.105;
   float gust=Wind_Gust*0.07*(
     sin((t+h3*5.0)*1.7)-sin((t-age+h3*5.0)*1.7));
   float swirl=Wind_Swirl*0.075*(
     sin(6.0*u+h4*6.283)-sin(h4*6.283));
   float2 center=float2((0.03+0.94*h1)*aspect,-0.09-size*2.0);
   center+=float2(direction.x*lateral+gust+swirl,
                  height*u*(0.65+0.85*fall)*styleFall+direction.y*lateral*0.30);
   // A localized vortex drifts objects sideways without collapsing the field.
   center.x+=Wind_Swirl*0.04*sin(u*8.0+h5*6.283);
   if (Wind_Style==2) center.x+=0.026*sin(age*3.8+h3*6.283);
   float2 particleLocal=(p-center)/max(size,0.0005);
   // Early reject before trigonometric shape evaluation.
   if (abs(particleLocal.x)>1.8 || abs(particleLocal.y)>1.8) continue;
   float spin=Wind_Tumble*styleSpin*(0.8+1.5*h3)*age + h4*6.283;
   float cs=cos(spin),sn=sin(spin);
   float2 q=float2(cs*particleLocal.x+sn*particleLocal.y,-sn*particleLocal.x+cs*particleLocal.y);
   // Edge-on foreshortening makes shapes tumble as they fall.
   float front=0.28+0.72*abs(cos(spin*0.83+h5*5.0));
   q.x/=front;
   float aa=clamp(1.2/(max(size,0.001)*max(uv_size.y,1.0)),0.014,0.22);
   float silhouette=windSilhouette(q,Wind_Style,aa);
   if (silhouette<=0.0) continue;
   // Slight natural per-object shading with no high-frequency flashing.
   float shade=0.79+0.21*abs(cos(spin*0.67+h3*3.0));
   float a=saturate(silhouette*Wind_Opacity*Wind_Tint.a*eventFade
                    *(0.58+0.42*h2));
   float3 pigment=baseColor*Wind_Tint.rgb*shade;
   colorSum+=(1.0-alpha)*a*pigment;
   alpha+=(1.0-alpha)*a;
 }
 alpha=saturate(alpha);
 if (Wind_OverlayOnly)
   return float4(colorSum,alpha);
 float4 original=image.Sample(textureSampler,uv);
 // OBS Shader Source blends with ONE / INV_SRC_ALPHA, so output is
 // premultiplied; never divide RGB by alpha (causes bright fringe artifacts).
 return float4(colorSum+original.rgb*original.a*(1.0-alpha),
               alpha+original.a*(1.0-alpha));
}
