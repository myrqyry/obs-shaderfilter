#include <obs/obs-module.h>
#include <obs/obs-source.h>
#include <obs/graphics/graphics.h>
#include <obs/util/platform.h>
#include <obs/obs-frontend-api.h>


#include "shader_filter.hpp"
#include "hot_reload.hpp"
#include "multi_input.hpp"
#include "audio_reactive.hpp"
#include "global_uniforms.hpp"

using namespace shader_filter_plugin;

OBS_DECLARE_MODULE()
OBS_MODULE_USE_DEFAULT_LOCALE("obs-shaderfilter-plus-next", "en-US")

MODULE_EXPORT const char *obs_module_description(void)
{
    return "Advanced shader filter with multi-input, audio reactivity, and hot reload";
}

// Forward declaration for the refresh logic
static void refresh_all_filters();

// Frontend event callbacks (optional)
#if __has_include(<obs/obs-frontend-api.h>)
static void frontend_event_handler(enum obs_frontend_event event, void *private_data)
{
    if (event == OBS_FRONTEND_EVENT_FINISHED_LOADING) {
        refresh_all_filters();
    }
    UNUSED_PARAMETER(private_data);
}

static void register_frontend_callbacks()
{
    obs_frontend_add_event_callback((obs_frontend_event_cb)frontend_event_handler, nullptr);
}

static void unregister_frontend_callbacks()
{
    obs_frontend_remove_event_callback((obs_frontend_event_cb)frontend_event_handler, nullptr);
}
#else
static void register_frontend_callbacks() {}
static void unregister_frontend_callbacks() {}
#endif

bool obs_module_load(void)
{
    blog(LOG_INFO, "[ShaderFilter Plus Next] Version 1.0.0 loading...");

    // Register main shader filter
    register_filter();

    // Initialize subsystems
    hot_reload::initialize();
    global_uniforms::initialize();
    register_frontend_callbacks();

    blog(LOG_INFO, "[ShaderFilter Plus Next] Loaded successfully");
    return true;
}

void obs_module_unload(void)
{
    blog(LOG_INFO, "[ShaderFilter Plus Next] Unloading...");
    hot_reload::shutdown();
    unregister_frontend_callbacks();
}

static void refresh_all_filters()
{
    obs_enum_sources([](void* data, obs_source_t* source) {
        const char *id = obs_source_get_id(source);
        if (strcmp(id, "shader_filter_plus_next") == 0) {
            obs_source_update_properties(source);
        }
        UNUSED_PARAMETER(data);
        return true;
    }, nullptr);
}