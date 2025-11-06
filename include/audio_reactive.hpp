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

void add_properties(obs_properties_t *props);
void set_defaults(obs_data_t *settings);
void update_settings(shader_filter::filter_data *filter, obs_data_t *settings);
void bind_audio_data(shader_filter::filter_data *filter, gs_effect_t *effect);
void free_capture_data(audio_capture_data *capture);

} // namespace audio_reactive
