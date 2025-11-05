#pragma once
#include <obs/obs-properties.h>
#include <atomic>

namespace shader_filter { struct filter_data; }

namespace hot_reload {

struct hot_reload_data {
    char *shader_path = nullptr;
    bool use_effect_file = false;
    bool hot_reload_enabled = false;
    char *last_error_string = nullptr;
    std::atomic<bool> needs_reload{false};
};

void initialize();
void shutdown();
void watch_file(shader_filter::filter_data *filter);
void unwatch_file(shader_filter::filter_data *filter);
void add_properties(obs_properties_t *props);

} // namespace hot_reload