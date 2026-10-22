// Compile *and render* the Mixwell ShaderFilter effect in native libobs.
// The old compile-only check passed even when OpenGL treated the PI constant
// as uninitialized and the nonzero-strength shader produced a flat dark frame.
#include <obs/obs.h>
#include <obs/graphics/graphics.h>
#include <obs/util/bmem.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { WIDTH = 256, HEIGHT = 144, PIXELS = WIDTH * HEIGHT };
static void set_float(gs_effect_t *fx, const char *name, float value) {
    gs_eparam_t *p = gs_effect_get_param_by_name(fx, name);
    if (p) gs_effect_set_float(p, value);
}
static void set_int(gs_effect_t *fx, const char *name, int value) {
    gs_eparam_t *p = gs_effect_get_param_by_name(fx, name);
    if (p) gs_effect_set_int(p, value);
}

// Draw the actual pixel shader and stage its RGBA output for verification.
// Same image and clock for all cases; ONLY strength/direction vary.
static int draw_case(gs_effect_t *fx, gs_texture_t *source, uint8_t *out,
                     float strength, float rotation, int quality, int strokes) {
    gs_texrender_t *target = gs_texrender_create(GS_RGBA, GS_ZS_NONE);
    gs_stagesurf_t *stage = gs_stagesurface_create(WIDTH, HEIGHT, GS_RGBA);
    int ok = 0;
    if (!target || !stage) goto done;

    struct vec2 size, one, zero, interval;
    vec2_set(&size, (float)WIDTH, (float)HEIGHT);
    vec2_set(&one, 1.f, 1.f);
    vec2_zero(&zero);
    vec2_set(&interval, 1.f / WIDTH, 1.f / HEIGHT);
    gs_effect_set_texture(gs_effect_get_param_by_name(fx, "image"), source);
    gs_effect_set_vec2(gs_effect_get_param_by_name(fx, "uv_size"), &size);
    gs_effect_set_vec2(gs_effect_get_param_by_name(fx, "uv_scale"), &one);
    gs_effect_set_vec2(gs_effect_get_param_by_name(fx, "uv_offset"), &zero);
    gs_effect_set_vec2(gs_effect_get_param_by_name(fx, "uv_pixel_interval"), &interval);
    set_float(fx, "elapsed_time", 2.7f);
    set_float(fx, "FluidGlass_Strength", strength);
    set_float(fx, "FluidGlass_Radius", 0.12f);
    set_float(fx, "FluidGlass_Length", 0.48f);
    set_float(fx, "FluidGlass_Speed", 0.f);
    set_float(fx, "FluidGlass_CenterX", 0.5f);
    set_float(fx, "FluidGlass_CenterY", 0.5f);
    set_float(fx, "FluidGlass_Rotation", rotation);
    set_int(fx, "FluidGlass_Strokes", strokes);
    set_int(fx, "FluidGlass_Quality", quality);

    gs_set_cull_mode(GS_NEITHER);
    gs_texrender_reset(target);
    if (!gs_texrender_begin(target, WIDTH, HEIGHT)) goto done;

    struct vec4 clear;
    vec4_zero(&clear);
    gs_clear(GS_CLEAR_COLOR, &clear, 0, 0);
    gs_projection_push();
    gs_matrix_push();
    gs_matrix_identity();
    gs_ortho(0, (float)WIDTH, 0, (float)HEIGHT, -100.f, 100.f);
    int passes = 0;
    while (gs_effect_loop(fx, "Draw")) {
        gs_draw_sprite(source, 0, WIDTH, HEIGHT);
        ++passes;
    }
    gs_matrix_pop();
    gs_projection_pop();
    gs_texrender_end(target);
    if (passes != 1) {
        fprintf(stderr, "Expected one Draw pass, got %d\n", passes);
        goto done;
    }

    gs_stage_texture(stage, gs_texrender_get_texture(target));
    uint8_t *map = NULL;
    uint32_t stride = 0;
    if (!gs_stagesurface_map(stage, &map, &stride)) goto done;
    for (size_t y = 0; y < HEIGHT; ++y)
        memcpy(out + y * WIDTH * 4, map + y * stride, WIDTH * 4);
    gs_stagesurface_unmap(stage);
    ok = 1;
done:
    if (stage) gs_stagesurface_destroy(stage);
    if (target) gs_texrender_destroy(target);
    return ok;
}

static int render_checks(gs_effect_t *fx) {
    uint8_t *input = malloc(PIXELS * 4);
    uint8_t *neutral = malloc(PIXELS * 4);
    uint8_t *turn0 = malloc(PIXELS * 4);
    uint8_t *turn90 = malloc(PIXELS * 4);
    uint8_t *detailed = malloc(PIXELS * 4);
    uint8_t *single = malloc(PIXELS * 4);
    if (!input || !neutral || !turn0 || !turn90 || !detailed || !single) {
        free(input); free(neutral); free(turn0); free(turn90);
        free(detailed); free(single);
        return 0;
    }

    // Mixed gradient, checker pattern and partially transparent corner.
    // A flat shader or a missing input texture cannot pass the comparisons.
    for (unsigned y = 0; y < HEIGHT; ++y) {
        for (unsigned x = 0; x < WIDTH; ++x) {
            unsigned i = (y * WIDTH + x) * 4;
            int checker = ((x / 6 + y / 5) & 1) != 0;
            input[i + 0] = (uint8_t)((x * 191 / WIDTH) + (checker ? 58 : 0));
            input[i + 1] = (uint8_t)((y * 210 / HEIGHT) + (checker ? 14 : 0));
            input[i + 2] = (uint8_t)((x + y * 3) % 256);
            input[i + 3] = (x < WIDTH / 4 && y < HEIGHT / 3) ? 128 : 255;
        }
    }
    const uint8_t *data = input;
    gs_texture_t *source = gs_texture_create(WIDTH, HEIGHT, GS_RGBA, 1, &data, 0);
    int ok = source
        && draw_case(fx, source, neutral, 0.f, 0.f, 8, 2)
        && draw_case(fx, source, turn0, 0.65f, 0.f, 8, 2)
        && draw_case(fx, source, turn90, 0.65f, 90.f, 8, 2)
        && draw_case(fx, source, detailed, 0.65f, 90.f, 16, 2)
        && draw_case(fx, source, single, 0.65f, 90.f, 8, 1);
    size_t pixels_changed = 0, rotation_changed = 0, varied = 0;
    size_t quality_changed = 0, strokes_changed = 0;
    if (ok) {
        const unsigned center = ((HEIGHT / 2) * WIDTH + WIDTH / 2) * 4;
        for (size_t p = 0; p < PIXELS; ++p) {
            size_t i = p * 4;
            if (memcmp(neutral + i, turn0 + i, 3)) ++pixels_changed;
            if (memcmp(turn0 + i, turn90 + i, 3)) ++rotation_changed;
            if (memcmp(turn90 + i, detailed + i, 3)) ++quality_changed;
            if (memcmp(turn90 + i, single + i, 3)) ++strokes_changed;
            if (memcmp(turn0 + i, turn0 + center, 3)) ++varied;
        }
        // The former bug produced one flat, nearly black frame for any
        // direction. Requiring spatial texture, response and directional
        // dependence catches that regression independently of driver colors.
        ok = pixels_changed > PIXELS / 100
          && rotation_changed > PIXELS / 100
          && varied > PIXELS / 5
          && quality_changed > PIXELS / 1000
          && strokes_changed > PIXELS / 100
          && turn0[center + 3] > 32
          && turn90[center + 3] > 32;
    }
    fprintf(stdout,
            "NATIVE_OBS_SHADER_RENDER_PASS=%d changed=%zu rotation=%zu quality=%zu strokes=%zu varied=%zu\n",
            ok, pixels_changed, rotation_changed, quality_changed, strokes_changed, varied);

    if (source) gs_texture_destroy(source);
    free(input); free(neutral); free(turn0); free(turn90);
    free(detailed); free(single);
    return ok;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s SHADER_EFFECT\n", argv[0]);
        return 2;
    }
    FILE *f = fopen(argv[1], "rb");
    if (!f) { perror("fopen"); return 2; }
    if (fseek(f, 0, SEEK_END)) { fclose(f); return 2; }
    long size = ftell(f);
    if (size <= 0) { fclose(f); return 2; }
    rewind(f);
    char *src = calloc((size_t)size + 1, 1);
    if (!src || fread(src, 1, (size_t)size, f) != (size_t)size) {
        fprintf(stderr, "read failure\n");
        free(src); fclose(f); return 2;
    }
    fclose(f);
    if (!obs_startup("en-US", NULL, NULL)) { free(src); return 3; }

    struct obs_video_info ovi = {0};
    ovi.graphics_module = "libobs-opengl";
    ovi.fps_num = 30; ovi.fps_den = 1;
    ovi.base_width = WIDTH; ovi.base_height = HEIGHT;
    ovi.output_width = WIDTH; ovi.output_height = HEIGHT;
    ovi.output_format = VIDEO_FORMAT_RGBA;
    ovi.colorspace = VIDEO_CS_709; ovi.range = VIDEO_RANGE_FULL;
    ovi.scale_type = OBS_SCALE_BILINEAR;
    if (obs_reset_video(&ovi) != OBS_VIDEO_SUCCESS) {
        free(src); obs_shutdown(); return 4;
    }
    obs_enter_graphics();
    char *errors = NULL;
    gs_effect_t *fx = gs_effect_create(src, "mixwell-fluid-glass", &errors);
    if (errors && *errors) fprintf(stderr, "Shader messages: %s\n", errors);
    int ok = fx != NULL;
    if (fx) {
        const char *required[] = {
            "image", "uv_size", "uv_scale", "uv_offset",
            "uv_pixel_interval", "elapsed_time",
            "FluidGlass_Strength", "FluidGlass_Radius", "FluidGlass_Length",
            "FluidGlass_Speed", "FluidGlass_CenterX", "FluidGlass_CenterY",
            "FluidGlass_Rotation", "FluidGlass_Strokes", "FluidGlass_Quality"
        };
        for (size_t i = 0; i < sizeof(required)/sizeof(required[0]); ++i) {
            if (!gs_effect_get_param_by_name(fx, required[i])) {
                fprintf(stderr, "Missing shader parameter: %s\n", required[i]);
                ok = 0;
            }
        }
        if (ok) printf("NATIVE_OBS_SHADER_COMPILE_PASS=1 params=%zu\n", gs_effect_get_num_params(fx));
        if (ok) ok = render_checks(fx);
    }
    if (fx) gs_effect_destroy(fx);
    bfree(errors);
    obs_leave_graphics();
    obs_shutdown();
    free(src);
    if (!ok) fprintf(stderr, "NATIVE_OBS_SHADER_FAIL\n");
    return ok ? 0 : 5;
}
