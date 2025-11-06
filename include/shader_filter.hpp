// === File: include/shader_filter.hpp ===
#ifndef SHADER_FILTER_HPP
#define SHADER_FILTER_HPP

// System includes first (critical for avoiding namespace conflicts)
#include <string>
#include <vector>
#include <memory>
#include <filesystem>

// OBS includes second
#include <obs-module.h>
#include <graphics/graphics.h>

// Forward declarations to avoid circular dependencies
struct filter_data;
struct effect_data;

namespace shader_filter_plugin {  // Use more specific namespace name

// Core functionality
bool validate_shader_path(const char* path);
bool load_shader_from_file(filter_data* filter, const char* path);
bool reload_shader(filter_data* filter);

// Utility functions
std::string preprocess_shader_file(const char* path);
bool compile_shader_effect(filter_data* filter, const std::string& shader_text);

} // namespace shader_filter_plugin

void register_filter();

#endif // SHADER_FILTER_HPP