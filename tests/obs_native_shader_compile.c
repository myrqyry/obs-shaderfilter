#include <obs/obs.h>
#include <obs/graphics/graphics.h>
#include <obs/util/bmem.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    if(argc!=2){fprintf(stderr,"Usage: %s SHADER_EFFECT\n",argv[0]);return 2;}
    FILE *f=fopen(argv[1],"rb");if(!f){perror("fopen");return 2;}
    fseek(f,0,SEEK_END);long size=ftell(f);rewind(f);
    char *text=calloc((size_t)size+1,1);
    if(!text||fread(text,1,(size_t)size,f)!=(size_t)size){fprintf(stderr,"read failure\n");return 2;}
    fclose(f);
    if(!obs_startup("en-US",NULL,NULL)){fprintf(stderr,"obs_startup failed\n");return 3;}
    struct obs_video_info ovi={0};
    ovi.graphics_module="libobs-opengl";
    ovi.fps_num=30;ovi.fps_den=1;
    ovi.base_width=320;ovi.base_height=240;
    ovi.output_width=320;ovi.output_height=240;
    ovi.output_format=VIDEO_FORMAT_RGBA;ovi.colorspace=VIDEO_CS_709;
    ovi.range=VIDEO_RANGE_FULL;ovi.scale_type=OBS_SCALE_BILINEAR;
    int status=obs_reset_video(&ovi);
    if(status!=OBS_VIDEO_SUCCESS){fprintf(stderr,"obs_reset_video failed: %d\n",status);obs_shutdown();return 4;}
    obs_enter_graphics();
    char *errors=NULL;
    gs_effect_t *effect=gs_effect_create(text,"mixwell-fluid-glass",&errors);
    int ok=(effect!=NULL);
    if(errors && *errors)fprintf(stderr,"shader errors: %s\n",errors);
    if (effect) {
        const char *names[] = {
            "image", "uv_size", "elapsed_time", "FluidGlass_Strength",
            "FluidGlass_Radius", "FluidGlass_Length", "FluidGlass_Speed",
            "FluidGlass_CenterX", "FluidGlass_CenterY",
            "FluidGlass_Rotation", "FluidGlass_Strokes", "FluidGlass_Quality"
        };
        for (size_t i=0; i<sizeof(names)/sizeof(names[0]); i++) {
            if (!gs_effect_get_param_by_name(effect,names[i])) {
                fprintf(stderr,"Missing required shader parameter: %s\n",names[i]);
                ok=0;
            }
        }
    }
    if(ok) printf("NATIVE_OBS_SHADER_COMPILE_PASS=1 params=%zu\n",gs_effect_get_num_params(effect));
    else fprintf(stderr,"NATIVE_OBS_SHADER_COMPILE_FAIL\n");
    if (effect) gs_effect_destroy(effect);
    bfree(errors);
    obs_leave_graphics();
    obs_shutdown();
    free(text);
    return ok?0:5;
}
