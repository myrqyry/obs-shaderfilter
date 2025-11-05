#pragma once
#include <obs/obs.h>
#include <obs/obs-properties.h>
#include <obs/obs-data.h>
#include <obs/graphics/gs_effect.h>
#include <mutex>
#include <array>

#ifndef USE_FFTW
// Minimal FFTW type stubs when FFTW is not available at compile time.
typedef void* fftwf_plan;
typedef float fftwf_complex[2];
#endif

namespace shader_filter { struct filter_data; }

namespace audio_reactive {

struct audio_capture_data;

struct audio_reactive_data {
    obs_weak_source_t *audio_source;
    audio_capture_data *audio_capture;
    std::mutex spectrum_mutex;
    std::array<float, 256> front_buffer;
    std::array<float, 256> back_buffer;
    int spectrum_bands;
    float audio_reactivity_strength;
    bool audio_reactive_enabled;
    bool audio_textures_enabled;
    float audio_attack;
    float audio_release;
    float audio_gain;
    std::array<float, 256> smoothed_spectrum;

    static constexpr int HIGH_RES_SPECTRUM_SIZE = 1024;
    static constexpr int SPECTROGRAM_WIDTH = 512;
    static constexpr int SPECTROGRAM_HEIGHT = 256;
    static constexpr int WAVEFORM_SIZE = 1024;

    std::array<float, HIGH_RES_SPECTRUM_SIZE> high_res_spectrum;
    std::array<float, SPECTROGRAM_WIDTH * SPECTROGRAM_HEIGHT> spectrogram_data;
    std::array<float, WAVEFORM_SIZE> waveform_data;
    int spectrogram_write_pos = 0;

    gs_texture_t *audio_spectrum_tex;
    gs_texture_t *audio_spectrogram_tex;
    gs_texture_t *audio_waveform_tex;
};

void add_properties(obs_properties_t *props);
void set_defaults(obs_data_t *settings);
void update_settings(shader_filter::filter_data *filter, obs_data_t *settings);
void bind_audio_data(shader_filter::filter_data *filter, gs_effect_t *effect);
void free_capture_data(audio_capture_data *capture);

} // namespace audio_reactive