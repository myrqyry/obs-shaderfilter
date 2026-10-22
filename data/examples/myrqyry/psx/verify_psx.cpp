// Native libobs OpenGL smoke harness for PSX Shaderfilter template snippets.
// Tests the generated effect, NOT a plugin filter/source lifecycle.
#include <obs.h>
#include <graphics/graphics.h>
#include <util/bmem.h>
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>
static constexpr unsigned W=256, H=144;
static const char* WRAPPER=R"FX(
uniform float4x4 ViewProj;
uniform texture2d image;
uniform float2 uv_offset;
uniform float2 uv_scale;
uniform float2 uv_pixel_interval;
uniform float2 uv_size;
uniform float rand_f;
uniform float rand_instance_f;
uniform float rand_activation_f;
uniform float elapsed_time;
uniform float elapsed_time_start;
uniform float elapsed_time_show;
uniform float elapsed_time_active;
uniform float elapsed_time_enable;
uniform int loops;
uniform float loop_second;
uniform float local_time;
sampler_state textureSampler {
    Filter = Linear;
    AddressU = Border;
    AddressV = Border;
    BorderColor = 00000000;
};
struct VertData { float4 pos : POSITION; float2 uv : TEXCOORD0; };
VertData mainTransform(VertData v_in) {
    VertData o;
    o.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
    o.uv = v_in.uv * uv_scale + uv_offset;
    return o;
}
float srgb_nonlinear_to_linear_channel(float u) {
    return (u <= 0.04045) ? (u / 12.92) : pow((u + 0.055) / 1.055, 2.4);
}
float3 srgb_nonlinear_to_linear(float3 v) {
    return float3(srgb_nonlinear_to_linear_channel(v.r),
                  srgb_nonlinear_to_linear_channel(v.g),
                  srgb_nonlinear_to_linear_channel(v.b));
}
)FX";
static const char* FOOTER=R"FX(
technique Draw {
    pass {
        vertex_shader = mainTransform(v_in);
        pixel_shader = mainImage(v_in);
    }
}
)FX";
struct Result {
 std::vector<uint8_t> rgba;
 uint64_t sum=0; size_t opaque=0;
};
static Result draw(gs_effect_t* fx,gs_texture_t* src,gs_texrender_t* target,gs_stagesurf_t* stage,float mix,float time) {
 Result r; r.rgba.resize(W*H*4);
 gs_texrender_reset(target);
 if(!gs_texrender_begin(target,W,H))return {};
 gs_projection_push(); gs_matrix_push(); gs_matrix_identity();
 gs_ortho(0,float(W),0,float(H),-100,100);
 struct vec4 clear{};gs_clear(GS_CLEAR_COLOR,&clear,0,0);
 if(auto p=gs_effect_get_param_by_name(fx,"image"))gs_effect_set_texture(p,src);
 if(auto p=gs_effect_get_param_by_name(fx,"uv_size")){
   struct vec2 v{};v.x=float(W);v.y=float(H);gs_effect_set_vec2(p,&v);
 }
 if(auto p=gs_effect_get_param_by_name(fx,"uv_pixel_interval")){
   struct vec2 v{};v.x=1.0f/W;v.y=1.0f/H;gs_effect_set_vec2(p,&v);
 }
 if(auto p=gs_effect_get_param_by_name(fx,"uv_offset")){
   struct vec2 v{};gs_effect_set_vec2(p,&v);
 }
 if(auto p=gs_effect_get_param_by_name(fx,"uv_scale")){
   struct vec2 v{};v.x=1;v.y=1;gs_effect_set_vec2(p,&v);
 }
 if(auto p=gs_effect_get_param_by_name(fx,"elapsed_time"))gs_effect_set_float(p,time);
 if(auto p=gs_effect_get_param_by_name(fx,"Mix"))gs_effect_set_float(p,mix);
 if(auto p=gs_effect_get_param_by_name(fx,"Color_Bits"))gs_effect_set_int(p,5);
 unsigned passes=0;
 while(gs_effect_loop(fx,"Draw")) {passes++;gs_draw_sprite(src,0,W,H);}
 gs_matrix_pop();gs_projection_pop();gs_texrender_end(target);
 if(passes!=1) {std::fprintf(stderr,"passes %u expected 1\n",passes);return {};}
 gs_stage_texture(stage,gs_texrender_get_texture(target));
 uint8_t* mapped=nullptr;uint32_t pitch=0;
 if(!gs_stagesurface_map(stage,&mapped,&pitch))return {};
 for(unsigned y=0;y<H;y++)for(unsigned x=0;x<W;x++){
   auto in=mapped+y*pitch+x*4, out=r.rgba.data()+(y*W+x)*4;
   for(int k=0;k<4;k++){out[k]=in[k];r.sum+=in[k];}
   if(out[3]>16)r.opaque++;
 }
 gs_stagesurface_unmap(stage);
 return r;
}
int main(int argc,char**argv) {
 if(argc<2)return 2;
 if(!obs_startup("en-US",nullptr,nullptr))return 3;
 obs_video_info v{};v.graphics_module="libobs-opengl";v.fps_num=30;v.fps_den=1;
 v.base_width=W;v.base_height=H;v.output_width=W;v.output_height=H;
 v.output_format=VIDEO_FORMAT_RGBA;v.scale_type=OBS_SCALE_DISABLE;
 if(obs_reset_video(&v)!=OBS_VIDEO_SUCCESS){obs_shutdown();return 4;}
 obs_enter_graphics();gs_set_cull_mode(GS_NEITHER);
 auto* target=gs_texrender_create(GS_RGBA,GS_ZS_NONE);
 auto* stage=gs_stagesurface_create(W,H,GS_RGBA);
 std::vector<uint8_t> input(W*H*4);
 for(unsigned y=0;y<H;y++)for(unsigned x=0;x<W;x++){
   auto* p=input.data()+(y*W+x)*4;
   p[0]=uint8_t((x*243)/W);
   p[1]=uint8_t((y*250)/H);
   p[2]=uint8_t(((x+y)*230)/(W+H));
   p[3]=(x<W/7)?0:((x<W/3)?128:255);
 }
 const uint8_t* raw=input.data();
 auto* src=gs_texture_create(W,H,GS_RGBA,1,&raw,0);
 bool success=true;
 for(int i=1;i<argc;i++){
   std::ifstream f(argv[i]);
   if(!f){std::fprintf(stderr,"UNREADABLE: %s\n",argv[i]);success=false;continue;}
   std::string shader((std::istreambuf_iterator<char>(f)),{});
   std::string effect=std::string("#define OPENGL 1\n")+WRAPPER+shader+FOOTER;
   char* errors=nullptr;
   auto* fx=gs_effect_create(effect.c_str(),argv[i],&errors);
   if(errors&&*errors)std::fprintf(stderr,"EFFECT ERR %s: %s\n",argv[i],errors);
   if(errors)bfree(errors);
   if(!fx){std::fprintf(stderr,"COMPILE FAILED %s\n",argv[i]);success=false;continue;}
   auto* tech=gs_effect_get_technique(fx,"Draw");
   if(!tech){
       std::fprintf(stderr,"BACKEND FAILED pass %s\n",argv[i]);success=false;gs_effect_destroy(fx);continue;
   }
   auto off=draw(fx,src,target,stage,0,1.0f);
   auto on=draw(fx,src,target,stage,1,1.0f);
   auto later=draw(fx,src,target,stage,1,3.5f);
   if(const char* folder=std::getenv("PSX_CAPTURE_DIR")) {
     std::string filename=argv[i];
     filename=filename.substr(filename.find_last_of("/\\")+1);
     std::ofstream out(std::string(folder)+"/"+filename+".rgba",std::ios::binary);
     out.write(reinterpret_cast<const char*>(on.rgba.data()),on.rgba.size());
   }
   size_t changed=0,time_changed=0,alpha_changed=0,opaque=0;
   for(size_t j=0;j<off.rgba.size() && j<on.rgba.size();j+=4){
     for(int k=0;k<3;k++)if(off.rgba[j+k]!=on.rgba[j+k]){changed++;break;}
     for(int k=0;k<3;k++)if(on.rgba[j+k]!=later.rgba[j+k]){time_changed++;break;}
     if(off.rgba[j+3]!=on.rgba[j+3])alpha_changed++;
     if(on.rgba[j+3]>16)opaque++;
   }
   std::printf("PSX %s | off=%llu on=%llu later=%llu altered=%zu time=%zu alpha_changed=%zu visible=%zu\n",
               argv[i],(unsigned long long)off.sum,(unsigned long long)on.sum,
               (unsigned long long)later.sum,changed,time_changed,alpha_changed,opaque);
   if(!off.sum || !on.sum || on.opaque<W*H/4 || changed<W*H/150){
      std::fprintf(stderr,"RENDER FAILED %s\n",argv[i]);success=false;
   }
   if((std::string(argv[i]).find("quantize")!=std::string::npos ||
        std::string(argv[i]).find("grade")!=std::string::npos) && alpha_changed){
      std::fprintf(stderr,"ALPHA PRESERVATION FAILED %s\n",argv[i]);success=false;
   }
   if(std::string(argv[i]).find("instability")!=std::string::npos && !time_changed){
      std::fprintf(stderr,"TIME CONTROL FAILED %s\n",argv[i]);success=false;
   }
   gs_effect_destroy(fx);
 }
 if(src)gs_texture_destroy(src);
 if(stage)gs_stagesurface_destroy(stage);
 if(target)gs_texrender_destroy(target);
 obs_leave_graphics();obs_shutdown();
 return success?0:1;
}
