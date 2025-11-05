#pragma once

#include <obs/obs.h>
#include <obs/obs-source.h>

#include "multi_input.hpp"
#include "audio_reactive.hpp"
#include "hot_reload.hpp"
#include "shader_state.hpp"

namespace shader_filter {

struct filter_data {
    filter_data() = default;
    explicit filter_data(obs_source_t* ctx) :
        context(ctx)
    {}
    // Core filter data
    obs_source_t * const context = nullptr;

    // Shader state
    shader_state shader;

    // Multi-input data
    multi_input::multi_input_data multi_input;

    // Hot-reload data
    hot_reload::hot_reload_data hot_reload;

    // Audio-reactive data
    audio_reactive::audio_reactive_data audio;
};

} // namespace shader_filter