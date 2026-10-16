// Real libobs/OpenGL pixel readback for native .shader compilation outputs.
// Run from verify_noisemaker_ports.py. No shader mocks or precomputed pixels.
#include <obs/obs.h>
#include <obs/graphics/graphics.h>
#include <obs/graphics/vec2.h>
#include <obs/util/bmem.h>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

constexpr uint32_t W=128,H=96;
using Frame=std::vector<uint8_t>;

Frame sample(bool partialAlpha=false) {
    Frame a(W*H*4);
    for (uint32_t y=0;y<H;y++) for (uint32_t x=0;x<W;x++) {
        size_t p=(y*W+x)*4;
        bool checker=((x/13+y/11)&1);
        a[p]=(uint8_t)((23+x*187/W + (checker?35:0))%256);
        a[p+1]=(uint8_t)((17+y*217/H + (checker?16:0))%256);
        a[p+2]=(uint8_t)((45+(x*3+y*2)%173+(checker?35:0))%256);
        // A mixed-opacity fixture verifies that effects preserve source alpha,
        // not merely that opaque inputs remain opaque.
        a[p+3]=partialAlpha ? uint8_t(((x/11+y/9)%5)*63) : 255;
    }
    return a;
}

Frame render(gs_effect_t* effect,gs_texture_t* source,const char* uniform,float value,
             const char* presetUniform="",float presetValue=0.f) {
    Frame pixels;
    gs_set_cull_mode(GS_NEITHER);
    gs_texrender_t* target=gs_texrender_create(GS_RGBA,GS_ZS_NONE);
    gs_stagesurf_t* surface=gs_stagesurface_create(W,H,GS_RGBA);
    if(target && surface && gs_texrender_begin(target,W,H)) {
        gs_projection_push();
        gs_matrix_push();
        gs_matrix_identity();
        gs_ortho(0.f,float(W),0.f,float(H),-100.f,100.f);
        auto* input=gs_effect_get_param_by_name(effect,"image");
        if(input)gs_effect_set_texture(input,source);
        struct vec2 size,interval,one,zero;
        vec2_set(&size,float(W),float(H));
        vec2_set(&interval,1.f/float(W),1.f/float(H));
        vec2_set(&one,1.f,1.f);
        vec2_set(&zero,0.f,0.f);
        if(auto* p=gs_effect_get_param_by_name(effect,"uv_size"))gs_effect_set_vec2(p,&size);
        if(auto* p=gs_effect_get_param_by_name(effect,"uv_pixel_interval"))gs_effect_set_vec2(p,&interval);
        if(auto* p=gs_effect_get_param_by_name(effect,"uv_scale"))gs_effect_set_vec2(p,&one);
        if(auto* p=gs_effect_get_param_by_name(effect,"uv_offset"))gs_effect_set_vec2(p,&zero);
        auto* param=gs_effect_get_param_by_name(effect,uniform);
        if(param) {
            struct gs_effect_param_info info={};
            gs_effect_get_param_info(param,&info);
            if(info.type==GS_SHADER_PARAM_INT)gs_effect_set_int(param,int(value));
            else if(info.type==GS_SHADER_PARAM_BOOL)gs_effect_set_bool(param,value!=0.f);
            else gs_effect_set_float(param,value);
        }
        if(presetUniform[0]) {
            if(auto* p=gs_effect_get_param_by_name(effect,presetUniform)) {
                struct gs_effect_param_info info={};
                gs_effect_get_param_info(p,&info);
                if(info.type==GS_SHADER_PARAM_INT)gs_effect_set_int(p,int(presetValue));
                else if(info.type==GS_SHADER_PARAM_BOOL)gs_effect_set_bool(p,presetValue!=0.f);
                else gs_effect_set_float(p,presetValue);
            }
        }
        while(gs_effect_loop(effect,"Draw"))gs_draw_sprite(source,0,W,H);
        gs_matrix_pop();gs_projection_pop();gs_texrender_end(target);
        if(auto* tex=gs_texrender_get_texture(target)) {
            gs_stage_texture(surface,tex);
            uint8_t* ptr=nullptr;uint32_t pitch=0;
            if(gs_stagesurface_map(surface,&ptr,&pitch)) {
                pixels.resize(W*H*4);
                for(uint32_t y=0;y<H;y++)
                    std::memcpy(pixels.data()+y*W*4,ptr+y*pitch,W*4);
                gs_stagesurface_unmap(surface);
            }
        }
    }
    if(surface)gs_stagesurface_destroy(surface);
    if(target)gs_texrender_destroy(target);
    return pixels;
}

int main(int argc,char** argv) {
    if(argc<5 || argc>7){std::fprintf(stderr,"usage: probe EFFECT UNIFORM A B [partial-alpha] [uniform=value]\n");return 2;}
    bool partialAlpha=false;
    std::string presetName;
    float presetValue=0.f;
    for(int i=5;i<argc;i++) {
        if(std::strcmp(argv[i],"partial-alpha")==0) {
            partialAlpha=true;
        } else {
            std::string arg=argv[i];
            size_t pos=arg.find('=');
            if(pos==std::string::npos || pos==0 || !presetName.empty())return 2;
            presetName=arg.substr(0,pos);
            presetValue=std::strtof(arg.c_str()+pos+1,nullptr);
        }
    }
    if(!obs_startup("en-US",nullptr,nullptr))return 3;
    struct obs_video_info v={};
    v.graphics_module="libobs-opengl";
    v.fps_num=30;v.fps_den=1;
    v.base_width=W;v.base_height=H;
    v.output_width=W;v.output_height=H;
    v.output_format=VIDEO_FORMAT_RGBA;
    v.scale_type=OBS_SCALE_DISABLE;
    if(obs_reset_video(&v)!=OBS_VIDEO_SUCCESS){obs_shutdown();return 4;}
    bool valid=false;
    obs_enter_graphics();
    char* err=nullptr;
    auto* effect=gs_effect_create_from_file(argv[1],&err);
    if(err){std::fprintf(stderr,"COMPILE_ERROR=%s\n",err);bfree(err);}
    if(effect) {
        auto* param=gs_effect_get_param_by_name(effect,argv[2]);
        if(!param)std::fprintf(stderr,"MISSING_CONTROL=%s\n",argv[2]);
        else {
            auto data=sample(partialAlpha);
            const uint8_t* bytes=data.data();
            auto* texture=gs_texture_create(W,H,GS_RGBA,1,&bytes,0);
            if(texture) {
                float a=std::strtof(argv[3],nullptr),b=std::strtof(argv[4],nullptr);
                auto first=render(effect,texture,argv[2],a,presetName.c_str(),presetValue);
                auto second=render(effect,texture,argv[2],b,presetName.c_str(),presetValue);
                if(first.size()==data.size()&&second.size()==data.size()) {
                    size_t changed=0,changedInput=0,alphaChanged=0;
                    uint64_t sum=0;
                    for(size_t p=0;p<data.size();p+=4) {
                        bool diff=false,diffInput=false;
                        for(int c=0;c<3;c++) {
                            if(std::abs(int(first[p+c])-int(second[p+c]))>2)diff=true;
                            if(std::abs(int(first[p+c])-int(data[p+c]))>2)diffInput=true;
                            sum+=second[p+c];
                        }
                        changed+=diff;
                        changedInput+=diffInput;
                        alphaChanged+=first[p+3]!=data[p+3]||second[p+3]!=data[p+3];
                    }
                    std::printf("GPU_READBACK_PASS=1 CONTROL=%s CHANGED=%zu CHANGED_FROM_INPUT=%zu ALPHA_CHANGED=%zu RGB_SUM=%llu\n",
                        argv[2],changed,changedInput,alphaChanged,(unsigned long long)sum);
                    valid=true;
                } else std::fprintf(stderr,"NO_PIXEL_READBACK\n");
                gs_texture_destroy(texture);
            }
        }
        gs_effect_destroy(effect);
    }
    obs_leave_graphics();
    obs_shutdown();
    return valid?0:5;
}
