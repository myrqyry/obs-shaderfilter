#include "multi_input.hpp"
#include "shader_filter.hpp"

#include <obs-module.h>
#include <graphics/graphics.h>

namespace multi_input {

// Add secondary and mask source properties to the UI
void add_properties(obs_properties_t *props, void *data)
{
    UNUSED_PARAMETER(data);

    obs_properties_t *group = obs_properties_create();
    obs_properties_add_group(props,
        "multi_input",
        obs_module_text("MultiInput"),
        OBS_GROUP_CHECKABLE,
        group);

    // Secondary video source selector
    obs_property_t *secondary = obs_properties_add_list(group,
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

    // Mask source selector, similar
    obs_property_t *mask = obs_properties_add_list(group,
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

    obs_properties_add_text(group,
        "multi_input_info",
        obs_module_text("MultiInput.Description"),
        OBS_TEXT_INFO);
}

// Default to no extra source
void set_defaults(obs_data_t *settings)
{
    obs_data_set_default_string(settings, "secondary_source", "");
    obs_data_set_default_string(settings, "mask_source", "");
}

// Update stored source references on settings change
void update_sources(void *filter_data, obs_data_t *settings)
{
    shader_filter::filter_data *filter =
        static_cast<shader_filter::filter_data*>(filter_data);

    // Release existing weak references (if any)
    if (filter->secondary_source) {
        obs_weak_source_release(filter->secondary_source);
        filter->secondary_source = nullptr;
    }
    if (filter->mask_source) {
        obs_weak_source_release(filter->mask_source);
        filter->mask_source = nullptr;
    }

    // Set new secondary source
    const char *secondary_name = obs_data_get_string(settings, "secondary_source");
    if (secondary_name && *secondary_name) {
        obs_source_t *source = obs_get_source_by_name(secondary_name);
        if (source) {
            filter->secondary_source = obs_source_get_weak_source(source);
            obs_source_release(source);
        }
    }

    // Set new mask source
    const char *mask_name = obs_data_get_string(settings, "mask_source");
    if (mask_name && *mask_name) {
        obs_source_t *source = obs_get_source_by_name(mask_name);
        if (source) {
            filter->mask_source = obs_source_get_weak_source(source);
            obs_source_release(source);
        }
    }
}

// Helper to render a source to a texture (reusing or recreating target)
static bool render_source_to_texture(obs_source_t *source, gs_texrender_t **texrender)
{
    if (!source)
        return false;

    uint32_t width = obs_source_get_width(source);
    uint32_t height = obs_source_get_height(source);

    if (width == 0 || height == 0)
        return false;

    if (!*texrender) {
        *texrender = gs_texrender_create(GS_RGBA, GS_ZS_NONE);
    } else {
        gs_texture_t *tex = gs_texrender_get_texture(*texrender);
        // Check if resize needed
        uint32_t w = gs_texture_get_width(tex);
        uint32_t h = gs_texture_get_height(tex);
        if (w != width || h != height) {
            gs_texrender_destroy(*texrender);
            *texrender = gs_texrender_create(GS_RGBA, GS_ZS_NONE);
        }
    }

    if (!gs_texrender_begin(*texrender, width, height))
        return false;

    gs_ortho(0.0f, (float)width, 0.0f, (float)height, -100.0f, 100.0f);
    obs_source_video_render(source);
    gs_texrender_end(*texrender);

    return true;
}

// Bind the textures from secondary and mask sources to the shader
void bind_textures(void *filter_data, gs_effect_t *effect)
{
    shader_filter::filter_data *filter =
        static_cast<shader_filter::filter_data*>(filter_data);

    if (filter->secondary_source) {
        obs_source_t *source = obs_weak_source_get_source(filter->secondary_source);
        if (source) {
            if (render_source_to_texture(source, &filter->secondary_texrender)) {
                gs_texture_t *tex = gs_texrender_get_texture(filter->secondary_texrender);
                gs_eparam_t *param = gs_effect_get_param_by_name(effect, "secondary_image");
                if (param && tex)
                    gs_effect_set_texture(param, tex);
            }
            obs_source_release(source);
        }
    }

    if (filter->mask_source) {
        obs_source_t *source = obs_weak_source_get_source(filter->mask_source);
        if (source) {
            if (render_source_to_texture(source, &filter->mask_texrender)) {
                gs_texture_t *tex = gs_texrender_get_texture(filter->mask_texrender);
                gs_eparam_t *param = gs_effect_get_param_by_name(effect, "mask_image");
                if (param && tex)
                    gs_effect_set_texture(param, tex);
            }
            obs_source_release(source);
        }
    }
}

// Clean up any persistent render targets during plugin destruction
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