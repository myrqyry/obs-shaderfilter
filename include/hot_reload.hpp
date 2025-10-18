#pragma once
#include <obs/obs-properties.h>

namespace hot_reload {

void initialize();
void shutdown();
void watch_file(const char *path, void *filter_instance);
void unwatch_file(const char *path, void *filter_instance);
void add_properties(obs_properties_t *props, void *data);

} // namespace hot_reload