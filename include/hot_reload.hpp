#pragma once
#include <obs/obs-properties.h>
#include <atomic>

namespace shader_filter { struct filter_data; }
namespace shader_filter_plugin { bool load_shader_from_file(shader_filter::filter_data *filter, const char *path); }

namespace hot_reload {

void initialize();
void shutdown();
void watch_file(shader_filter::filter_data *filter);
void unwatch_file(shader_filter::filter_data *filter);
void add_properties(obs_properties_t *props);
void perform_hot_reload(shader_filter::filter_data *filter);

} // namespace hot_reload
