#include <obs-module.h>
#include "shader_filter.hpp"
#include "hot_reload.hpp"
#include "multi_input.hpp"
#include "audio_reactive.hpp"

OBS_DECLARE_MODULE()
OBS_MODULE_USE_DEFAULT_LOCALE("obs-shaderfilter-plus-next", "en-US")

bool obs_module_load(void)
{
    shader_filter::register_filter();
    hot_reload::initialize();
    // These are placeholders for now
    // multi_input::register_filter();
    // audio_reactive::register_filter();
    return true;
}