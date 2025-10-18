#include "audio_reactive.hpp"
#include "shader_filter.hpp"

#include <obs-module.h>
#include <cmath>

namespace audio_reactive {

void add_properties(obs_properties_t *props, void *data)
{
    UNUSED_PARAMETER(data);

    // Placeholder
}

void set_defaults(obs_data_t *settings)
{
    // Placeholder
}

void update_settings(void *filter_data, obs_data_t *settings)
{
    // Placeholder
}

} // namespace audio_reactive