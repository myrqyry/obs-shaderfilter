#pragma once

#include <obs.h>
#include <obs-source.h>
#include <obs/graphics/gs_effect.h>
#include <obs/graphics/gs_texrender.h>

// Forward declarations for types used in the struct
class AudioCapture;

namespace shader_filter {

struct filter_data {
    // Core filter data
    obs_source_t *context;
    gs_effect_t *effect;
    gs_texrender_t *render_target_a;
    gs_texrender_t *render_target_b;
    bool use_buffer_a;
    uint32_t target_width;
    uint32_t target_height;

    // Expansion properties
    int expand_left;
    int expand_right;
    int expand_top;
    int expand_bottom;
    bool override_entire_effect;

    // Multi-input data
    obs_weak_source_t *secondary_source;
    obs_weak_source_t *mask_source;
    gs_texrender_t *secondary_texrender;
    gs_texrender_t *mask_texrender;
    uint32_t secondary_texrender_width;
    uint32_t secondary_texrender_height;
    uint32_t mask_texrender_width;
    uint32_t mask_texrender_height;

    // Hot-reload data
    char *shader_path;
    bool use_effect_file;
    bool hot_reload_enabled;

    // Audio-reactive data
    obs_weak_source_t *audio_source;
    AudioCapture *audio_capture;
    float *audio_spectrum;
    int spectrum_bands;
    bool audio_reactive_enabled;
};

} // namespace shader_filter