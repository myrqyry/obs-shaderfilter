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

    // All substructs are default-initialized
    filter->shader.effect = nullptr;
    filter->shader.render_target_a = nullptr;
    filter->shader.render_target_b = nullptr;
    filter->shader.use_buffer_a = true;
    filter->shader.target_width = 0;
    filter->shader.target_height = 0;

    filter_update(filter, settings);

    return filter;
}

static void filter_destroy(void *data)
{
    filter_data *filter = static_cast<filter_data*>(data);

    if (filter->hot_reload.shader_path && filter->hot_reload.hot_reload_enabled) {
        hot_reload::unwatch_file(filter);
    }

    graphics_context_guard guard;

    if (filter->shader.effect) {
        gs_effect_destroy(filter->shader.effect);
    }

    if (filter->shader.render_target_a) {
        gs_texrender_destroy(filter->shader.render_target_a);
    }

    if (filter->shader.render_target_b) {
        gs_texrender_destroy(filter->shader.render_target_b);
    }

    // Destroy audio textures
    if (filter->audio.audio_spectrum_tex) {
        gs_texture_destroy(filter->audio.audio_spectrum_tex);
    }
    if (filter->audio.audio_spectrogram_tex) {
        gs_texture_destroy(filter->audio.audio_spectrogram_tex);
    }
    if (filter->audio.audio_waveform_tex) {
        gs_texture_destroy(filter->audio.audio_waveform_tex);
    }

    multi_input::cleanup_textures(filter);

    if (filter->multi_input.secondary_source) {
        obs_weak_source_release(filter->multi_input.secondary_source);
    }

    if (filter->multi_input.mask_source) {
        obs_weak_source_release(filter->multi_input.mask_source);
    }

    if (filter->audio.audio_source) {
        obs_weak_source_release(filter->audio.audio_source);
    }
    // audio_capture_data is defined in audio_reactive.cpp; free it via the audio_reactive API
    audio_reactive::free_capture_data(filter->audio.audio_capture);

    bfree(filter->hot_reload.shader_path);

    delete filter;
}

static bool is_subdirectory(const std::filesystem::path& base, const std::filesystem::path& path) {
    auto rel = std::filesystem::relative(path, base);
    return !rel.empty() && rel.native().find("..") != 0;
}

static bool validate_shader_path(const char *path) {
    if (!path || !*path) return false;

    // 1. Reject paths containing ".." to prevent traversal.
    std::string path_str = path;
    if (path_str.find("..") != std::string::npos) {
        plugin_error("Shader path contains traversal characters: %s", path);
        return false;
    }

    // Define allowed shader directories
    const char* data_path = obs_get_module_data_path(obs_current_module(), "");
    static const std::vector<std::filesystem::path> allowed_directories = {
        std::filesystem::path(data_path) / "shaders",
        std::filesystem::path(data_path) / "examples"
    };

    std::filesystem::path canonical_path;
    try {
        canonical_path = std::filesystem::canonical(path);
    } catch (const std::filesystem::filesystem_error&) {
        return false; // Path does not exist or is invalid.
    }

    // 2. Check if the canonical path is a descendant of any allowed directory.
    bool in_allowed_dir = false;
    for (const auto& allowed_dir : allowed_directories) {
        std::filesystem::path allowed_canonical;
        try {
             if (std::filesystem::exists(allowed_dir)) {
                allowed_canonical = std::filesystem::canonical(allowed_dir);
                if (is_subdirectory(allowed_canonical, canonical_path)) {
                    in_allowed_dir = true;
                    break;
                }
             }
        } catch (const std::filesystem::filesystem_error&) {
            continue;
        }
    }

    if (!in_allowed_dir) {
        plugin_error("Shader path is not in an allowed directory: %s", path);
        return false;
    }

    // 3. Validate extension.
    std::string ext = canonical_path.extension().string();
    std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
    const std::vector<std::string> allowed_extensions = {".effect", ".shader", ".hlsl"};
    if (std::find(allowed_extensions.begin(), allowed_extensions.end(), ext) == allowed_extensions.end()) {
        plugin_error("Shader path has an invalid extension: %s", path);
        return false;
    }

    return true;
}

#include <fstream>
#include <sstream>

static std::string preprocess_shader(const char *path, std::vector<std::string>& visited_files);

static void process_include(const std::string& line, const std::filesystem::path& parent_path, std::vector<std::string>& visited_files, std::stringstream& buffer) {
    size_t start = line.find('"');
    size_t end = line.rfind('"');
    if (start != std::string::npos && end != std::string::npos && start != end) {
        std::string include_path_str = line.substr(start + 1, end - start - 1);
        std::filesystem::path include_path = parent_path / include_path_str;
        if (validate_shader_path(include_path.string().c_str())) {
            buffer << preprocess_shader(include_path.string().c_str(), visited_files);
        } else {
            // Error is logged within validate_shader_path
        }
    } else {
        buffer << line << std::endl;
    }
}

static std::string preprocess_shader(const char *path, std::vector<std::string>& visited_files)
{
    std::string canonical_path_str;
    try {
        canonical_path_str = std::filesystem::canonical(path).string();
    } catch (const std::filesystem::filesystem_error&) {
        plugin_error("Failed to get canonical path for: %s", path);
        return "";
    }

    if (std::find(visited_files.begin(), visited_files.end(), canonical_path_str) != visited_files.end()) {
        plugin_error("Circular include detected: %s", path);
        return "";
    }

    visited_files.push_back(canonical_path_str);

    std::ifstream file(path);
    if (!file.is_open()) {
        plugin_error("Failed to open shader file: %s", path);
        return "";
    }

    std::stringstream buffer;
    std::string line;
    std::filesystem::path parent_path = std::filesystem::path(path).parent_path();

    while (std::getline(file, line)) {
        if (line.find("#include") != std::string::npos && line.find("//") != 0) {
            process_include(line, parent_path, visited_files, buffer);
        } else {
            buffer << line << std::endl;
        }
    }

    return buffer.str();
}

static bool load_shader_from_file(filter_data *filter, const char *path)
{
    if (!validate_shader_path(path)) {
        return false;
    }

    std::vector<std::string> visited_files;
    std::string processed_shader = preprocess_shader(path, visited_files);

    if (processed_shader.empty()) {
        return false;
    }

#ifndef TEST_HARNESS_BUILD
    graphics_context_guard guard;

    gs_effect_guard new_effect;
    char *error_string = nullptr;
    new_effect.effect = gs_effect_create(processed_shader.c_str(), path, &error_string);

    if (filter->hot_reload.last_error_string) {
        bfree(filter->hot_reload.last_error_string);
        filter->hot_reload.last_error_string = nullptr;
    }

    if (!new_effect.effect) {
        plugin_error("Failed to load shader '%s': %s",
             path, error_string ? error_string : "unknown error");
        if (error_string) {
            filter->hot_reload.last_error_string = bstrdup(error_string);
            bfree(error_string);
        }
        return false;
    }

    if (error_string) {
        bfree(error_string);
    }

    if (filter->shader.effect) {
        gs_effect_destroy(filter->shader.effect);
    }
    filter->shader.effect = new_effect.release();

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
        bool path_changed = !filter->hot_reload.shader_path ||
                           strcmp(filter->hot_reload.shader_path, shader_path) != 0;

        if (path_changed) {
            bfree(filter->hot_reload.shader_path);
            filter->hot_reload.shader_path = bstrdup(shader_path);
            filter->hot_reload.use_effect_file = use_effect;

            load_shader_from_file(filter, shader_path);
        }
    }

    bool hot_reload_enabled = obs_data_get_bool(settings, "hot_reload_enabled");
    if (hot_reload_enabled != filter->hot_reload.hot_reload_enabled) {
        filter->hot_reload.hot_reload_enabled = hot_reload_enabled;

        if (hot_reload_enabled && filter->hot_reload.shader_path) {
            hot_reload::watch_file(filter);
        } else if (!hot_reload_enabled && filter->hot_reload.shader_path) {
            hot_reload::unwatch_file(filter);
        }
    }

    filter->shader.expand_left = (int)obs_data_get_int(settings, "expand_left");
    filter->shader.expand_right = (int)obs_data_get_int(settings, "expand_right");
    filter->shader.expand_top = (int)obs_data_get_int(settings, "expand_top");
    filter->shader.expand_bottom = (int)obs_data_get_int(settings, "expand_bottom");
    filter->shader.override_entire_effect = obs_data_get_bool(settings, "override_entire_effect");

    multi_input::update_sources(filter, settings);
    audio_reactive::update_settings(filter, settings);
}

static void ensure_render_targets(filter_data *filter, uint32_t width, uint32_t height) {
    // Larger tolerance to reduce recreation frequency
    constexpr uint32_t SIZE_TOLERANCE = 64;
    constexpr uint32_t PADDING_BLOCK = 128; // Larger blocks for fewer recreations

    bool needs_recreation = !filter->shader.render_target_a ||
        width > filter->shader.target_width || height > filter->shader.target_height ||
        (filter->shader.target_width - width) > SIZE_TOLERANCE * 2 ||
        (filter->shader.target_height - height) > SIZE_TOLERANCE * 2;

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
    gs_texrender_t *old_target_a = filter->shader.render_target_a;
    gs_texrender_t *old_target_b = filter->shader.render_target_b;

    filter->shader.render_target_a = gs_texrender_create(GS_RGBA, GS_ZS_NONE);
    filter->shader.render_target_b = gs_texrender_create(GS_RGBA, GS_ZS_NONE);

    if (old_target_a) {
        gs_texrender_destroy(old_target_a);
        gs_texrender_destroy(old_target_b);
    }

    filter->shader.target_width = padded_width;
    filter->shader.target_height = padded_height;
}

static void filter_render(void *data, gs_effect_t *effect)
{
    UNUSED_PARAMETER(effect);

    filter_data *filter = static_cast<filter_data*>(data);

    // Check if a hot reload is pending
    if (filter->hot_reload.needs_reload.exchange(false)) {
        reload_shader(filter);
    }

    if (!filter->shader.effect) {
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

    uint32_t width = base_width + filter->shader.expand_left + filter->shader.expand_right;
    uint32_t height = base_height + filter->shader.expand_top + filter->shader.expand_bottom;

    ensure_render_targets(filter, width, height);

    multi_input::render_sources(filter);

    gs_effect_t *render_effect = filter->shader.override_entire_effect ?
                                 filter->shader.effect : obs_get_base_effect(OBS_EFFECT_DEFAULT);

    gs_eparam_t *param_image = gs_effect_get_param_by_name(filter->shader.effect, "image");
    gs_eparam_t *param_elapsed = gs_effect_get_param_by_name(filter->shader.effect, "elapsed_time");
    gs_eparam_t *param_uv_size = gs_effect_get_param_by_name(filter->shader.effect, "uv_size");

    obs_data_t *settings = obs_source_get_settings(filter->context);
    bool feedback_enabled = obs_data_get_bool(settings, "feedback_settings");
    obs_data_release(settings);

    gs_texrender_t *current_target = filter->shader.use_buffer_a ?
                                     filter->shader.render_target_a : filter->shader.render_target_b;
    gs_texrender_t *previous_target = filter->shader.use_buffer_a ?
                                      filter->shader.render_target_b : filter->shader.render_target_a;

    if (gs_texrender_begin(current_target, width, height)) {
        bool viewport_pushed = false;
        bool projection_pushed = false;

        try {
            gs_viewport_push();
            viewport_pushed = true;

            gs_projection_push();
            projection_pushed = true;

            if (filter->shader.override_entire_effect) {
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

            gs_eparam_t *param_previous = gs_effect_get_param_by_name(filter->shader.effect, "previous_frame");
            if (param_previous) {
                gs_texture_t *prev_tex = gs_texrender_get_texture(previous_target);
                gs_effect_set_texture(param_previous, prev_tex);
            }

            multi_input::bind_textures(filter, filter->shader.effect);
            audio_reactive::bind_audio_data(filter, filter->shader.effect);
            global_uniforms::bind_to_effect(filter->shader.effect);

            if (!filter->shader.override_entire_effect) {
                 obs_source_process_filter_begin(filter->context, GS_RGBA, OBS_ALLOW_DIRECT_RENDERING);
            }

            obs_source_process_filter_end(filter->context, filter->shader.effect, width, height);

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

    filter->shader.use_buffer_a = !filter->shader.use_buffer_a;
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
    if (filter->hot_reload.shader_path) {
        plugin_info("Hot-reloading shader: %s",
             filter->hot_reload.shader_path);
        load_shader_from_file(filter, filter->hot_reload.shader_path);
    }
}

} // namespace shader_filter