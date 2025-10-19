#include "shader_filter.hpp"
#include "shader_filter_data.hpp"
#include "hot_reload.hpp"
#include "multi_input.hpp"
#include "audio_reactive.hpp"

#include <obs/obs-module.h>
#include <graphics/graphics.h>
#include <graphics/image-file.h>
#include <util/platform.h>
#include <util/dstr.h>

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
    filter_data *filter = new filter_data();
    filter->context = source;
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
    filter->audio_spectrum = new float[256]();
    filter->spectrum_bands = 64;
    filter->audio_reactive_enabled = false;

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

    if(filter->audio_capture){
        delete filter->audio_capture;
    }

    delete[] filter->audio_spectrum;
    bfree(filter->shader_path);

    delete filter;
}

static bool load_shader_from_file(filter_data *filter, const char *path)
{
    obs_enter_graphics();

    if (filter->effect) {
        gs_effect_destroy(filter->effect);
        filter->effect = nullptr;
    }

    char *error_string = nullptr;
    filter->effect = gs_effect_create_from_file(path, &error_string);

    if (!filter->effect) {
        blog(LOG_ERROR, "[ShaderFilter Plus Next] Failed to load shader '%s': %s",
             path, error_string ? error_string : "unknown error");
        bfree(error_string);
        obs_leave_graphics();
        return false;
    }

    bfree(error_string);
    obs_leave_graphics();

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

    gs_texrender_t *current_target = filter->use_buffer_a ?
                                     filter->render_target_a : filter->render_target_b;
    gs_texrender_t *previous_target = filter->use_buffer_a ?
                                      filter->render_target_b : filter->render_target_a;

    if (gs_texrender_begin(current_target, width, height)) {

        gs_viewport_push();
        gs_projection_push();
        gs_ortho(0.0f, (float)width, 0.0f, (float)height, -100.0f, 100.0f);
        gs_set_viewport(filter->expand_left, filter->expand_top,
                       base_width, base_height);

        struct vec2 uv_size = {(float)width, (float)height};

        if (param_elapsed) {
            float time = (float)obs_get_video_frame_time() / 1000000000.0f;
            gs_effect_set_float(param_elapsed, time);
        }

        if (param_uv_size) {
            gs_effect_set_vec2(param_uv_size, &uv_size);
        }

		gs_eparam_t *param_previous = gs_effect_get_param_by_name(
			filter->effect, "previous_frame");
		if (param_previous) {
			if (previous_target) {
				gs_texture_t *prev_tex =
					gs_texrender_get_texture(
						previous_target);
				if (prev_tex) {
					gs_effect_set_texture(param_previous,
							      prev_tex);
				}
			} else {
				gs_effect_set_texture(param_previous, NULL);
			}
		}

        multi_input::bind_textures(filter, render_effect);
        audio_reactive::bind_audio_data(filter, render_effect);

        if (param_image) {
            if (obs_source_process_filter_begin(filter->context, GS_RGBA,
                                               OBS_ALLOW_DIRECT_RENDERING)) {
                obs_source_process_filter_end(filter->context, render_effect,
                                             width, height);
            }
        }

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