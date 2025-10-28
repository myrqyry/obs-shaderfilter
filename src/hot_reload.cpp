#include "hot_reload.hpp"
#include "shader_filter.hpp"
#include "shader_filter_data.hpp"
#include "logging.hpp"

#include <obs/obs-module.h>
#include <filesystem>
#include <thread>
#include <mutex>
#include <unordered_map>
#include <chrono>
#include <vector>
#include <string>
#include <algorithm>
#include <atomic>

namespace fs = std::filesystem;

namespace hot_reload {

namespace hot_reload_config {
    constexpr std::chrono::milliseconds POLLING_INTERVAL{500};
    constexpr std::chrono::seconds CALLBACK_TIMEOUT{2};
    constexpr size_t MAX_WATCHED_FILES = 100;
}

struct watch_entry {
    std::string path;
    fs::file_time_type last_write_time;
    std::vector<void*> filter_instances;
};

static std::thread watcher_thread;
static std::mutex watch_mutex;
static std::unordered_map<std::string, watch_entry> watched_files;
static std::atomic<bool> running = false;

static void watcher_loop()
{
    while (running) {
        std::this_thread::sleep_for(hot_reload_config::POLLING_INTERVAL);

        std::lock_guard<std::mutex> lock(watch_mutex);
        for (auto &entry : watched_files) {
            std::error_code ec;
            auto current_time =
                fs::last_write_time(entry.second.path, ec);

            if (ec) {
                // This can happen if the file is deleted or being written to.
                // We'll just retry next time.
                continue;
            }

            if (current_time > entry.second.last_write_time) {
                plugin_info("File changed: %s", entry.first.c_str());
                entry.second.last_write_time = current_time;

                // Instead of calling reload directly, just set a flag.
                // The render thread will pick this up safely.
                for (void *filter_ptr :
                     entry.second.filter_instances) {
                    auto *filter = static_cast<
                        shader_filter::filter_data *>(
                        filter_ptr);
                    if (filter && filter->context) {  // Validate filter is still alive
                        filter->needs_reload.store(true, std::memory_order_release);
                    }
                }
            }
        }
    }
}

void initialize()
{
    plugin_info("Initializing hot reload system");
    running = true;
    watcher_thread = std::thread(watcher_loop);
}

void shutdown()
{
    plugin_info("Shutting down hot reload system");
    running = false;
    if (watcher_thread.joinable()) {
        watcher_thread.join();
    }

    std::lock_guard<std::mutex> lock(watch_mutex);
    watched_files.clear();
}

void watch_file(const char *path, void *filter_instance)
{
    if (!path || !*path) {
        plugin_warn("Cannot watch empty file path");
        return;
    }

    // Check if file exists before trying to watch it
    if (!std::filesystem::exists(path)) {
        plugin_warn("File does not exist: %s", path);
        return;
    }

    std::lock_guard<std::mutex> lock(watch_mutex);
    std::string path_str(path);

    auto& entry = watched_files[path_str];

    if (entry.path.empty()) {
        entry.path = path_str;
        try {
            entry.last_write_time = fs::last_write_time(path_str);
        } catch (const fs::filesystem_error& e) {
            plugin_warn("Cannot get last write time for %s: %s", path, e.what());
            // Set to a known time to avoid constant reload attempts on error
            entry.last_write_time = fs::file_time_type::min();
        }
        plugin_info("Now watching: %s", path);
    }

    auto &instances = entry.filter_instances;
    if (std::find(instances.begin(), instances.end(), filter_instance) == instances.end()) {
        instances.push_back(filter_instance);
    }
}

void unwatch_file(const char *path, void *filter_instance)
{
    std::lock_guard<std::mutex> lock(watch_mutex);

    std::string path_str(path);

    auto it = watched_files.find(path_str);
    if (it != watched_files.end()) {
        auto &instances = it->second.filter_instances;
        instances.erase(
            std::remove(instances.begin(), instances.end(), filter_instance),
            instances.end()
        );

        if (instances.empty()) {
            watched_files.erase(it);
            plugin_info("Stopped watching: %s", path);
        }
    }
}

void add_properties(obs_properties_t *props, void *data)
{
    UNUSED_PARAMETER(data);

    obs_properties_t *hot_reload_group = obs_properties_create();
    obs_properties_add_group(props,
        "hot_reload",
        obs_module_text("HotReload"),
        OBS_GROUP_CHECKABLE,
        hot_reload_group);

    obs_property_t *enabled = obs_properties_add_bool(hot_reload_group,
        "hot_reload_enabled",
        obs_module_text("HotReloadEnabled"));
    obs_property_set_long_description(enabled,
        obs_module_text("HotReload.Description"));
}

} // namespace hot_reload