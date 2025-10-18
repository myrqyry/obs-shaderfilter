#pragma once
#include <obs-module.h>

namespace shader_filter {
    struct filter_data; // Forward declaration of your main filter_data struct
}

namespace multi_input {

void add_properties(obs_properties_t *props, void *data);
void set_defaults(obs_data_t *settings);
void update_sources(void *filter_data, obs_data_t *settings);
void bind_textures(void *filter_data, gs_effect_t *effect);
void cleanup_textures(void *filter_data);

} // namespace multi_input