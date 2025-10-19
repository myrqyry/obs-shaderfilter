// Minimal stub for audio_reactive when FFTW or audio APIs are not available.
// Provides no-op implementations so the plugin can build.

#include "audio_reactive.hpp"
#include <obs/obs.h>

namespace audio_reactive {

void add_properties(obs_properties_t *props, void *data)
{
    UNUSED_PARAMETER(props);
    UNUSED_PARAMETER(data);
}

void set_defaults(obs_data_t *settings)
{
    UNUSED_PARAMETER(settings);
}

void update_settings(void *filter_data, obs_data_t *settings)
{
    UNUSED_PARAMETER(filter_data);
    UNUSED_PARAMETER(settings);
}

void bind_audio_data(void *filter_data, gs_effect_t *effect)
{
    UNUSED_PARAMETER(filter_data);
    UNUSED_PARAMETER(effect);
}

} // namespace audio_reactive
