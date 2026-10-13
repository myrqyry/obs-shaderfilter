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
    gs_effect_t *effect=gs_effect_create(text,"hyper-stdlib-test",&errors);
    int ok=(effect!=NULL);
    if(errors && *errors)fprintf(stderr,"shader errors: %s\n",errors);
    if(ok){
        printf("STDLIB_NATIVE_EFFECT_PASS=1 params=%zu\n",gs_effect_get_num_params(effect));
        gs_effect_destroy(effect);
    }else{fprintf(stderr,"STDLIB_NATIVE_EFFECT_FAIL\n");}
    bfree(errors);
    obs_leave_graphics();
    obs_shutdown();
    free(text);
    return ok?0:5;
}
