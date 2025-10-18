#pragma once
#include <obs/obs.h>

namespace shader_filter {

// Main registration function
void register_filter();

// Callback for hot-reloading
void reload_shader(void *data);

// UI properties function (defined in shader_filter_properties.cpp)
obs_properties_t* get_properties(void* data);

} // namespace shader_filter