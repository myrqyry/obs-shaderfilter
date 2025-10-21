#include "hot_reload.hpp"
#include "shader_filter.hpp"

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
        std::this_thread::sleep_for(std::chrono::milliseconds(1000));

        std::vector<std::pair<std::string, std::vector<void*>>> reload_list;

        {
            std::lock_guard<std::mutex> lock(watch_mutex);

            for (auto &entry : watched_files) {
                std::error_code ec;
                auto current_time = fs::last_write_time(entry.second.path, ec);

                if (ec) {
                    continue;
                }

                if (current_time != entry.second.last_write_time) {
                    entry.second.last_write_time = current_time;
                    reload_list.emplace_back(entry.second.path, entry.second.filter_instances);
                }
            }
        } // Release lock before calling reload callbacks

        // Process reloads outside of the lock to prevent deadlocks
        for (const auto& reload_item : reload_list) {
            blog(LOG_INFO, "[ShaderFilter Plus Next] File changed: %s", reload_item.first.c_str());

            for (void *filter : reload_item.second) {
                shader_filter::reload_shader(filter);
            }
        }
    }
}

void initialize()
{
    blog(LOG_INFO, "[ShaderFilter Plus Next] Initializing hot reload system");
    running = true;
    watcher_thread = std::thread(watcher_loop);
}

void shutdown()
{
    blog(LOG_INFO, "[ShaderFilter Plus Next] Shutting down hot reload system");
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
        blog(LOG_WARNING, "[ShaderFilter Plus Next] Cannot watch empty file path");
        return;
    }

    // Check if file exists before trying to watch it
    if (!std::filesystem::exists(path)) {
        blog(LOG_WARNING, "[ShaderFilter Plus Next] File does not exist: %s", path);
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
            blog(LOG_WARNING, "[ShaderFilter Plus Next] Cannot get last write time for %s: %s", path, e.what());
            // Set to a known time to avoid constant reload attempts on error
            entry.last_write_time = fs::file_time_type::min();
        }
        blog(LOG_INFO, "[ShaderFilter Plus Next] Now watching: %s", path);
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
            blog(LOG_INFO, "[ShaderFilter Plus Next] Stopped watching: %s", path);
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