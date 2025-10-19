#pragma once
#include <obs/obs.h>
#include <obs/obs-properties.h>
#include <obs/obs-data.h>
#include <obs/graphics/gs_effect.h>

#ifndef USE_FFTW
// Minimal FFTW type stubs when FFTW is not available at compile time.
// These allow the code to compile; actual FFTW behavior will be disabled.
typedef void* fftwf_plan;
typedef float fftwf_complex[2];
#endif

namespace audio_reactive {

void add_properties(obs_properties_t *props, void *data);
void set_defaults(obs_data_t *settings);
void update_settings(void *filter_data, obs_data_t *settings);
void bind_audio_data(void *filter_data, gs_effect_t *effect);
// Safely free an audio_capture_data pointer from other translation units
void free_capture_data(void *capture);

} // namespace audio_reactive