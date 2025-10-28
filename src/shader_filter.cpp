#include "shader_filter.hpp"
#include "shader_filter_data.hpp"
#include "hot_reload.hpp"
#include "multi_input.hpp"
#include "audio_reactive.hpp"
#include "global_uniforms.hpp"
#include "logging.hpp"

#include <obs/obs-module.h>
#include <obs/graphics/graphics.h>
#include <obs/graphics/image-file.h>
#include <obs/util/platform.h>
#include <obs/util/dstr.h>
#include "wrappers.hpp"

#include <filesystem>
#include <algorithm>

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

    graphics_context_guard guard;

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

static bool validate_shader_path(const char *path) {
    if (!path || !*path) return false;

    // Define allowed shader directories
    static const std::vector<std::string> allowed_directories = {
        "data/shaders/",
        "data/examples/",
        obs_get_module_data_path(obs_current_module(), "shaders/"),
        obs_get_module_data_path(obs_current_module(), "examples/")
    };

    std::filesystem::path canonical_path;
    try {
        canonical_path = std::filesystem::canonical(path);
    } catch (const std::filesystem::filesystem_error&) {
        return false;
    }

    // Check if path is within allowed directories
    bool in_allowed_dir = false;
    for (const auto& allowed_dir : allowed_directories) {
        std::filesystem::path allowed_canonical;
        try {
            allowed_canonical = std::filesystem::canonical(allowed_dir);
            auto rel_path = std::filesystem::relative(canonical_path, allowed_canonical);
            if (!rel_path.empty() && rel_path.string().substr(0, 2) != "..") {
                in_allowed_dir = true;
                break;
            }
        } catch (const std::filesystem::filesystem_error&) {
            continue;
        }
    }

    if (!in_allowed_dir) return false;

    // Validate extension
    std::string ext = canonical_path.extension().string();
    std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
    return ext == ".effect" || ext == ".shader" || ext == ".hlsl";
}

static bool load_shader_from_file(filter_data *filter, const char *path)
{
    if (!validate_shader_path(path)) {
        plugin_error("Invalid shader path: %s", path);
        return false;
    }
#ifndef TEST_HARNESS_BUILD
    graphics_context_guard guard;

    gs_effect_guard new_effect;
    char *error_string = nullptr;
    new_effect.effect = gs_effect_create_from_file(path, &error_string);

    if (filter->last_error_string) {
        bfree(filter->last_error_string);
        filter->last_error_string = nullptr;
    }

    if (!new_effect.effect) {
        plugin_error("Failed to load shader '%s': %s",
             path, error_string ? error_string : "unknown error");
        if (error_string) {
            filter->last_error_string = bstrdup(error_string);
            bfree(error_string);
        }
        return false;
    }

    if (error_string) {
        bfree(error_string);
    }

    if (filter->effect) {
        gs_effect_destroy(filter->effect);
    }
    filter->effect = new_effect.release();

#else
    // In test harness mode, we don't have a graphics context,
    // so we just log and pretend the shader loaded.
    blog(LOG_INFO, "[Test Harness] Pretending to load shader: %s", path);
#endif
    plugin_info("Loaded shader: %s", path);
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

static void ensure_render_targets(filter_data *filter, uint32_t width, uint32_t height) {
    // Larger tolerance to reduce recreation frequency
    constexpr uint32_t SIZE_TOLERANCE = 64;
    constexpr uint32_t PADDING_BLOCK = 128; // Larger blocks for fewer recreations

    bool needs_recreation = !filter->render_target_a ||
        width > filter->target_width || height > filter->target_height ||
        (filter->target_width - width) > SIZE_TOLERANCE * 2 ||
        (filter->target_height - height) > SIZE_TOLERANCE * 2;

    if (!needs_recreation) {
        return;
    }

    // More aggressive padding to prevent frequent recreations
    uint32_t padded_width = ((width + PADDING_BLOCK - 1) / PADDING_BLOCK) * PADDING_BLOCK;
    uint32_t padded_height = ((height + PADDING_BLOCK - 1) / PADDING_BLOCK) * PADDING_BLOCK;

    // Add 25% extra padding for growth
    padded_width = static_cast<uint32_t>(padded_width * 1.25f);
    padded_height = static_cast<uint32_t>(padded_height * 1.25f);

    // Defer destruction until after creation to avoid GPU stalls
    gs_texrender_t *old_target_a = filter->render_target_a;
    gs_texrender_t *old_target_b = filter->render_target_b;

    filter->render_target_a = gs_texrender_create(GS_RGBA, GS_ZS_NONE);
    filter->render_target_b = gs_texrender_create(GS_RGBA, GS_ZS_NONE);

    if (old_target_a) {
        gs_texrender_destroy(old_target_a);
        gs_texrender_destroy(old_target_b);
    }

    filter->target_width = padded_width;
    filter->target_height = padded_height;
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
        bool viewport_pushed = false;
        bool projection_pushed = false;

        try {
            gs_viewport_push();
            viewport_pushed = true;

            gs_projection_push();
            projection_pushed = true;

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

        } catch (...) {
            plugin_error("Graphics operation failed during shader render");
        }

        // Ensure proper cleanup regardless of success/failure
        if (projection_pushed) gs_projection_pop();
        if (viewport_pushed) gs_viewport_pop();
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
        plugin_info("Hot-reloading shader: %s",
             filter->shader_path);
        load_shader_from_file(filter, filter->shader_path);
    }
}

} // namespace shader_filter