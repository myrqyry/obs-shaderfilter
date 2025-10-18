#include "multi_input.hpp"
#include "shader_filter.hpp"

#include <obs-module.h>

namespace multi_input {

void add_properties(obs_properties_t *props, void *data)
{
    UNUSED_PARAMETER(data);

    // Placeholder
}

void set_defaults(obs_data_t *settings)
{
    // Placeholder
}

void update_sources(void *filter_data, obs_data_t *settings)
{
    // Placeholder
}

} // namespace multi_input