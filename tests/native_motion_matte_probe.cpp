// Actual libobs/OpenGL pixel readback for frame-history Shaderfilter effects.
// Compare real current and previous input textures, not fabricated GLSL output.
#include <obs/obs.h>
#include <obs/graphics/graphics.h>
#include <obs/graphics/vec2.h>
#include <obs/util/bmem.h>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

constexpr unsigned W=128,H=96;
using Frame=std::vector<uint8_t>;

Frame fixture(bool changed) {
    Frame out(W*H*4);
    for (unsigned y=0;y<H;y++) for (unsigned x=0;x<W;x++) {
        size_t p=(y*W+x)*4;
        bool motion=changed && x>=38 && x<91 && y>=27 && y<74;
        out[p]  =motion?12:uint8_t(68+x/2);
        out[p+1]=motion?18:uint8_t(40+y);
        out[p+2]=motion?24:uint8_t(132+x/4);
        out[p+3]=200;
    }
    return out;
}

void setf(gs_effect_t *effect,const char* name,float value) {
    if (auto *p=gs_effect_get_param_by_name(effect,name)) gs_effect_set_float(p,value);
}
void seti(gs_effect_t *effect,const char* name,int value) {
    if (auto *p=gs_effect_get_param_by_name(effect,name)) gs_effect_set_int(p,value);
}
Frame render(gs_effect_t* effect,gs_texture_t* current,gs_texture_t* previous,
             int mode,float started,float gain=5.f,float threshold=.08f,
             int compare=1,float enabledAge=-1.f) {
    Frame result;
    auto* target=gs_texrender_create(GS_RGBA,GS_ZS_NONE);
    auto* stage=gs_stagesurface_create(W,H,GS_RGBA);
    if (target && stage && gs_texrender_begin(target,W,H)) {
        gs_projection_push();gs_matrix_push();gs_matrix_identity();
        gs_ortho(0.f,float(W),0.f,float(H),-100.f,100.f);
        gs_set_cull_mode(GS_NEITHER);
        gs_effect_set_texture(gs_effect_get_param_by_name(effect,"image"),current);
        gs_effect_set_texture(gs_effect_get_param_by_name(effect,"previous_image"),previous);
        struct vec2 size,pix,one,zero;
        vec2_set(&size,float(W),float(H)); vec2_set(&pix,1.f/W,1.f/H);
        vec2_set(&one,1.f,1.f);vec2_set(&zero,0.f,0.f);
        if(auto*p=gs_effect_get_param_by_name(effect,"uv_size"))gs_effect_set_vec2(p,&size);
        if(auto*p=gs_effect_get_param_by_name(effect,"uv_pixel_interval"))gs_effect_set_vec2(p,&pix);
        if(auto*p=gs_effect_get_param_by_name(effect,"uv_scale"))gs_effect_set_vec2(p,&one);
        if(auto*p=gs_effect_get_param_by_name(effect,"uv_offset"))gs_effect_set_vec2(p,&zero);
        seti(effect,"display_mode",mode);seti(effect,"comparison",compare);
        setf(effect,"elapsed_time_start",started);
        setf(effect,"elapsed_time_enable", enabledAge >= 0.f ? enabledAge : started);
        setf(effect,"warmup_seconds",.1f);
        setf(effect,"blur_pixels",0.f);
        setf(effect,"gain",gain);setf(effect,"threshold",threshold);
        setf(effect,"feather",.1f);setf(effect,"highlight_strength",1.f);
        while(gs_effect_loop(effect,"Draw"))gs_draw_sprite(current,0,W,H);
        gs_matrix_pop();gs_projection_pop();gs_texrender_end(target);
        if(auto* texture=gs_texrender_get_texture(target)) {
            gs_stage_texture(stage,texture);
            uint8_t* ptr=nullptr;uint32_t pitch=0;
            if(gs_stagesurface_map(stage,&ptr,&pitch)) {
                result.resize(W*H*4);
                for(unsigned y=0;y<H;y++)
                    std::memcpy(result.data()+y*W*4,ptr+y*pitch,W*4);
                gs_stagesurface_unmap(stage);
            }
        }
    }
    if(stage)gs_stagesurface_destroy(stage);
    if(target)gs_texrender_destroy(target);
    return result;
}

int main(int argc,char** argv) {
    if(argc!=2)return 2;
    if(!obs_startup("en-US",nullptr,nullptr))return 3;
    struct obs_video_info v={};v.graphics_module="libobs-opengl";
    v.fps_num=30;v.fps_den=1;v.base_width=W;v.base_height=H;
    v.output_width=W;v.output_height=H;v.output_format=VIDEO_FORMAT_RGBA;
    v.scale_type=OBS_SCALE_DISABLE;
    if(obs_reset_video(&v)!=OBS_VIDEO_SUCCESS){obs_shutdown();return 4;}
    bool pass=false;obs_enter_graphics();
    char* err=nullptr;auto* effect=gs_effect_create_from_file(argv[1],&err);
    if(err){std::fprintf(stderr,"COMPILE_ERROR=%s\n",err);bfree(err);}
    if(effect) {
        auto current=fixture(false), previous=fixture(true);
        const uint8_t *live_bytes=current.data(),*old_bytes=previous.data();
        auto *live=gs_texture_create(W,H,GS_RGBA,1,&live_bytes,0);
        auto *old=gs_texture_create(W,H,GS_RGBA,1,&old_bytes,0);
        if(live&&old&&gs_effect_get_param_by_name(effect,"previous_image")) {
            auto still=render(effect,live,live,0,1.f);
            auto moved=render(effect,live,old,0,1.f);
            auto first=render(effect,live,old,0,0.f);
            auto cutout=render(effect,live,old,1,1.f);
            auto highlighted=render(effect,live,old,2,1.f);
            auto low=render(effect,live,old,0,1.f,.25f,.5f);
            // Re-enabled after minutes of elapsed shader runtime: the enabled
            // clock must reset even while the startup clock remains large.
            auto reenabled=render(effect,live,old,0,300.f,5.f,.08f,1,0.f);
            Frame lumCurrent(W*H*4), lumPrevious(W*H*4);
            for(size_t i=0;i<lumCurrent.size();i+=4) {
                // Rec. 601 luma green == red + 125/255 green to 0.001.
                lumCurrent[i]=0; lumCurrent[i+1]=255; lumCurrent[i+2]=0;
                lumPrevious[i]=255;lumPrevious[i+1]=125;lumPrevious[i+2]=0;
                lumCurrent[i+3]=lumPrevious[i+3]=255;
            }
            const uint8_t *lc=lumCurrent.data(),*lp=lumPrevious.data();
            auto *lLive=gs_texture_create(W,H,GS_RGBA,1,&lc,0);
            auto *lPast=gs_texture_create(W,H,GS_RGBA,1,&lp,0);
            Frame isoLuma,isoRGB;
            if(lLive && lPast) {
                isoLuma=render(effect,lLive,lPast,0,1.f,5.f,.08f,0);
                isoRGB=render(effect,lLive,lPast,0,1.f,5.f,.08f,1);
            }
            if(lLive)gs_texture_destroy(lLive);
            if(lPast)gs_texture_destroy(lPast);
            if(still.size()==current.size()&&moved.size()==current.size()&&
               first.size()==current.size()&&cutout.size()==current.size()&&
               highlighted.size()==current.size()&&low.size()==current.size()&&
               reenabled.size()==current.size()&&isoLuma.size()==current.size()&&
               isoRGB.size()==current.size()) {
                unsigned movedCount=0,stillCount=0,firstCount=0,lowCount=0;
                unsigned reenabledCount=0,lumaCount=0,rgbDiffCount=0;
                unsigned movingAlpha=0,staticAlpha=0,badRGB=0,badHighlightAlpha=0;
                unsigned highlightChanged=0;
                for(unsigned y=4;y<H-4;y++)for(unsigned x=4;x<W-4;x++) {
                    size_t p=(y*W+x)*4;
                    bool movingRegion=x>=42&&x<87&&y>=31&&y<70;
                    bool staticRegion=x<26&&y<18;
                    movedCount+=moved[p]>200;
                    stillCount+=still[p]>2;
                    firstCount+=first[p]>2;
                    lowCount+=low[p]>2;
                    reenabledCount+=reenabled[p]>2;
                    lumaCount+=isoLuma[p]>2;
                    rgbDiffCount+=isoRGB[p]>200;
                    if(movingRegion) {
                        movingAlpha+=cutout[p+3]>180;
                        highlightChanged+=std::abs(int(highlighted[p])-int(current[p]))>15;
                    }
                    if(staticRegion)staticAlpha+=cutout[p+3]>2;
                    // Straight-alpha cutout must not darken RGB that later
                    // gets premultiplied by the OBS composite stage.
                    if(std::abs(int(cutout[p])-int(current[p]))>2)badRGB++;
                    if(highlighted[p+3]!=current[p+3])badHighlightAlpha++;
                }
                pass=movedCount>1300 && stillCount==0 && firstCount==0 &&
                     lowCount==0 && reenabledCount==0 && lumaCount==0 &&
                     rgbDiffCount>5000 && movingAlpha>1300 && staticAlpha==0 &&
                     badRGB==0 && badHighlightAlpha==0 && highlightChanged>1300;
                std::printf("MOTION_MATTE_REAL_GPU_PASS=%d moved=%u still=%u warmup=%u low=%u reenable=%u iso_luma=%u iso_rgb=%u cutout=%u static_alpha=%u rgb_changed=%u highlight=%u highlight_alpha_errors=%u\n",
                           pass,movedCount,stillCount,firstCount,lowCount,reenabledCount,
                           lumaCount,rgbDiffCount,movingAlpha,staticAlpha,badRGB,highlightChanged,badHighlightAlpha);
            } else std::fprintf(stderr,"MOTION_NO_READBACK\n");
        } else std::fprintf(stderr,"MOTION_MISSING_TEXTURE_OR_PARAM\n");
        if(live)gs_texture_destroy(live);
        if(old)gs_texture_destroy(old);
        gs_effect_destroy(effect);
    }
    obs_leave_graphics();obs_shutdown();return pass?0:5;
}
