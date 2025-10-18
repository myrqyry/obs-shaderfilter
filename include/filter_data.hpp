#pragma once
#include <obs-module.h>
#include <string>

struct filter_data {
    obs_source_t *source = nullptr;
    gs_effect_t *effect = nullptr;
    std::string current_shader_path;

    // Multi-input
    obs_source_t *secondary_input = nullptr;
    obs_source_t *mask_input = nullptr;
    float secondary_scale = 1.0f;
    float secondary_offset_x = 0.0f;
    float secondary_offset_y = 0.0f;

    // Ping-pong buffers
    gs_texrender_t *render_target_a = nullptr;
    gs_texrender_t *render_target_b = nullptr;
    bool use_buffer_a = true;

    // Texture for secondary source
    gs_texrender_t *secondary_texrender = nullptr;
};