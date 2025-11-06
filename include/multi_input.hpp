#pragma once

#include <obs/obs-source.h>
#include <obs/graphics/gs_texrender.h>

namespace shader_filter { struct filter_data; }

namespace multi_input {

void update_sources(shader_filter::filter_data *filter, obs_data_t *settings);
void render_sources(shader_filter::filter_data *filter);
void bind_textures(shader_filter::filter_data *filter, gs_effect_t *effect);
void cleanup_textures(shader_filter::filter_data *filter);
void add_properties(obs_properties_t *props);
void set_defaults(obs_data_t *settings);

}
