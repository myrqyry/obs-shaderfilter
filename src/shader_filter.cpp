#include "shader_filter.hpp"
#include "hot_reload.hpp"
#include "multi_input.hpp"
#include "audio_reactive.hpp"

#include <obs-module.h>
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
extern obs_properties_t* get_properties(void*);
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

    filter_update(filter, settings);

    return filter;
}

static void filter_destroy(void *data)
{
    filter_data *filter = static_cast<filter_data*>(data);

    if (!filter->shader_path.empty() && filter->hot_reload_enabled) {
        hot_reload::unwatch_file(filter->shader_path.c_str(), filter);
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

    const char *shader_path_c = obs_data_get_string(settings, "shader_file");
    bool use_effect = obs_data_get_bool(settings, "use_effect_file");

    if (shader_path_c && *shader_path_c) {
        bool path_changed = filter->shader_path.empty() ||
                           filter->shader_path.compare(shader_path_c) != 0;

        if (path_changed) {
            filter->shader_path = shader_path_c;
            filter->use_effect_file = use_effect;

            load_shader_from_file(filter, shader_path_c);
        }
    }

    bool hot_reload = obs_data_get_bool(settings, "hot_reload_enabled");
    if (hot_reload != filter->hot_reload_enabled) {
        filter->hot_reload_enabled = hot_reload;

        if (hot_reload && !filter->shader_path.empty()) {
            hot_reload::watch_file(filter->shader_path.c_str(), filter);
        } else if (!hot_reload && !filter->shader_path.empty()) {
            hot_reload::unwatch_file(filter->shader_path.c_str(), filter);
        }
    }

    filter->expand_left = (int)obs_data_get_int(settings, "expand_left");
    filter->expand_right = (int)obs_data_get_int(settings, "expand_right");
    filter->expand_top = (int)obs_data_get_int(settings, "expand_top");
    filter->expand_bottom = (int)obs_data_get_int(settings, "expand_bottom");
    filter->override_entire_effect = obs_data_get_bool(settings, "override_entire_effect");

    multi_input::update_sources(filter, settings);
}

static void filter_render(void *data, gs_effect_t *effect)
{
    UNUSED_PARAMETER(effect);

    filter_data *filter = static_cast<filter_data*>(data);

    if (!filter->effect) {
        obs_source_skip_video_filter(filter->context);
        return;
    }

    if (obs_source_process_filter_begin(filter->context, GS_RGBA, OBS_ALLOW_DIRECT_RENDERING)) {
        multi_input::bind_textures(filter, filter->effect);
        obs_source_process_filter_end(filter->context, filter->effect, 0, 0);
    }
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
}

void reload_shader(void *data)
{
    filter_data *filter = static_cast<filter_data*>(data);
    if (!filter->shader_path.empty()) {
        blog(LOG_INFO, "[ShaderFilter Plus Next] Hot-reloading shader: %s",
             filter->shader_path.c_str());
        load_shader_from_file(filter, filter->shader_path.c_str());
    }
}

} // namespace shader_filter