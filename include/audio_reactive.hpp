#pragma once
#include <obs/obs-properties.h>
#include <obs/obs-data.h>
#include <obs/graphics/gs_effect.h>

namespace audio_reactive {

void add_properties(obs_properties_t *props, void *data);
void set_defaults(obs_data_t *settings);
void update_settings(void *filter_data, obs_data_t *settings);
void bind_audio_data(void *filter_data, gs_effect_t *effect);

} // namespace audio_reactive