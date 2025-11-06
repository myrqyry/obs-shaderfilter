#pragma once

#include <obs/obs.h>
#include <obs/obs-source.h>
#include <obs/graphics/gs_effect.h>
#include <obs/graphics/gs_texrender.h>
#include <mutex>
#include <array>
#include <string>
#include <chrono>
#include <atomic>

#ifndef USE_FFTW
// Minimal FFTW type stubs when FFTW is not available at compile time.
typedef void* fftwf_plan;
typedef float fftwf_complex[2];
#endif

// Forward declarations
struct audio_capture_data;

namespace shader_filter {

struct filter_data {
    // Core filter data
    obs_source_t *context = nullptr;
    gs_effect_t *effect = nullptr;
    gs_texrender_t *render_target_a = nullptr;
    gs_texrender_t *render_target_b = nullptr;
    bool use_buffer_a = true;
    uint32_t target_width = 0;
    uint32_t target_height = 0;

    // Shader loading and management
    char *shader_path = nullptr;
    bool use_effect_file = false;
    bool hot_reload_enabled = false;
    std::chrono::steady_clock::time_point last_reload_check;
    char *last_error_string = nullptr;
    std::atomic<bool> needs_reload{false};

    // Expansion properties
    int expand_left = 0;
    int expand_right = 0;
    int expand_top = 0;
    int expand_bottom = 0;
    bool override_entire_effect = false;

    // Multi-input data
    obs_weak_source_t *secondary_source = nullptr;
    obs_weak_source_t *mask_source = nullptr;
    gs_texrender_t *secondary_texrender = nullptr;
    gs_texrender_t *mask_texrender = nullptr;
    uint32_t secondary_texrender_width = 0;
    uint32_t secondary_texrender_height = 0;
    uint32_t mask_texrender_width = 0;
    uint32_t mask_texrender_height = 0;

    // Audio-reactive data
    obs_weak_source_t *audio_source = nullptr;
    audio_capture_data *audio_capture = nullptr;
    std::mutex spectrum_mutex;
    std::array<float, 256> front_buffer;
    std::array<float, 256> back_buffer;
    int spectrum_bands = 0;
    float audio_reactivity_strength = 0.0f;
    bool audio_reactive_enabled = false;
    bool audio_textures_enabled = false;
    float audio_attack = 0.0f;
    float audio_release = 0.0f;
    float audio_gain = 0.0f;
    std::array<float, 256> smoothed_spectrum;

    static constexpr int HIGH_RES_SPECTRUM_SIZE = 1024;
    static constexpr int SPECTROGRAM_WIDTH = 512;
    static constexpr int SPECTROGRAM_HEIGHT = 256;
    static constexpr int WAVEFORM_SIZE = 1024;

    std::array<float, HIGH_RES_SPECTRUM_SIZE> high_res_spectrum;
    std::array<float, SPECTROGRAM_WIDTH * SPECTROGRAM_HEIGHT> spectrogram_data;
    std::array<float, WAVEFORM_SIZE> waveform_data;
    int spectrogram_write_pos = 0;

    gs_texture_t *audio_spectrum_tex = nullptr;
    gs_texture_t *audio_spectrogram_tex = nullptr;
    gs_texture_t *audio_waveform_tex = nullptr;

    // Performance tracking
    uint64_t render_count = 0;
    double last_frame_time = 0.0;

    // Error handling
    std::string last_error;
    int error_count = 0;
};

} // namespace shader_filter
