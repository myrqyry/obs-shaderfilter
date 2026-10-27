#include <obs.h>
#include <obs-module.h>
#include <graphics/graphics.h>
#include <cstdio>
#include <cstring>
#include <vector>
#include <thread>
#include <chrono>
#include <cstdlib>
#include <cstdint>
#include <algorithm>
constexpr unsigned W=256,H=144;
using Frame=std::vector<uint8_t>;
Frame render(obs_source_t* source) {
 Frame pixels;
 obs_enter_graphics();
 auto* target=gs_texrender_create(GS_RGBA,GS_ZS_NONE);
 auto* stage=gs_stagesurface_create(W,H,GS_RGBA);
 if(target&&stage&&gs_texrender_begin(target,W,H)){
  gs_projection_push();gs_matrix_push();gs_matrix_identity();
  gs_ortho(0,float(W),0,float(H),-100,100);
  obs_source_video_render(source);
  gs_matrix_pop();gs_projection_pop();gs_texrender_end(target);
  if(auto* tex=gs_texrender_get_texture(target)){
   gs_stage_texture(stage,tex);
   uint8_t* map=nullptr;uint32_t stride=0;
   if(gs_stagesurface_map(stage,&map,&stride)){
    pixels.resize(W*H*4);
    for(unsigned y=0;y<H;++y)
     std::memcpy(pixels.data()+y*W*4,map+y*stride,W*4);
    gs_stagesurface_unmap(stage);
   }
  }
 }
 if(stage)gs_stagesurface_destroy(stage);
 if(target)gs_texrender_destroy(target);
 obs_leave_graphics();
 return pixels;
}
size_t diff(const Frame&a,const Frame&b){
 if(a.empty()||a.size()!=b.size())return 0;
 size_t n=0;
 for(size_t i=0;i<a.size();i+=4) n+=(std::abs(int(a[i])-int(b[i]))+std::abs(int(a[i+1])-int(b[i+1]))+std::abs(int(a[i+2])-int(b[i+2])))>5;
 return n;
}
uint64_t sum(const Frame &a){uint64_t n=0;for(size_t i=0;i<a.size();i+=4)n+=a[i]+a[i+1]+a[i+2];return n;}
int main(int argc,char**argv){
 if(argc!=4){std::fprintf(stderr,"usage: PLUGIN BIN DATA SHADER\n");return 2;}
 if(!obs_startup("en-US",nullptr,nullptr))return 2;
 obs_video_info v{};v.graphics_module="libobs-opengl";v.fps_num=30;v.fps_den=1;v.base_width=W;v.base_height=H;v.output_width=W;v.output_height=H;
 v.output_format=VIDEO_FORMAT_RGBA;v.scale_type=OBS_SCALE_DISABLE;
 if(obs_reset_video(&v)!=OBS_VIDEO_SUCCESS){obs_shutdown();return 2;}
 obs_module_t* mod=nullptr;bool loaded=obs_open_module(&mod,argv[1],argv[2])==MODULE_SUCCESS;
 loaded=loaded&&obs_init_module(mod);if(!loaded){std::puts("PLUGIN_LOAD_FAIL");obs_shutdown();return 3;}
 obs_data_t* settings=obs_data_create();
 obs_data_set_bool(settings,"from_file",true);
 obs_data_set_string(settings,"shader_file_name",argv[3]);
 obs_data_set_int(settings,"source_width",W);obs_data_set_int(settings,"source_height",H);
 auto*source=obs_source_create("shader_source","CrossTL Generator Probe",settings,nullptr);
 obs_data_release(settings);
 if(!source){std::puts("SOURCE_CREATE_FAIL");obs_shutdown();return 4;}
 obs_source_inc_showing(source);
 auto*low=obs_source_get_settings(source);obs_data_set_double(low,"u_strength",0.0);obs_source_update(source,low);obs_data_release(low);
 Frame first;
 for(int i=0;i<10;i++){first=render(source);std::this_thread::sleep_for(std::chrono::milliseconds(50));}
 auto*high=obs_source_get_settings(source);obs_data_set_double(high,"u_strength",1.2);obs_source_update(source,high);obs_data_release(high);
 Frame second;
 for(int i=0;i<10;i++){second=render(source);std::this_thread::sleep_for(std::chrono::milliseconds(50));}
 auto*props=obs_source_properties(source);
 auto*group=props?obs_properties_get(props,"shader_params_group"):nullptr;
 auto*inside=group?obs_property_group_content(group):nullptr;
 bool hasControl=inside&&obs_properties_get(inside,"u_strength");
 if(props)obs_properties_destroy(props);
 auto*status=obs_source_get_settings(source);
 const char*error=obs_data_get_string(status,"last_error");
 std::printf("SOURCE_DIMENSIONS=%ux%u PARAM_CONTROL=%d ERROR=%s\n",obs_source_get_width(source),obs_source_get_height(source),hasControl,error?error:"");
 std::printf("SOURCE_RENDER_INPUT_SUM=%llu OUTPUT_SUM=%llu PIXEL_DIFF=%zu\n",
  (unsigned long long)sum(first),(unsigned long long)sum(second),diff(first,second));
 bool ok=hasControl&&obs_source_get_width(source)==W&&obs_source_get_height(source)==H&&sum(first)>10000&&sum(second)>10000&&diff(first,second)>500&&(!error||!*error);
 obs_data_release(status);
 obs_source_dec_showing(source);
 obs_source_release(source);
 obs_shutdown();
 std::printf("CROSSTL_SHADER_SOURCE_PLUGIN_PASS=%d\n",ok);
 return ok?0:5;
}
