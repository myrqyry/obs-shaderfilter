#pragma once

#include <obs/obs-module.h>

#define PLUGIN_LOG_PREFIX "[ShaderFilter Plus Next]"
#define plugin_info(format, ...) blog(LOG_INFO, PLUGIN_LOG_PREFIX " " format, ##__VA_ARGS__)
#define plugin_warn(format, ...) blog(LOG_WARNING, PLUGIN_LOG_PREFIX " " format, ##__VA_ARGS__)
#define plugin_error(format, ...) blog(LOG_ERROR, PLUGIN_LOG_PREFIX " " format, ##__VA_ARGS__)