#pragma once

#include <obs/obs.h>
#include <string>
#include <vector>

namespace global_uniforms {

struct uniform {
    std::string name;
    float value;
};

void initialize();
void add_ui(obs_properties_t *props);
void update_from_settings(obs_data_t *settings);
void bind_to_effect(gs_effect_t *effect);
const std::vector<uniform>& get_uniforms();

} // namespace global_uniforms