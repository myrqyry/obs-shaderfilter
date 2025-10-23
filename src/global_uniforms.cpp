#include "global_uniforms.hpp"
#include <obs/obs-module.h>
#include <vector>

namespace global_uniforms {

static std::vector<uniform> g_uniforms;

void add_uniform(const std::string& name, float value) {
    uniform u;
    u.name = name;
    u.value = value;
    g_uniforms.push_back(u);
}

void initialize() {
    add_uniform("global_mix", 0.5f);
}

void add_ui(obs_properties_t *props) {
    obs_properties_t *group = obs_properties_create();
    obs_properties_add_group(props, "global_uniforms", "Global Uniforms", OBS_GROUP_NORMAL, group);

    for (size_t i = 0; i < g_uniforms.size(); ++i) {
        obs_properties_add_float_slider(group, g_uniforms[i].name.c_str(), g_uniforms[i].name.c_str(), 0.0, 1.0, 0.01);
    }
}

void update_from_settings(obs_data_t *settings) {
    for (size_t i = 0; i < g_uniforms.size(); ++i) {
        g_uniforms[i].value = (float)obs_data_get_double(settings, g_uniforms[i].name.c_str());
    }
}

void bind_to_effect(gs_effect_t *effect) {
    for (size_t i = 0; i < g_uniforms.size(); ++i) {
        gs_eparam_t *param = gs_effect_get_param_by_name(effect, g_uniforms[i].name.c_str());
        if (param) {
            gs_effect_set_float(param, g_uniforms[i].value);
        }
    }
}

const std::vector<uniform>& get_uniforms() {
    return g_uniforms;
}

void add_uniform(const std::string& name, float value) {
    uniform u;
    u.name = name;
    u.value = value;
    g_uniforms.push_back(u);
}

} // namespace global_uniforms