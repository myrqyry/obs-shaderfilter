// tests/test_hot_reload.cpp
#include "hot_reload.hpp"
#include "shader_filter_data.hpp" // Include the filter data definition
#include <thread>
#include <vector>
#include <atomic>
#include <filesystem>
#include <chrono>
#include <cstdio>
#include <cstring> // For strdup

namespace fs = std::filesystem;

int main() {
  using namespace std::chrono_literals;
  const char* path = "test_shader.glsl";
  // Ensure the file exists
  std::FILE* f = std::fopen(path, "w");
  if (f) { std::fputs("// initial\n", f); std::fclose(f); }

  hot_reload::initialize();

  constexpr int N = 32;
  // Create a vector of actual filter_data objects
  std::vector<shader_filter::filter_data> instances(N);
  for (int i = 0; i < N; ++i) {
    // Initialize with the minimal data needed for reload_shader.
    // The vector constructor already default-initialized the objects.
    instances[i].shader_path = strdup(path);
    hot_reload::watch_file(path, &instances[i]);
  }

  std::atomic<bool> stop{false};
  std::thread modifier([&]{
    while (!stop.load()) {
      // touch the file to change mtime
      auto now = std::chrono::file_clock::now();
      std::this_thread::sleep_for(50ms);
      std::error_code ec;
      fs::last_write_time(path, now, ec);
    }
  });

  std::thread unwatcher([&]{
    for (int round = 0; round < 100; ++round) {
      for (auto& inst : instances) {
        hot_reload::unwatch_file(path, &inst);
      }
      for (auto& inst : instances) {
        hot_reload::watch_file(path, &inst);
      }
    }
  });

  std::this_thread::sleep_for(10s);
  stop = true;
  modifier.join();
  unwatcher.join();

  // Shut down the hot reload system first to ensure the watcher thread is stopped.
  hot_reload::shutdown();

  // Now it is safe to clean up the filter data.
  for (auto& inst : instances) {
    // The hot reload shutdown clears the watch list, so unwatch is not strictly
    // necessary here, but it's good practice for clarity.
    hot_reload::unwatch_file(path, &inst);
    free(inst.shader_path); // Clean up the duplicated string
  }

  return 0;
}
