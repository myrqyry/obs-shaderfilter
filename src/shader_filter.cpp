#include "shader_filter.hpp"
#include "filter_data.hpp"
#include <obs-frontend-api.h>
#include <obs-properties.h>
#include <obs-source.h>
#include <obs/util/platform.h>
#include <obs/graphics/vec2.h>

namespace shader_filter {

const char *FILTER_ID = "obs_shaderfilter_plus_next";

void update(void* data, obs_data_t* settings);

const char* get_name(void*) {
    return "Shader Filter Plus";
}

void* create(obs_data_t *settings, obs_source_t *source) {
    filter_data *filter = new filter_data();
    filter->source = source;
    update(filter, settings);
    return filter;
}

void destroy(void *data) {
    filter_data *filter = (filter_data*)data;
    if (filter->effect) gs_effect_destroy(filter->effect);
    delete filter;
}

obs_properties_t* get_properties(void* /*data*/) {
    obs_properties_t *props = obs_properties_create();
    obs_properties_add_path(props, "shader_file_path", "Shader File", OBS_PATH_FILE, "Effect files (*.effect)", nullptr);
    return props;
}

void update(void* data, obs_data_t* settings) {
    filter_data *filter = (filter_data*)data;

    const char *path = obs_data_get_string(settings, "shader_file_path");
    if (path && (filter->current_shader_path.empty() || filter->current_shader_path != path)) {
        if (filter->effect) gs_effect_destroy(filter->effect);
        char *effect_string = os_quick_read_utf8_file(path);
        filter->effect = gs_effect_create(effect_string, nullptr, nullptr);
        bfree(effect_string);
        filter->current_shader_path = path ? path : "";
    }
}

void render(void* data, gs_effect_t* /*effect*/) {
    filter_data *filter = (filter_data*)data;
    if (!filter || !filter->effect) {
        obs_source_skip_video_filter(filter->source);
        return;
    }

    if (obs_source_process_filter_begin(filter->source, GS_RGBA, OBS_ALLOW_DIRECT_RENDERING)) {
        obs_source_process_filter_end(filter->source, filter->effect, 0, 0);
    }
}

void register_filter() {
    obs_source_info si = {};
    si.id           = FILTER_ID;
    si.type         = OBS_SOURCE_TYPE_FILTER;
    si.output_flags = OBS_SOURCE_VIDEO;
    si.get_name     = get_name;
    si.create       = create;
    si.destroy      = destroy;
    si.get_properties = get_properties;
    si.update       = update;
    si.video_render = render;
    obs_register_source(&si);
}

} // namespace shader_filter