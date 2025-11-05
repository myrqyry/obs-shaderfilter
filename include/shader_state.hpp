#pragma once

#include <obs/graphics/gs_effect.h>
#include <obs/graphics/gs_texrender.h>

namespace shader_filter {

struct shader_state {
    gs_effect_t *effect;
    gs_texrender_t *render_target_a;
    gs_texrender_t *render_target_b;
    bool use_buffer_a;
    uint32_t target_width;
    uint32_t target_height;
    int expand_left;
    int expand_right;
    int expand_top;
    int expand_bottom;
    bool override_entire_effect;
};

} // namespace shader_filter