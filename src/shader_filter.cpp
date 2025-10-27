#include "shader_filter.hpp"
#include "shader_filter_data.hpp"
#include "hot_reload.hpp"
#include "multi_input.hpp"
#include "audio_reactive.hpp"
#include "global_uniforms.hpp"

#include <obs/obs-module.h>
#include <obs/graphics/graphics.h>
#include <obs/graphics/image-file.h>
#include <obs/util/platform.h>
#include <obs/util/dstr.h>

namespace shader_filter {

const char *FILTER_ID = "obs_shaderfilter_plus_next_filter";

static const char *filter_get_name(void *unused);
static void *filter_create(obs_data_t *settings, obs_source_t *source);
static void filter_destroy(void *data);
static void filter_update(void *data, obs_data_t *settings);
static void filter_render(void *data, gs_effect_t *effect);
static void filter_defaults(obs_data_t *settings);

void register_filter()
{
    struct obs_source_info filter_info = {};
    filter_info.id = FILTER_ID;
    filter_info.type = OBS_SOURCE_TYPE_FILTER;
    filter_info.output_flags = OBS_SOURCE_VIDEO | OBS_SOURCE_CUSTOM_DRAW;

    filter_info.get_name = filter_get_name;
    filter_info.create = filter_create;
    filter_info.destroy = filter_destroy;
    filter_info.update = filter_update;
    filter_info.video_render = filter_render;
    filter_info.get_properties = get_properties;
    filter_info.get_defaults = filter_defaults;

    obs_register_source(&filter_info);
}

static const char *filter_get_name(void *unused)
{
    UNUSED_PARAMETER(unused);
    return obs_module_text("ShaderFilterPlusNext");
}

static void *filter_create(obs_data_t *settings, obs_source_t *source)
{
    filter_data *filter = new filter_data(source);
    filter->effect = nullptr;
    filter->render_target_a = nullptr;
    filter->render_target_b = nullptr;
    filter->use_buffer_a = true;
    filter->target_width = 0;
    filter->target_height = 0;

    filter->secondary_source = nullptr;
    filter->mask_source = nullptr;
    filter->secondary_texrender = nullptr;
    filter->mask_texrender = nullptr;

    filter->shader_path = nullptr;
    filter->use_effect_file = false;
    filter->hot_reload_enabled = false;

    filter->audio_source = nullptr;
    filter->audio_capture = nullptr;
    filter->spectrum_bands = 128;
    filter->audio_reactivity_strength = 1.0f;
    filter->audio_reactive_enabled = false;
    filter->front_buffer.fill(0.0f);
    filter->back_buffer.fill(0.0f);
    // Initialize audio smoothing fields (keep in sync with defaults)
    filter->audio_attack = 0.5f;
    filter->audio_release = 0.3f;
    filter->audio_gain = 1.0f;
    filter->smoothed_spectrum.fill(0.0f);

    // New audio texture fields
    filter->audio_textures_enabled = false;
    filter->high_res_spectrum.fill(0.0f);
    filter->spectrogram_data.fill(0.0f);
    filter->waveform_data.fill(0.0f);
    filter->audio_spectrum_tex = nullptr;
    filter->audio_spectrogram_tex = nullptr;
    filter->audio_waveform_tex = nullptr;

    filter_update(filter, settings);

    return filter;
}

static void filter_destroy(void *data)
{
    filter_data *filter = static_cast<filter_data*>(data);

    if (filter->shader_path && filter->hot_reload_enabled) {
        hot_reload::unwatch_file(filter->shader_path, filter);
    }

    obs_enter_graphics();

    if (filter->effect) {
        gs_effect_destroy(filter->effect);
    }

    if (filter->render_target_a) {
        gs_texrender_destroy(filter->render_target_a);
    }

    if (filter->render_target_b) {
        gs_texrender_destroy(filter->render_target_b);
    }

    // Destroy audio textures
    if (filter->audio_spectrum_tex) {
        gs_texture_destroy(filter->audio_spectrum_tex);
    }
    if (filter->audio_spectrogram_tex) {
        gs_texture_destroy(filter->audio_spectrogram_tex);
    }
    if (filter->audio_waveform_tex) {
        gs_texture_destroy(filter->audio_waveform_tex);
    }

    obs_leave_graphics();

    multi_input::cleanup_textures(filter);

    if (filter->secondary_source) {
        obs_weak_source_release(filter->secondary_source);
    }

    if (filter->mask_source) {
        obs_weak_source_release(filter->mask_source);
    }

    if (filter->audio_source) {
        obs_weak_source_release(filter->audio_source);
    }
    // audio_capture_data is defined in audio_reactive.cpp; free it via the audio_reactive API
    audio_reactive::free_capture_data(filter->audio_capture);

    bfree(filter->shader_path);

    delete filter;
}

static bool load_shader_from_file(filter_data *filter, const char *path)
{
#ifndef TEST_HARNESS_BUILD
    obs_enter_graphics();

    if (filter->effect) {
        gs_effect_destroy(filter->effect);
        filter->effect = nullptr;
    }

    char *error_string = nullptr;
    filter->effect = gs_effect_create_from_file(path, &error_string);

    if (filter->last_error_string) {
        bfree(filter->last_error_string);
        filter->last_error_string = nullptr;
    }

    if (!filter->effect) {
        blog(LOG_ERROR, "[ShaderFilter Plus Next] Failed to load shader '%s': %s",
             path, error_string ? error_string : "unknown error");
        if (error_string) {
            filter->last_error_string = error_string;
        }
        obs_leave_graphics();
        return false;
    }

    if (error_string) {  // Also add null check in success case
        bfree(error_string);
    }
    obs_leave_graphics();
#else
    // In test harness mode, we don't have a graphics context,
    // so we just log and pretend the shader loaded.
    blog(LOG_INFO, "[Test Harness] Pretending to load shader: %s", path);
#endif
    blog(LOG_INFO, "[ShaderFilter Plus Next] Loaded shader: %s", path);
    return true;
}

static void filter_update(void *data, obs_data_t *settings)
{
    filter_data *filter = static_cast<filter_data*>(data);

    const char *shader_path = obs_data_get_string(settings, "shader_file");
    bool use_effect = obs_data_get_bool(settings, "use_effect_file");

    if (shader_path && *shader_path) {
        bool path_changed = !filter->shader_path ||
                           strcmp(filter->shader_path, shader_path) != 0;

        if (path_changed) {
            bfree(filter->shader_path);
            filter->shader_path = bstrdup(shader_path);
            filter->use_effect_file = use_effect;

            load_shader_from_file(filter, shader_path);
        }
    }

    bool hot_reload = obs_data_get_bool(settings, "hot_reload_enabled");
    if (hot_reload != filter->hot_reload_enabled) {
        filter->hot_reload_enabled = hot_reload;

        if (hot_reload && filter->shader_path) {
            hot_reload::watch_file(filter->shader_path, filter);
        } else if (!hot_reload && filter->shader_path) {
            hot_reload::unwatch_file(filter->shader_path, filter);
        }
    }

    filter->expand_left = (int)obs_data_get_int(settings, "expand_left");
    filter->expand_right = (int)obs_data_get_int(settings, "expand_right");
    filter->expand_top = (int)obs_data_get_int(settings, "expand_top");
    filter->expand_bottom = (int)obs_data_get_int(settings, "expand_bottom");
    filter->override_entire_effect = obs_data_get_bool(settings, "override_entire_effect");

    multi_input::update_sources(filter, settings);
    audio_reactive::update_settings(filter, settings);
}

static void ensure_render_targets(filter_data *filter, uint32_t width, uint32_t height)
{
    if (filter->render_target_a &&
        filter->target_width == width &&
        filter->target_height == height) {
        return;
    }

    if (filter->render_target_a) {
        gs_texrender_destroy(filter->render_target_a);
        gs_texrender_destroy(filter->render_target_b);
    }

    filter->render_target_a = gs_texrender_create(GS_RGBA, GS_ZS_NONE);
    filter->render_target_b = gs_texrender_create(GS_RGBA, GS_ZS_NONE);
    filter->target_width = width;
    filter->target_height = height;

    blog(LOG_DEBUG, "[ShaderFilter Plus Next] Created render targets: %dx%d",
         width, height);
}

static void filter_render(void *data, gs_effect_t *effect)
{
    UNUSED_PARAMETER(effect);

    filter_data *filter = static_cast<filter_data*>(data);

    // Check if a hot reload is pending
    if (filter->needs_reload.exchange(false)) {
        reload_shader(filter);
    }

    if (!filter->effect) {
        obs_source_skip_video_filter(filter->context);
        return;
    }

    obs_source_t *target = obs_filter_get_target(filter->context);
    uint32_t base_width = obs_source_get_base_width(target);
    uint32_t base_height = obs_source_get_base_height(target);

    if (!base_width || !base_height) {
        obs_source_skip_video_filter(filter->context);
        return;
    }

    uint32_t width = base_width + filter->expand_left + filter->expand_right;
    uint32_t height = base_height + filter->expand_top + filter->expand_bottom;

    ensure_render_targets(filter, width, height);

    multi_input::render_sources(filter);

    gs_effect_t *render_effect = filter->override_entire_effect ?
                                 filter->effect : obs_get_base_effect(OBS_EFFECT_DEFAULT);

    gs_eparam_t *param_image = gs_effect_get_param_by_name(filter->effect, "image");
    gs_eparam_t *param_elapsed = gs_effect_get_param_by_name(filter->effect, "elapsed_time");
    gs_eparam_t *param_uv_size = gs_effect_get_param_by_name(filter->effect, "uv_size");

    obs_data_t *settings = obs_source_get_settings(filter->context);
    bool feedback_enabled = obs_data_get_bool(settings, "feedback_settings");
    obs_data_release(settings);

    gs_texrender_t *current_target = filter->use_buffer_a ?
                                     filter->render_target_a : filter->render_target_b;
    gs_texrender_t *previous_target = filter->use_buffer_a ?
                                      filter->render_target_b : filter->render_target_a;

    if (gs_texrender_begin(current_target, width, height)) {
        gs_viewport_push();
        gs_projection_push();

        if (filter->override_entire_effect) {
            gs_ortho(0.0f, (float)width, 0.0f, (float)height, -100.0f, 100.0f);
            gs_set_viewport(0, 0, width, height);
        } else {
            gs_ortho(0.0f, (float)base_width, 0.0f, (float)base_height, -100.0f, 100.0f);
            gs_set_viewport(0, 0, base_width, base_height);
        }

        struct vec2 uv_size = {(float)width, (float)height};
        if (param_uv_size) {
            gs_effect_set_vec2(param_uv_size, &uv_size);
        }

        if (param_elapsed) {
            float time = (float)obs_get_video_frame_time() / 1000000000.0f;
            gs_effect_set_float(param_elapsed, time);
        }

        gs_eparam_t *param_previous = gs_effect_get_param_by_name(filter->effect, "previous_frame");
        if (param_previous) {
            gs_texture_t *prev_tex = gs_texrender_get_texture(previous_target);
            gs_effect_set_texture(param_previous, prev_tex);
        }

        multi_input::bind_textures(filter, filter->effect);
        audio_reactive::bind_audio_data(filter, filter->effect);
        global_uniforms::bind_to_effect(filter->effect);

        if (!filter->override_entire_effect) {
             obs_source_process_filter_begin(filter->context, GS_RGBA, OBS_ALLOW_DIRECT_RENDERING);
        }

        obs_source_process_filter_end(filter->context, filter->effect, width, height);

        gs_projection_pop();
        gs_viewport_pop();
        gs_texrender_end(current_target);
    }

	if (current_target) {
		gs_texture_t *tex = gs_texrender_get_texture(current_target);
		if (tex) {
			gs_effect_t *pass_through =
				obs_get_base_effect(OBS_EFFECT_DEFAULT);
			gs_eparam_t *image = gs_effect_get_param_by_name(
				pass_through, "image");
			gs_effect_set_texture(image, tex);

			while (gs_effect_loop(pass_through, "Draw")) {
				gs_draw_sprite(tex, 0, width, height);
			}
		}
	}

    filter->use_buffer_a = !filter->use_buffer_a;
}

static void filter_defaults(obs_data_t *settings)
{
    obs_data_set_default_bool(settings, "use_effect_file", false);
    obs_data_set_default_int(settings, "expand_left", 0);
    obs_data_set_default_int(settings, "expand_right", 0);
    obs_data_set_default_int(settings, "expand_top", 0);
    obs_data_set_default_int(settings, "expand_bottom", 0);
    obs_data_set_default_bool(settings, "override_entire_effect", false);
    obs_data_set_default_bool(settings, "hot_reload_enabled", false);

    obs_data_set_default_double(settings, "trail_length", 0.85);

    multi_input::set_defaults(settings);
    audio_reactive::set_defaults(settings);
}

void reload_shader(void *data)
{
    filter_data *filter = static_cast<filter_data*>(data);
    if (filter->shader_path) {
        blog(LOG_INFO, "[ShaderFilter Plus Next] Hot-reloading shader: %s",
             filter->shader_path);
        load_shader_from_file(filter, filter->shader_path);
    }
}

} // namespace shader_filter