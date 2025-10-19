#pragma once

// Minimal shims to satisfy shader_filter_data.hpp without pulling real OBS headers
using uint32_t = unsigned int;
using obs_source_t = void;
using obs_weak_source_t = void;

// Minimal forward declarations used in headers
namespace gs { }
