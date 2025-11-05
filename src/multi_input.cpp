#include "multi_input.hpp"
#include "shader_filter_data.hpp"
#include "logging.hpp"
#include "wrappers.hpp"

#include <obs/obs-module.h>
#include <obs/obs-source.h>
#include <obs/graphics/graphics.h>
#include <obs/obs-enum-sources.h>

#include <vector>
#include <string>
#include <chrono>

namespace multi_input {

static void populate_source_list(obs_property_t *list) {
    obs_property_list_add_string(list, obs_module_text("None"), "");

    // Cache source list with periodic refresh
    static std::vector<std::string> cached_sources;
    static std::chrono::steady_clock::time_point last_refresh;
    auto now = std::chrono::steady_clock::now();

    if (cached_sources.empty() ||
         now - last_refresh > std::chrono::seconds(2)) {

        cached_sources.clear();
        obs_enum_sources([](void *param, obs_source_t *source) {
            auto *sources = static_cast<std::vector<std::string>*>(param);
            uint32_t caps = obs_source_get_output_flags(source);
            if ((caps & OBS_SOURCE_VIDEO) != 0) {
                sources->emplace_back(obs_source_get_name(source));
            }
            return true;
        }, &cached_sources);

        last_refresh = now;
    }

    for (const auto& name : cached_sources) {
        obs_property_list_add_string(list, name.c_str(), name.c_str());
    }
}

void add_properties(obs_properties_t *props)
{
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

void update_sources(shader_filter::filter_data *filter, obs_data_t *settings)
{
    const char *secondary_name = obs_data_get_string(settings, "secondary_source");
    if (secondary_name && *secondary_name) {
        obs_source_t *source = obs_get_source_by_name(secondary_name);
        if (source) {
            obs_weak_source_t *weak = obs_source_get_weak_source(source);
            if (filter->multi_input.secondary_source) {
                obs_weak_source_release(filter->multi_input.secondary_source);
            }
            filter->multi_input.secondary_source = weak;
            obs_source_release(source);
        }
    } else {
        if (filter->multi_input.secondary_source) {
            obs_weak_source_release(filter->multi_input.secondary_source);
            filter->multi_input.secondary_source = nullptr;
        }
    }

    const char *mask_name = obs_data_get_string(settings, "mask_source");
    if (mask_name && *mask_name) {
        obs_source_t *source = obs_get_source_by_name(mask_name);
        if (source) {
            obs_weak_source_t *weak = obs_source_get_weak_source(source);
            if (filter->multi_input.mask_source) {
                obs_weak_source_release(filter->multi_input.mask_source);
            }
            filter->multi_input.mask_source = weak;
            obs_source_release(source);
        }
    } else {
        if (filter->multi_input.mask_source) {
            obs_weak_source_release(filter->multi_input.mask_source);
            filter->multi_input.mask_source = nullptr;
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
            texrender = nullptr;
        }

        texrender = gs_texrender_create(GS_RGBA, GS_ZS_NONE);
        if (!texrender) {
            plugin_error("Failed to create texrender %ux%u", width, height);
            obs_source_release(source);
            return;
        }

        tex_width = width;
        tex_height = height;
    }

    if (gs_texrender_begin(texrender, width, height)) {
        gs_ortho(0.0f, (float)width, 0.0f, (float)height, -100.0f, 100.0f);
        obs_source_video_render(source);
        gs_texrender_end(texrender);
    }

    obs_source_release(source);
}

void render_sources(shader_filter::filter_data *filter)
{
    if (filter->multi_input.secondary_source) {
        render_source(
            filter->multi_input.secondary_source,
            filter->multi_input.secondary_texrender,
            filter->multi_input.secondary_texrender_width,
            filter->multi_input.secondary_texrender_height);
    }

    if (filter->multi_input.mask_source) {
        render_source(
            filter->multi_input.mask_source,
            filter->multi_input.mask_texrender,
            filter->multi_input.mask_texrender_width,
            filter->multi_input.mask_texrender_height);
    }
}

void bind_textures(shader_filter::filter_data *filter, gs_effect_t *effect)
{
    if (!effect) return; // Add null check for effect

    if (filter->multi_input.secondary_texrender) {
        gs_eparam_t *param = gs_effect_get_param_by_name(effect, "secondary_image");
        if (param) {
            gs_texture_t *tex = gs_texrender_get_texture(filter->multi_input.secondary_texrender);
            if (tex) {
                gs_effect_set_texture(param, tex);
            }
        }
    }

    if (filter->multi_input.mask_texrender) {
        gs_eparam_t *param = gs_effect_get_param_by_name(effect, "mask_image");
        if (param) {
            gs_texture_t *tex = gs_texrender_get_texture(filter->multi_input.mask_texrender);
            if (tex) {
                gs_effect_set_texture(param, tex);
            }
        }
    }
}

void cleanup_textures(shader_filter::filter_data *filter)
{
    graphics_context_guard guard;

    if (filter->multi_input.secondary_texrender) {
        gs_texrender_destroy(filter->multi_input.secondary_texrender);
        filter->multi_input.secondary_texrender = nullptr;
    }

    if (filter->multi_input.mask_texrender) {
        gs_texrender_destroy(filter->multi_input.mask_texrender);
        filter->multi_input.mask_texrender = nullptr;
    }
}

} // namespace multi_input