#include "multi_input.hpp"
#include "shader_filter_data.hpp"

#include <obs/obs-module.h>
#include <obs/obs-source.h>
#include <graphics/graphics.h>
#include <obs-enum-sources.h>

namespace multi_input {

static void populate_source_list(obs_property_t *list)
{
	obs_property_list_add_string(list, obs_module_text("None"), "");
	obs_enum_sources(
		[](void *param, obs_source_t *source) {
			obs_property_t *list = (obs_property_t *)param;
			uint32_t caps = obs_source_get_output_flags(source);
			if ((caps & OBS_SOURCE_VIDEO) != 0) {
				const char *name = obs_source_get_name(source);
				obs_property_list_add_string(list, name, name);
			}
			return true;
		},
		list);
}

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
	populate_source_list(secondary);

    obs_property_t *mask = obs_properties_add_list(multi_input_group,
        "mask_source",
        obs_module_text("MaskSource"),
        OBS_COMBO_TYPE_LIST,
        OBS_COMBO_FORMAT_STRING);
	populate_source_list(mask);
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

static void render_source(
    obs_weak_source_t *weak_source,
    gs_texrender_t *&texrender,
    uint32_t &tex_width,
    uint32_t &tex_height)
{
    obs_source_t *source = obs_weak_source_get_source(weak_source);
    if (!source) {
        return;
    }

    uint32_t width = obs_source_get_base_width(source);
    uint32_t height = obs_source_get_base_height(source);

    if (width == 0 || height == 0) {
        obs_source_release(source);
        return;
    }

    if (!texrender || width != tex_width || height != tex_height) {
        if (texrender) {
            gs_texrender_destroy(texrender);
        }
        texrender = gs_texrender_create(GS_RGBA, GS_ZS_NONE);
        tex_width = width;
        tex_height = height;
        blog(LOG_INFO, "[shader-filter-plus] Resized multi-input texture to %ux%u", width, height);
    }

    if (gs_texrender_begin(texrender, width, height)) {
        gs_ortho(0.0f, (float)width, 0.0f, (float)height, -100.0f, 100.0f);
        obs_source_video_render(source);
        gs_texrender_end(texrender);
    }

    obs_source_release(source);
}

void render_sources(void *filter_data)
{
    shader_filter::filter_data *filter = static_cast<shader_filter::filter_data*>(filter_data);

    if (filter->secondary_source) {
        render_source(
            filter->secondary_source,
            filter->secondary_texrender,
            filter->secondary_texrender_width,
            filter->secondary_texrender_height);
    }

    if (filter->mask_source) {
        render_source(
            filter->mask_source,
            filter->mask_texrender,
            filter->mask_texrender_width,
            filter->mask_texrender_height);
    }
}

void bind_textures(void *filter_data, gs_effect_t *effect)
{
    shader_filter::filter_data *filter = static_cast<shader_filter::filter_data*>(filter_data);

    if (filter->secondary_texrender) {
        gs_eparam_t *param = gs_effect_get_param_by_name(effect, "secondary_image");
        if (param) {
            gs_texture_t *tex = gs_texrender_get_texture(filter->secondary_texrender);
            if (tex) {
                gs_effect_set_texture(param, tex);
            }
        }
    }

    if (filter->mask_texrender) {
        gs_eparam_t *param = gs_effect_get_param_by_name(effect, "mask_image");
        if (param) {
            gs_texture_t *tex = gs_texrender_get_texture(filter->mask_texrender);
            if (tex) {
                gs_effect_set_texture(param, tex);
            }
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
    }

    if (filter->mask_texrender) {
        gs_texrender_destroy(filter->mask_texrender);
    }

    obs_leave_graphics();
}

} // namespace multi_input