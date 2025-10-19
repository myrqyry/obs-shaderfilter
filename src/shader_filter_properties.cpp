#include "shader_filter.hpp"
#include <obs/obs-module.h>

// Forward declarations from other modules
namespace multi_input { void add_properties(obs_properties_t*, void*); }
namespace audio_reactive { void add_properties(obs_properties_t*, void*); }
namespace hot_reload { void add_properties(obs_properties_t*, void*); }

namespace shader_filter {

obs_properties_t* get_properties(void* data)
{
    obs_properties_t *props = obs_properties_create();

    // ===== SHADER FILE SELECTION =====
    obs_property_t *shader_file = obs_properties_add_path(props,
        "shader_file",
        obs_module_text("ShaderFile"),
        OBS_PATH_FILE,
        "Shader Files (*.effect *.shader);;Effect Files (*.effect);;Shader Files (*.shader);;All Files (*.*)",
        nullptr
    );
    obs_property_set_long_description(shader_file,
        obs_module_text("ShaderFile.Description"));

    obs_properties_add_bool(props,
        "use_effect_file",
        obs_module_text("UseEffectFile"));

    // ===== RENDERING OPTIONS GROUP =====
    obs_properties_t *render_group = obs_properties_create();
    obs_properties_add_group(props,
        "render_options",
        obs_module_text("RenderOptions"),
        OBS_GROUP_NORMAL,
        render_group);

    // Expand/Override Size options
    obs_properties_add_bool(render_group,
        "override_entire_effect",
        obs_module_text("OverrideEntireEffect"));

    obs_property_t *expand_left = obs_properties_add_int(render_group,
        "expand_left",
        obs_module_text("ExpandLeft"),
        0, 400, 1);
    obs_property_set_long_description(expand_left,
        obs_module_text("ExpandLeft.Description"));

    obs_properties_add_int(render_group,
        "expand_right",
        obs_module_text("ExpandRight"),
        0, 400, 1);

    obs_properties_add_int(render_group,
        "expand_top",
        obs_module_text("ExpandTop"),
        0, 400, 1);

    obs_properties_add_int(render_group,
        "expand_bottom",
        obs_module_text("ExpandBottom"),
        0, 400, 1);

    // ===== FEEDBACK SETTINGS GROUP =====
    obs_properties_t *feedback_group = obs_properties_create();
    obs_properties_add_group(props,
        "feedback_settings",
        obs_module_text("Feedback Settings"),
        OBS_GROUP_CHECKABLE,
        feedback_group);

    obs_properties_add_bool(feedback_group,
        "enable_feedback",
        obs_module_text("Enable Feedback"));
    obs_properties_add_float_slider(feedback_group,
        "trail_length",
        obs_module_text("Trail Length"),
        0.0, 0.99, 0.01);

    // ===== Subsystem Properties =====
    multi_input::add_properties(props, data);
    audio_reactive::add_properties(props, data);
    hot_reload::add_properties(props, data);

    // ===== SHADER PARAMETERS GROUP (Dynamically Populated) =====
    obs_properties_t *shader_params = obs_properties_create();
    obs_properties_add_group(props,
        "shader_parameters",
        obs_module_text("ShaderParameters"),
        OBS_GROUP_NORMAL,
        shader_params);

    return props;
}

} // namespace shader_filter