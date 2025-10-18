#pragma once
#include <obs.h>

namespace shader_filter {

// Main registration function
void register_filter();

// Callback for hot-reloading
void reload_shader(void *data);

// UI properties function (defined in shader_filter_properties.cpp)
obs_properties_t* get_properties(void* data);

struct filter_data {
    obs_source_t *context;
    gs_effect_t *effect;

    // Ping-pong render targets for feedback effects
    gs_texrender_t *render_target_a;
    gs_texrender_t *render_target_b;
    bool use_buffer_a;
    uint32_t target_width;
    uint32_t target_height;

    // Multi-input textures
    obs_weak_source_t *secondary_source;
    obs_weak_source_t *mask_source;
    gs_texrender_t *secondary_texrender;
    gs_texrender_t *mask_texrender;

    // Audio data
    float *audio_spectrum;
    int spectrum_bands;

    // Rendering options
    int expand_left;
    int expand_right;
    int expand_top;
    int expand_bottom;
    bool override_entire_effect;

    // Shader file path
    char *shader_path;
    bool use_effect_file;

    // Hot reload
    bool hot_reload_enabled;
};

} // namespace shader_filter