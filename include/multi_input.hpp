#pragma once
#include <obs-properties.h>
#include <obs-data.h>
#include <obs/graphics/gs_effect.h>

namespace multi_input {

void add_properties(obs_properties_t *props, void *data);
void set_defaults(obs_data_t *settings);
void update_sources(void *filter_data, obs_data_t *settings);
void render_sources(void *filter_data);
void bind_textures(void *filter_data, gs_effect_t *effect);
void cleanup_textures(void *filter_data);

} // namespace multi_input