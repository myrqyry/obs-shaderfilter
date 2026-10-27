// Real OBS Shaderfilter integration for a batch of file-backed filter shaders.
// Mesa/Xvfb OpenGL: verify actual plugin load, controls, changed pixels, bypass, alpha.
#include <obs.h>
#include <obs-module.h>
#include <graphics/graphics.h>
#include <vector>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <thread>
#include <chrono>
#include <algorithm>
#include <cmath>

constexpr unsigned W=256,H=144;
using Frame=std::vector<uint8_t>;
struct Fixture { gs_texture_t *texture=nullptr; };

Frame pattern() {
    Frame v(W*H*4);
    for(unsigned y=0;y<H;++y) for(unsigned x=0;x<W;++x) {
        size_t i=4*(size_t(y)*W+x);
        bool checker=((x/8+y/9)%2)==0;
        v[i]=uint8_t(checker?215:38);
        v[i+1]=uint8_t(y*228/H);
        v[i+2]=uint8_t(checker?33:224);
        v[i+3]=uint8_t(x<15?0:255);
    }
    return v;
}
const char* source_name(void*){return "Curated shader test image";}
uint32_t source_width(void*){return W;}
uint32_t source_height(void*){return H;}
void *source_create(obs_data_t*,obs_source_t*){
    auto *f=new Fixture;
    auto bytes=pattern();
    const uint8_t *pixel=bytes.data();
    obs_enter_graphics();f->texture=gs_texture_create(W,H,GS_RGBA,1,&pixel,0);obs_leave_graphics();
    return f;
}
void source_destroy(void*p){
    auto *f=(Fixture*)p;
    obs_enter_graphics(); gs_texture_destroy(f->texture); obs_leave_graphics();delete f;
}
void source_render(void*p,gs_effect_t*){auto *f=(Fixture*)p;obs_source_draw(f->texture,0,0,W,H,false);}
obs_source_info source_info {
    .id="curated_shader_fixture",
    .type=OBS_SOURCE_TYPE_INPUT,
    .output_flags=OBS_SOURCE_VIDEO,
    .get_name=source_name,
    .create=source_create,
    .destroy=source_destroy,
    .get_width=source_width,
    .get_height=source_height,
    .video_render=source_render
};
Frame capture(obs_source_t *s) {
    Frame out;
    obs_enter_graphics();
    auto *target=gs_texrender_create(GS_RGBA,GS_ZS_NONE);
    auto *stage=gs_stagesurface_create(W,H,GS_RGBA);
    if(target && stage && gs_texrender_begin(target,W,H)) {
        gs_projection_push();gs_matrix_push();gs_matrix_identity();
        gs_ortho(0,float(W),0,float(H),-100,100);
        obs_source_video_render(s);
        gs_matrix_pop();gs_projection_pop();gs_texrender_end(target);
        auto *tex=gs_texrender_get_texture(target);
        if(tex) {
            gs_stage_texture(stage,tex);
            uint8_t *bytes=nullptr;uint32_t stride=0;
            if(gs_stagesurface_map(stage,&bytes,&stride)) {
                out.resize(W*H*4);
                for(unsigned y=0;y<H;++y)
                    std::memcpy(out.data()+size_t(y)*W*4, bytes+size_t(y)*stride,W*4);
                gs_stagesurface_unmap(stage);
            }
        }
    }
    if(stage)gs_stagesurface_destroy(stage);
    if(target)gs_texrender_destroy(target);
    obs_leave_graphics();
    return out;
}
size_t diff(const Frame&a,const Frame&b,int start,int end){
    if(a.size()!=b.size()||a.empty())return SIZE_MAX;
    size_t n=0;
    for(size_t i=0;i<a.size();i+=4)
       for(int c=start;c<end;++c)
          n+=std::abs(int(a[i+c])-int(b[i+c]))>2;
    return n;
}
Frame settle(obs_source_t *s){
    Frame out;
    for(int i=0;i<5;++i){
        out=capture(s);
        std::this_thread::sleep_for(std::chrono::milliseconds(32));
    }
    return out;
}
int main(int argc,char**argv) {
    if(argc<4){std::fprintf(stderr,"usage: verify MODULE DATA SHADER... \n");return 2;}
    if(!obs_startup("en-US",nullptr,nullptr))return 3;
    obs_video_info video{};
    video.graphics_module="libobs-opengl";
    video.fps_num=30;video.fps_den=1;
    video.base_width=W;video.base_height=H;video.output_width=W;video.output_height=H;
    video.output_format=VIDEO_FORMAT_RGBA;video.scale_type=OBS_SCALE_DISABLE;
    if(obs_reset_video(&video)!=OBS_VIDEO_SUCCESS){obs_shutdown();return 4;}
    obs_register_source(&source_info);
    obs_module_t *module=nullptr;
    bool opened=obs_open_module(&module,argv[1],argv[2])==MODULE_SUCCESS;
    if(!opened||!obs_init_module(module)){std::fprintf(stderr,"MODULE_LOAD_FAIL\n");obs_shutdown();return 5;}
    obs_source_t *s=obs_source_create("curated_shader_fixture","fixture",nullptr,nullptr);
    if(!s){obs_shutdown();return 6;}
    obs_source_inc_showing(s);
    Frame baseline=settle(s);
    bool all=true;
    for(int n=3;n<argc;++n) {
        auto *settings=obs_data_create();
        obs_data_set_bool(settings,"from_file",true);
        obs_data_set_bool(settings,"override_entire_effect",false);
        obs_data_set_string(settings,"shader_file_name",argv[n]);
        auto *f=obs_source_create("shader_filter",argv[n],settings,nullptr);
        obs_data_release(settings);
        if(!f){std::printf("PORT_FAIL %s create\n",argv[n]);all=false;continue;}
        obs_source_filter_add(s,f);
        Frame enabled=settle(s);
        auto *p=obs_source_properties(f);
        auto *group=p?obs_properties_get(p,"shader_params_group"):nullptr;
        auto *params=group?obs_property_group_content(group):nullptr;
        bool controls=params&&obs_properties_get(params,"Mix");
        if(p)obs_properties_destroy(p);
        auto *state=obs_source_get_settings(f);
        const char *error=obs_data_get_string(state,"last_error");
        bool compiled=!error||!*error;
        if(!compiled)std::fprintf(stderr,"PARSE_ERROR %s: %s\n",argv[n],error);
        obs_data_release(state);
        state=obs_source_get_settings(f);
        obs_data_set_double(state,"Mix",0.0);
        obs_source_update(f,state);
        obs_data_release(state);
        Frame bypass=settle(s);
        size_t visible=diff(baseline,enabled,0,3);
        size_t noMix=diff(baseline,bypass,0,3);
        size_t alpha=diff(baseline,enabled,3,4);
        bool pass=compiled&&controls&&visible>500&&noMix<100&&alpha<100;
        std::printf("PORT_%s %s visible=%zu bypass=%zu alpha=%zu controls=%d compile=%d\n",
             pass?"PASS":"FAIL",argv[n],visible,noMix,alpha,controls,compiled);
        std::fflush(stdout);
        all&=pass;
        obs_source_filter_remove(s,f);
        obs_source_release(f);
    }
    obs_source_dec_showing(s);obs_source_release(s);obs_shutdown();
    std::printf("CURATED_REAL_PLUGIN_GPU_PASS=%d\n",all);
    return all?0:7;
}
