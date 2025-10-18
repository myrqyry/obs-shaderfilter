#include <obs-module.h>
#include <obs-source.h>
#include <graphics/graphics.h>
#include <util/platform.h>

#include "shader_filter.hpp"
#include "hot_reload.hpp"
#include "multi_input.hpp"
#include "audio_reactive.hpp"

OBS_DECLARE_MODULE()
OBS_MODULE_USE_DEFAULT_LOCALE("obs-shaderfilter-plus-next", "en-US")

MODULE_EXPORT const char *obs_module_description(void)
{
    return "Advanced shader filter with multi-input, audio reactivity, and hot reload";
}

bool obs_module_load(void)
{
    blog(LOG_INFO, "[ShaderFilter Plus Next] Version 1.0.0 loading...");

    // Register main shader filter
    shader_filter::register_filter();

    // Initialize subsystems
    hot_reload::initialize();

    blog(LOG_INFO, "[ShaderFilter Plus Next] Loaded successfully");
    return true;
}

void obs_module_unload(void)
{
    blog(LOG_INFO, "[ShaderFilter Plus Next] Unloading...");
    hot_reload::shutdown();
}