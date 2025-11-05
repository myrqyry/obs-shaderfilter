#pragma once

#include <obs/obs-source.h>
#include <obs/graphics/gs_texrender.h>

namespace shader_filter { struct filter_data; }

namespace multi_input {

struct multi_input_data {
    obs_weak_source_t *secondary_source = nullptr;
    obs_weak_source_t *mask_source = nullptr;
    gs_texrender_t *secondary_texrender = nullptr;
    gs_texrender_t *mask_texrender = nullptr;
    uint32_t secondary_texrender_width = 0;
    uint32_t secondary_texrender_height = 0;
    uint32_t mask_texrender_width = 0;
    uint32_t mask_texrender_height = 0;
};

void update_sources(shader_filter::filter_data *filter, obs_data_t *settings);
void render_sources(shader_filter::filter_data *filter);
void bind_textures(shader_filter::filter_data *filter, gs_effect_t *effect);
void cleanup_textures(shader_filter::filter_data *filter);
void add_properties(obs_properties_t *props);
void set_defaults(obs_data_t *settings);

}