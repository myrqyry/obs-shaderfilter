#pragma once

#include <obs/graphics/gs_effect.h>
#include <obs/graphics/gs_texrender.h>

namespace shader_filter {

struct shader_state {
    gs_effect_t *effect = nullptr;
    gs_texrender_t *render_target_a = nullptr;
    gs_texrender_t *render_target_b = nullptr;
    bool use_buffer_a = true;
    uint32_t target_width = 0;
    uint32_t target_height = 0;
    int expand_left = 0;
    int expand_right = 0;
    int expand_top = 0;
    int expand_bottom = 0;
    bool override_entire_effect = false;
};

} // namespace shader_filter