#include "multi_input.hpp"
#include "shader_filter.hpp"

#include <obs-module.h>
#include <obs-source.h>
#include <graphics/graphics.h>
#include <obs-enum-sources.h>

namespace multi_input {

void add_properties(obs_properties_t *props, void *data)
{
    UNUSED_PARAMETER(data);

    obs_properties_t *multi_input_group = obs_properties_create();
    obs_properties_add_group(props,
        "multi_input",
        obs_module_text("MultiInput"),
        OBS_GROUP_CHECKABLE,
        multi_input_group);

    obs_property_t *secondary = obs_properties_add_list(multi_input_group,
        "secondary_source",
        obs_module_text("SecondarySource"),
        OBS_COMBO_TYPE_LIST,
        OBS_COMBO_FORMAT_STRING);

    obs_property_list_add_string(secondary, obs_module_text("None"), "");

    obs_enum_sources([](void *param, obs_source_t *source) {
        obs_property_t *list = (obs_property_t*)param;
        uint32_t caps = obs_source_get_output_flags(source);
        if ((caps & OBS_SOURCE_VIDEO) != 0) {
            const char *name = obs_source_get_name(source);
            obs_property_list_add_string(list, name, name);
        }
        return true;
    }, secondary);

    obs_property_t *mask = obs_properties_add_list(multi_input_group,
        "mask_source",
        obs_module_text("MaskSource"),
        OBS_COMBO_TYPE_LIST,
        OBS_COMBO_FORMAT_STRING);

    obs_property_list_add_string(mask, obs_module_text("None"), "");

    obs_enum_sources([](void *param, obs_source_t *source) {
        obs_property_t *list = (obs_property_t*)param;
        uint32_t caps = obs_source_get_output_flags(source);
        if ((caps & OBS_SOURCE_VIDEO) != 0) {
            const char *name = obs_source_get_name(source);
            obs_property_list_add_string(list, name, name);
        }
        return true;
    }, mask);
}

void set_defaults(obs_data_t *settings)
{
    obs_data_set_default_string(settings, "secondary_source", "");
    obs_data_set_default_string(settings, "mask_source", "");
}

void update_sources(void *filter_data, obs_data_t *settings)
{
    shader_filter::filter_data *filter = static_cast<shader_filter::filter_data*>(filter_data);

    const char *secondary_name = obs_data_get_string(settings, "secondary_source");
    if (secondary_name && *secondary_name) {
        obs_source_t *source = obs_get_source_by_name(secondary_name);
        if (source) {
            obs_weak_source_t *weak = obs_source_get_weak_source(source);
            if (filter->secondary_source) {
                obs_weak_source_release(filter->secondary_source);
            }
            filter->secondary_source = weak;
            obs_source_release(source);
        }
    } else {
        if (filter->secondary_source) {
            obs_weak_source_release(filter->secondary_source);
            filter->secondary_source = nullptr;
        }
    }

    const char *mask_name = obs_data_get_string(settings, "mask_source");
    if (mask_name && *mask_name) {
        obs_source_t *source = obs_get_source_by_name(mask_name);
        if (source) {
            obs_weak_source_t *weak = obs_source_get_weak_source(source);
            if (filter->mask_source) {
                obs_weak_source_release(filter->mask_source);
            }
            filter->mask_source = weak;
            obs_source_release(source);
        }
    } else {
        if (filter->mask_source) {
            obs_weak_source_release(filter->mask_source);
            filter->mask_source = nullptr;
        }
    }
}

void bind_textures(void *filter_data, gs_effect_t *effect)
{
    shader_filter::filter_data *filter = static_cast<shader_filter::filter_data*>(filter_data);

    if (filter->secondary_source) {
        obs_source_t *source = obs_weak_source_get_source(filter->secondary_source);
        if (source) {
            gs_eparam_t *param = gs_effect_get_param_by_name(effect, "secondary_image");
            if (param) {
                gs_texture_t *tex = obs_source_get_texture(source);
                if (tex) {
                    gs_effect_set_texture(param, tex);
                }
            }
            obs_source_release(source);
        }
    }

    if (filter->mask_source) {
        obs_source_t *source = obs_weak_source_get_source(filter->mask_source);
        if (source) {
            gs_eparam_t *param = gs_effect_get_param_by_name(effect, "mask_image");
            if (param) {
                gs_texture_t *tex = obs_source_get_texture(source);
                if (tex) {
                    gs_effect_set_texture(param, tex);
                }
            }
            obs_source_release(source);
        }
    }
}

void cleanup_textures(void *filter_data)
{
    shader_filter::filter_data *filter =
        static_cast<shader_filter::filter_data*>(filter_data);

    obs_enter_graphics();

    if (filter->secondary_texrender) {
        gs_texrender_destroy(filter->secondary_texrender);
        filter->secondary_texrender = nullptr;
    }

    if (filter->mask_texrender) {
        gs_texrender_destroy(filter->mask_texrender);
        filter->mask_texrender = nullptr;
    }

    obs_leave_graphics();
}

} // namespace multi_input