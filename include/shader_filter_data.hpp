#pragma once

#include <obs/obs.h>
#include <obs/obs-source.h>
#include <obs/graphics/gs_effect.h>
#include <obs/graphics/gs_texrender.h>
#include <mutex>
#include <array>
#include <atomic>

// Forward declarations for types used in the struct
namespace audio_reactive { struct audio_capture_data; }

namespace shader_filter {

struct filter_data {
    filter_data() = default;
    explicit filter_data(obs_source_t* ctx) : context(ctx) {}
    // Core filter data
    obs_source_t * const context = nullptr;
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
    char *last_error_string;
    std::atomic<bool> needs_reload;

    // Audio-reactive data
    obs_weak_source_t *audio_source;
    audio_reactive::audio_capture_data *audio_capture;
    std::mutex spectrum_mutex;
    std::array<float, 256> front_buffer;
    std::array<float, 256> back_buffer;
    int spectrum_bands;
    float audio_reactivity_strength;
    bool audio_reactive_enabled;
    bool audio_textures_enabled;
    // Named to match audio_reactive.cpp usage
    float audio_attack;
    float audio_release;
    float audio_gain;

    // Temporally smoothed spectrum (same size as front/back buffers)
    std::array<float, 256> smoothed_spectrum;

    // --- New Audio Texture Data ---
    // CPU-side data buffers
    static constexpr int HIGH_RES_SPECTRUM_SIZE = 1024;
    static constexpr int SPECTROGRAM_WIDTH = 512;
    static constexpr int SPECTROGRAM_HEIGHT = 256;
    static constexpr int WAVEFORM_SIZE = 1024;

    std::array<float, HIGH_RES_SPECTRUM_SIZE> high_res_spectrum;
    std::array<float, SPECTROGRAM_WIDTH * SPECTROGRAM_HEIGHT> spectrogram_data;
    std::array<float, WAVEFORM_SIZE> waveform_data;
    int spectrogram_write_pos = 0;

    // GPU-side texture resources
    gs_texture_t *audio_spectrum_tex;
    gs_texture_t *audio_spectrogram_tex;
    gs_texture_t *audio_waveform_tex;
};

} // namespace shader_filter