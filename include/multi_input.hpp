#pragma once
#include <obs-properties.h>

struct filter_data;

namespace multi_input {
    void add_properties(obs_properties_t *props, filter_data *data);
}