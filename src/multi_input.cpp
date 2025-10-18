#include "multi_input.hpp"
#include "shader_filter.hpp"

#include <obs-module.h>
#include <obs-source.h>
#include <graphics/graphics.h>

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

    // obs_enum_sources is not available in this version of OBS
    // In a full implementation, we would need to find another way to enumerate sources.

    obs_property_t *mask = obs_properties_add_list(multi_input_group,
        "mask_source",
        obs_module_text("MaskSource"),
        OBS_COMBO_TYPE_LIST,
        OBS_COMBO_FORMAT_STRING);

    obs_property_list_add_string(mask, obs_module_text("None"), "");

    obs_properties_add_text(multi_input_group,
        "multi_input_info",
        obs_module_text("MultiInput.Description"),
        OBS_TEXT_INFO);
}

void set_defaults(obs_data_t *settings)
{
    obs_data_set_default_string(settings, "secondary_source", "");
    obs_data_set_default_string(settings, "mask_source", "");
}

void update_sources(void *filter_data, obs_data_t *settings)
{
    shader_filter::filter_data *filter =
        static_cast<shader_filter::filter_data*>(filter_data);

    const char *secondary_name = obs_data_get_string(settings, "secondary_source");

    if (filter->secondary_source) {
        obs_weak_source_release(filter->secondary_source);
        filter->secondary_source = nullptr;
    }

    if (secondary_name && *secondary_name) {
        obs_source_t *source = obs_get_source_by_name(secondary_name);
        if (source) {
            filter->secondary_source = obs_source_get_weak_source(source);
            obs_source_release(source);
        }
    }

    const char *mask_name = obs_data_get_string(settings, "mask_source");

    if (filter->mask_source) {
        obs_weak_source_release(filter->mask_source);
        filter->mask_source = nullptr;
    }

    if (mask_name && *mask_name) {
        obs_source_t *source = obs_get_source_by_name(mask_name);
        if (source) {
            filter->mask_source = obs_source_get_weak_source(source);
            obs_source_release(source);
        }
    }
}

void bind_textures(void *filter_data, gs_effect_t *effect)
{
    // This function will be implemented in a later step
}

void cleanup_textures(void *filter_data)
{
    // This function will be implemented in a later step
}

} // namespace multi_input