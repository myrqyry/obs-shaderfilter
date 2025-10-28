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
    explicit filter_data(obs_source_t* ctx) :
        context(ctx),
        effect(nullptr),
        render_target_a(nullptr),
        render_target_b(nullptr),
        use_buffer_a(true),
        target_width(0),
        target_height(0),
        expand_left(0),
        expand_right(0),
        expand_top(0),
        expand_bottom(0),
        override_entire_effect(false),
        secondary_source(nullptr),
        mask_source(nullptr),
        secondary_texrender(nullptr),
        mask_texrender(nullptr),
        secondary_texrender_width(0),
        secondary_texrender_height(0),
        mask_texrender_width(0),
        mask_texrender_height(0),
        shader_path(nullptr),
        use_effect_file(false),
        hot_reload_enabled(false),
        last_error_string(nullptr),
        needs_reload(false),
        audio_source(nullptr),
        audio_capture(nullptr),
        spectrum_bands(0),
        audio_reactivity_strength(0.0f),
        audio_reactive_enabled(false),
        audio_textures_enabled(false),
        audio_attack(0.0f),
        audio_release(0.0f),
        audio_gain(0.0f),
        audio_spectrum_tex(nullptr),
        audio_spectrogram_tex(nullptr),
        audio_waveform_tex(nullptr)
    {}
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