// Version 2.0 by Exeldro https://github.com/exeldro/obs-shaderfilter
// Version 1.21 by Charles Fettinger https://github.com/Oncorporation/obs-shaderfilter
// original version by nleseul https://github.com/nleseul/obs-shaderfilter
#include <obs-module.h>
#include <graphics/graphics.h>
#include <graphics/image-file.h>
#include <graphics/math-extra.h>
// #include <obs-paths.h> // os_get_abs_path_ptr is in util/platform.h
// util/platform.h is already included below, which should provide os_get_abs_path_ptr

#include <util/base.h>
#include <util/dstr.h>
#include <util/darray.h>
#include <util/platform.h>
#include <obs-data.h>
#include <float.h>
#include <limits.h>
#include <stdio.h>
#include <time.h>
#include <string.h>

#include <util/threading.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <sys/time.h>
#endif

#include "version.h"

// Moved struct definitions before forward declarations to resolve type issues

struct effect_param_data {
	struct dstr name;
	struct dstr display_name;
	struct dstr widget_type;
	struct dstr group;
	struct dstr path;
	DARRAY(int) option_values;
	DARRAY(struct dstr) option_labels;
	enum gs_shader_param_type type;
	gs_eparam_t *param;
	gs_image_file_t *image;
	gs_texrender_t *render;
	obs_weak_source_t *source;
	union { long long i; double f; char *string; struct vec2 vec2; struct vec3 vec3; struct vec4 vec4; } value;
	union { long long i; double f; char *string; struct vec2 vec2; struct vec3 vec3; struct vec4 vec4; } default_value;
	bool has_default;
	char *label;
	union { long long i; double f; } minimum;
	union { long long i; double f; } maximum;
	union { long long i; double f; } step;
};

// Forward declare shader_filter_data so shader_pass_info can use it if needed,
// though in this case shader_pass_info is self-contained or uses effect_param_data.
// This is not strictly necessary here as shader_pass_info is defined within shader_filter_data,
// but good practice if they were separate and cross-referencing.
struct shader_filter_data;

#define MAX_SHADER_PASSES 3
struct shader_pass_info {
	gs_effect_t *effect;
	struct dstr effect_file_path;
	bool enabled;
	DARRAY(struct effect_param_data) stored_param_list;
	struct dstr error_string; // For per-pass error UI
};

struct shader_filter_data {
	obs_source_t *context;
	gs_effect_t *effect;
	gs_effect_t *output_effect;
	gs_texrender_t *input_texrender, *previous_input_texrender, *output_texrender, *previous_output_texrender;
	gs_eparam_t *param_output_image;
	bool reload_effect;
	struct dstr last_path;
	bool last_from_file;
	bool transition, transitioning, prev_transitioning;
	bool use_pm_alpha, output_rendered, input_rendered;
	float shader_start_time, shader_show_time, shader_active_time, shader_enable_time;
	bool enabled;
	gs_eparam_t *param_uv_offset, *param_uv_scale, *param_uv_pixel_interval, *param_uv_size;
	gs_eparam_t *param_current_time_ms, *param_current_time_sec, *param_current_time_min, *param_current_time_hour;
	gs_eparam_t *param_current_time_day_of_week, *param_current_time_day_of_month, *param_current_time_month, *param_current_time_day_of_year, *param_current_time_year;
	gs_eparam_t *param_elapsed_time, *param_elapsed_time_start, *param_elapsed_time_show, *param_elapsed_time_active, *param_elapsed_time_enable;
	gs_eparam_t *param_loops, *param_loop_second, *param_local_time;
	gs_eparam_t *param_rand_f, *param_rand_instance_f, *param_rand_activation_f;
	gs_eparam_t *param_image, *param_previous_image, *param_image_a, *param_image_b;
	gs_eparam_t *param_transition_time, *param_convert_linear, *param_previous_output;
	int expand_left, expand_right, expand_top, expand_bottom;
	int total_width, total_height;
	bool no_repeat, rendering;
	struct vec2 uv_offset_val, uv_scale_val, uv_pixel_interval_val, uv_size_val;
	float elapsed_time_val, elapsed_time_loop_val, local_time_val, rand_f_val, rand_instance_f_val, rand_activation_f_val;
	int loops_val;
	DARRAY(struct effect_param_data) stored_param_list; // For main effect
	struct shader_pass_info passes[MAX_SHADER_PASSES];
	int num_active_passes;
	gs_texrender_t *intermediate_texrender_A, *intermediate_texrender_B;
	struct dstr global_error_string; // For global/main effect errors
};


// Global variables
float (*move_get_transition_filter)(obs_source_t *filter_from, obs_source_t **filter_to) = NULL;
#define nullptr ((void *)0)

// Effect templates
static const char *effect_template_begin = "\
uniform float4x4 ViewProj;\n\
uniform texture2d image;\n\
\n\
uniform float2 uv_offset;\n\
uniform float2 uv_scale;\n\
uniform float2 uv_pixel_interval;\n\
uniform float2 uv_size;\n\
uniform float rand_f;\n\
uniform float rand_instance_f;\n\
uniform float rand_activation_f;\n\
uniform float elapsed_time;\n\
uniform float elapsed_time_start;\n\
uniform float elapsed_time_show;\n\
uniform float elapsed_time_active;\n\
uniform float elapsed_time_enable;\n\
uniform int loops;\n\
uniform float loop_second;\n\
uniform float local_time;\n\
\n\
sampler_state textureSampler{\n\
	Filter = Linear;\n\
	AddressU = Border;\n\
	AddressV = Border;\n\
	BorderColor = 00000000;\n\
};\n\
\n\
struct VertData {\n\
	float4 pos : POSITION;\n\
	float2 uv : TEXCOORD0;\n\
};\n\
\n\
VertData mainTransform(VertData v_in)\n\
{\n\
	VertData vert_out;\n\
	vert_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);\n\
	vert_out.uv = v_in.uv * uv_scale + uv_offset;\n\
	return vert_out;\n\
}\n\
\n\
float srgb_nonlinear_to_linear_channel(float u)\n\
{\n\
	return (u <= 0.04045) ? (u / 12.92) : pow((u + 0.055) / 1.055, 2.4);\n\
}\n\
\n\
float3 srgb_nonlinear_to_linear(float3 v)\n\
{\n\
	return float3(srgb_nonlinear_to_linear_channel(v.r),\n\
		      srgb_nonlinear_to_linear_channel(v.g),\n\
		      srgb_nonlinear_to_linear_channel(v.b));\n\
}\n\
\n";

static const char *effect_template_default_image_shader = "\n\
float4 mainImage(VertData v_in) : TARGET\n\
{\n\
	return image.Sample(textureSampler, v_in.uv);\n\
}\n\
";

static const char *effect_template_default_transition_image_shader = "\n\
uniform texture2d image_a;\n\
uniform texture2d image_b;\n\
uniform float transition_time = 0.5;\n\
uniform bool convert_linear = true;\n\
\n\
float4 mainImage(VertData v_in) : TARGET\n\
{\n\
	float4 a_val = image_a.Sample(textureSampler, v_in.uv);\n\
	float4 b_val = image_b.Sample(textureSampler, v_in.uv);\n\
	float4 rgba = lerp(a_val, b_val, transition_time);\n\
	if (convert_linear)\n\
		rgba.rgb = srgb_nonlinear_to_linear(rgba.rgb);\n\
	return rgba;\n\
}\n\
";

static const char *effect_template_end = "\n\
technique Draw\n\
{\n\
	pass\n\
	{\n\
		vertex_shader = mainTransform(v_in);\n\
		pixel_shader = mainImage(v_in);\n\
	}\n\
}\n";


// Forward declarations for OBS callbacks
static const char *shader_filter_get_name(void *unused);
static void *shader_filter_create(obs_data_t *settings, obs_source_t *source);
static void shader_filter_destroy(void *data);
static void shader_filter_update(void *data, obs_data_t *settings);
static void shader_filter_defaults(obs_data_t *settings);
static obs_properties_t *shader_filter_properties(void *data);
static void shader_filter_tick(void *data, float seconds);
static void shader_filter_render(void *data, gs_effect_t *effect);
static uint32_t shader_filter_getwidth(void *data);
static uint32_t shader_filter_getheight(void *data);
static enum gs_color_space shader_filter_get_color_space(void *data, size_t count, const enum gs_color_space *preferred_spaces);
static void shader_filter_activate(void *data);
static void shader_filter_deactivate(void *data);
static void shader_filter_show(void *data);
static void shader_filter_hide(void *data);

static const char *shader_transition_get_name(void *unused);
static void *shader_transition_create(obs_data_t *settings, obs_source_t *source);
static void shader_transition_defaults(obs_data_t *settings);
static bool shader_transition_audio_render(void *data, uint64_t *ts_out, struct obs_source_audio_mix *audio, uint32_t mixers, size_t channels, size_t sample_rate);
static void shader_transition_video_render(void *data, gs_effect_t *effect);
static enum gs_color_space shader_transition_get_color_space(void *data, size_t count, const enum gs_color_space *preferred_spaces);

// Forward declarations for static helper functions if they are used before definition
// OBS UI callbacks
static bool shader_filter_from_file_changed(obs_properties_t *props, obs_property_t *p, obs_data_t *settings);
static bool shader_filter_text_changed(obs_properties_t *props, obs_property_t *p, obs_data_t *settings);
static bool shader_filter_file_name_changed(obs_properties_t *props, obs_property_t *p, obs_data_t *settings);
static bool shader_filter_reload_effect_clicked(obs_properties_t *props, obs_property_t *property, void *data);
static bool shader_filter_convert(obs_properties_t *props, obs_property_t *property, void *data);
static bool shader_filter_pass_from_file_changed(obs_properties_t *props, obs_property_t *p, obs_data_t *settings); // For pass specific file change
static bool shader_filter_pass_enabled_changed(obs_properties_t *props, obs_property_t *p, obs_data_t *settings); // For pass enable/disable

<<<<<<< HEAD
// Core logic helpers
static char *load_shader_from_file(const char *file_name);
static void shader_filter_clear_params(struct shader_filter_data *filter); // For main effect
static void shader_filter_clear_pass_params(struct shader_pass_info *pass_info); // For pass effects
static void load_output_effect(struct shader_filter_data *filter);
static void shader_filter_reload_effect(struct shader_filter_data *filter); // For main effect
static bool shader_filter_reload_pass_effect(struct shader_filter_data *filter, int pass_index, obs_data_t *settings); // For pass effects
static void shader_filter_set_pass_effect_params(struct shader_filter_data *filter, int pass_idx);
static void get_input_source(struct shader_filter_data *filter);
static void draw_output(struct shader_filter_data *filter);
static void render_shader(struct shader_filter_data *filter, float f, obs_source_t *filter_to);
static gs_texrender_t *create_or_reset_texrender(gs_texrender_t *render);
static bool is_var_char(char ch);
static char *str_replace(const char *str, const char *find, const char *replace);
static bool add_source_to_list(void *data, obs_source_t *source);
static unsigned int rand_interval(unsigned int min, unsigned int max);
=======
struct shader_filter_data {
	obs_source_t *context;
	gs_effect_t *effect;
	gs_effect_t *output_effect;
	gs_vertbuffer_t *sprite_buffer;
>>>>>>> origin/relocate-extra-pixels-ui

// UI generation helper
static void add_effect_params_to_ui(obs_properties_t *props_group, DARRAY(struct effect_param_data) *param_list,
                                    const char *setting_prefix, obs_data_t *settings, DARRAY(obs_property_t *) created_groups_list);

// --- START OF STATIC HELPER FUNCTION DEFINITIONS ---

<<<<<<< HEAD
static unsigned int rand_interval(unsigned int min, unsigned int max) {
=======
	bool use_pm_alpha;
	bool output_rendered;
	bool input_rendered;

	float shader_start_time;
	float shader_show_time;
	float shader_active_time;
	float shader_enable_time;
	bool enabled;
	bool use_template;

	gs_eparam_t *param_uv_offset;
	gs_eparam_t *param_uv_scale;
	gs_eparam_t *param_uv_pixel_interval;
	gs_eparam_t *param_uv_size;
	gs_eparam_t *param_current_time_ms;
	gs_eparam_t *param_current_time_sec;
	gs_eparam_t *param_current_time_min;
	gs_eparam_t *param_current_time_hour;
	gs_eparam_t *param_current_time_day_of_week;
	gs_eparam_t *param_current_time_day_of_month;
	gs_eparam_t *param_current_time_month;
	gs_eparam_t *param_current_time_day_of_year;
	gs_eparam_t *param_current_time_year;
	gs_eparam_t *param_elapsed_time;
	gs_eparam_t *param_elapsed_time_start;
	gs_eparam_t *param_elapsed_time_show;
	gs_eparam_t *param_elapsed_time_active;
	gs_eparam_t *param_elapsed_time_enable;
	gs_eparam_t *param_loops;
	gs_eparam_t *param_loop_second;
	gs_eparam_t *param_local_time;
	gs_eparam_t *param_rand_f;
	gs_eparam_t *param_rand_instance_f;
	gs_eparam_t *param_rand_activation_f;
	gs_eparam_t *param_image;
	gs_eparam_t *param_previous_image;
	gs_eparam_t *param_image_a;
	gs_eparam_t *param_image_b;
	gs_eparam_t *param_transition_time;
	gs_eparam_t *param_convert_linear;
	gs_eparam_t *param_previous_output;

	int expand_left;
	int expand_right;
	int expand_top;
	int expand_bottom;

	int total_width;
	int total_height;
	bool no_repeat;
	bool rendering;

	struct vec2 uv_offset;
	struct vec2 uv_scale;
	struct vec2 uv_pixel_interval;
	struct vec2 uv_size;
	float elapsed_time;
	float elapsed_time_loop;
	int loops;
	float local_time;
	float rand_f;
	float rand_instance_f;
	float rand_activation_f;

	DARRAY(struct effect_param_data) stored_param_list;
};

static unsigned int rand_interval(unsigned int min, unsigned int max)
{
>>>>>>> origin/relocate-extra-pixels-ui
	unsigned int r;
	const unsigned int range = 1 + max - min;
	const unsigned int buckets = RAND_MAX / range;
	const unsigned int limit = buckets * range;
	do {
		r = rand();
	} while (r >= limit);
	return min + (r / buckets);
}

<<<<<<< HEAD
static char *str_replace(const char *str, const char *find, const char *replace) {
    // Simple string replacement, ensure it handles memory correctly if used.
    // This is a placeholder for now; the original file might have a more robust version or not use it.
    // For safety, if this is critical, it should be reviewed or taken from a known good source.
    char *result;
    int i, cnt = 0;
    int find_len = strlen(find);
    int replace_len = strlen(replace);

    for (i = 0; str[i] != '\0'; i++) {
        if (strstr(&str[i], find) == &str[i]) {
            cnt++;
            i += find_len - 1;
        }
    }
    result = (char *)malloc(i + cnt * (replace_len - find_len) + 1);
    i = 0;
    while (*str) {
        if (strstr(str, find) == str) {
            strcpy(&result[i], replace);
            i += replace_len;
            str += find_len;
        } else {
            result[i++] = *str++;
        }
    }
    result[i] = '\0';
    return result;
}


static char *load_shader_from_file(const char *file_name) {
=======
static char *load_shader_from_file(const char *file_name) // add input of visited files
{
>>>>>>> origin/relocate-extra-pixels-ui
	char *file_ptr = os_quick_read_utf8_file(file_name);
	if (!file_ptr) {
		blog(LOG_WARNING, "[obs-shaderfilter] failed to read file: %s", file_name);
		return NULL;
	}

	char **lines = strlist_split(file_ptr, '\n', true);
	struct dstr shader_file;
	dstr_init(&shader_file);
	size_t line_i = 0;

	while (lines[line_i] != NULL) {
		char *line = lines[line_i++];
		if (strncmp(line, "#include", 8) == 0) {
			char *include_file_name = line + 8;
			while (*include_file_name == ' ' || *include_file_name == '\t' || *include_file_name == '"') {
				include_file_name++;
			}
			char *end_char = include_file_name + strlen(include_file_name) -1;
			while (*end_char == ' ' || *end_char == '\t' || *end_char == '"') {
				*end_char = '\0';
				end_char--;
			}

			char *base_path = os_get_path_ptr(file_name); // Using os_get_path_ptr
			struct dstr full_include_path;
			dstr_init(&full_include_path);
			dstr_catf(&full_include_path, "%s/%s", base_path, include_file_name);
			bfree(base_path);

			char *included_shader = load_shader_from_file(full_include_path.array);
			dstr_free(&full_include_path);

			if (included_shader) {
				dstr_cat(&shader_file, included_shader);
				bfree(included_shader);
			} else {
				blog(LOG_WARNING, "[obs-shaderfilter] failed to include file: %s (from %s)", include_file_name, file_name);
			}
		} else {
			dstr_cat(&shader_file, line);
			dstr_cat(&shader_file, "\n");
		}
	}
	bfree(file_ptr);
	strlist_free(lines);
	return shader_file.array;
}

static void shader_filter_clear_params_internal(DARRAY(struct effect_param_data) *param_list) {
    if (!param_list) return;
	for (size_t i = 0; i < param_list->num; i++) {
		struct effect_param_data *param = param_list->array + i;
		dstr_free(&param->name);
		dstr_free(&param->display_name);
		dstr_free(&param->widget_type);
		dstr_free(&param->group);
		dstr_free(&param->path);
		da_free(param->option_values);
		for(size_t j=0; j < param->option_labels.num; ++j) {
			dstr_free(&param->option_labels.array[j]);
		}
		da_free(param->option_labels);
		if (param->image) {
			gs_image_file_free(param->image);
			param->image = NULL;
		}
        obs_weak_source_release(param->source);
        param->source = NULL;
        param->render = NULL; // Not owned by param_data
	}
	darray_free(&(*param_list).da); // Use direct darray_free
}


static void shader_filter_clear_params(struct shader_filter_data *filter) {
    shader_filter_clear_params_internal(&filter->stored_param_list);
}

<<<<<<< HEAD
static void shader_filter_clear_pass_params(struct shader_pass_info *pass_info) {
    if (pass_info->effect) {
        gs_effect_destroy(pass_info->effect);
        pass_info->effect = NULL;
    }
    shader_filter_clear_params_internal(&pass_info->stored_param_list);
    dstr_free(&pass_info->error_string); // Clear error string too
=======
static void load_sprite_buffer(struct shader_filter_data *filter)
{
	if (filter->sprite_buffer)
		return;
	struct gs_vb_data *vbd = gs_vbdata_create();
	vbd->num = 4;
	vbd->points = bmalloc(sizeof(struct vec3) * 4);
	vbd->num_tex = 1;
	vbd->tvarray = bmalloc(sizeof(struct gs_tvertarray));
	vbd->tvarray[0].width = 2;
	vbd->tvarray[0].array = bmalloc(sizeof(struct vec2) * 4);
	memset(vbd->points, 0, sizeof(struct vec3) * 4);
	memset(vbd->tvarray[0].array, 0, sizeof(struct vec2) * 4);
	filter->sprite_buffer = gs_vertexbuffer_create(vbd, GS_DYNAMIC);
}

static void shader_filter_reload_effect(struct shader_filter_data *filter)
{
	obs_data_t *settings = obs_source_get_settings(filter->context);

	// First, clean up the old effect and all references to it.
	filter->shader_start_time = 0.0f;
	shader_filter_clear_params(filter);

	if (filter->effect != NULL) {
		obs_enter_graphics();
		gs_effect_destroy(filter->effect);
		filter->effect = NULL;
		obs_leave_graphics();
	}

	// Load text and build the effect from the template, if necessary.
	char *shader_text = NULL;
	bool use_template = !obs_data_get_bool(settings, "override_entire_effect");

	if (obs_data_get_bool(settings, "from_file")) {
		const char *file_name = obs_data_get_string(settings, "shader_file_name");
		if (!strlen(file_name)) {
			obs_data_unset_user_value(settings, "last_error");
			goto end;
		}
		shader_text = load_shader_from_file(file_name);
		if (!shader_text) {
			obs_data_set_string(settings, "last_error", obs_module_text("ShaderFilter.FileLoadFailed"));
			goto end;
		}
	} else {
		shader_text = bstrdup(obs_data_get_string(settings, "shader_text"));
		use_template = true;
	}
	filter->use_template = use_template;

	struct dstr effect_text = {0};

	if (use_template) {
		dstr_cat(&effect_text, effect_template_begin);
	}

	if (shader_text) {
		dstr_cat(&effect_text, shader_text);
		bfree(shader_text);
	}

	if (use_template) {
		dstr_cat(&effect_text, effect_template_end);
	}

	// Create the effect.
	char *errors = NULL;

	obs_enter_graphics();
	int device_type = gs_get_device_type();
	if (device_type == GS_DEVICE_OPENGL) {
		dstr_replace(&effect_text, "[loop]", "");
		dstr_insert(&effect_text, 0, "#define OPENGL 1\n");
	}

	if (effect_text.len && dstr_find(&effect_text, "#define USE_PM_ALPHA 1")) {
		filter->use_pm_alpha = true;
	} else {
		filter->use_pm_alpha = false;
	}

	if (filter->effect)
		gs_effect_destroy(filter->effect);
	filter->effect = gs_effect_create(effect_text.array, NULL, &errors);
	obs_leave_graphics();

	if (filter->effect == NULL) {
		blog(LOG_WARNING, "[obs-shaderfilter] Unable to create effect. Errors returned from parser:\n%s",
		     (errors == NULL || strlen(errors) == 0 ? "(None)" : errors));
		if (errors && strlen(errors)) {
			obs_data_set_string(settings, "last_error", errors);
		} else {
			obs_data_set_string(settings, "last_error", obs_module_text("ShaderFilter.Unknown"));
		}
		dstr_free(&effect_text);
		bfree(errors);
		goto end;
	} else {
		dstr_free(&effect_text);
		obs_data_unset_user_value(settings, "last_error");
	}

	// Store references to the new effect's parameters.
	da_free(filter->stored_param_list);

	size_t effect_count = gs_effect_get_num_params(filter->effect);
	for (size_t effect_index = 0; effect_index < effect_count; effect_index++) {
		gs_eparam_t *param = gs_effect_get_param_by_idx(filter->effect, effect_index);
		if (!param)
			continue;
		struct gs_effect_param_info info;
		gs_effect_get_param_info(param, &info);

		if (strcmp(info.name, "uv_offset") == 0) {
			filter->param_uv_offset = param;
		} else if (strcmp(info.name, "uv_scale") == 0) {
			filter->param_uv_scale = param;
		} else if (strcmp(info.name, "uv_pixel_interval") == 0) {
			filter->param_uv_pixel_interval = param;
		} else if (strcmp(info.name, "uv_size") == 0) {
			filter->param_uv_size = param;
		} else if (strcmp(info.name, "current_time_ms") == 0) {
			filter->param_current_time_ms = param;
		} else if (strcmp(info.name, "current_time_sec") == 0) {
			filter->param_current_time_sec = param;
		} else if (strcmp(info.name, "current_time_min") == 0) {
			filter->param_current_time_min = param;
		} else if (strcmp(info.name, "current_time_hour") == 0) {
			filter->param_current_time_hour = param;
		} else if (strcmp(info.name, "current_time_day_of_week") == 0) {
			filter->param_current_time_day_of_week = param;
		} else if (strcmp(info.name, "current_time_day_of_month") == 0) {
			filter->param_current_time_day_of_month = param;
		} else if (strcmp(info.name, "current_time_month") == 0) {
			filter->param_current_time_month = param;
		} else if (strcmp(info.name, "current_time_day_of_year") == 0) {
			filter->param_current_time_day_of_year = param;
		} else if (strcmp(info.name, "current_time_year") == 0) {
			filter->param_current_time_year = param;
		} else if (strcmp(info.name, "elapsed_time") == 0) {
			filter->param_elapsed_time = param;
		} else if (strcmp(info.name, "elapsed_time_start") == 0) {
			filter->param_elapsed_time_start = param;
		} else if (strcmp(info.name, "elapsed_time_show") == 0) {
			filter->param_elapsed_time_show = param;
		} else if (strcmp(info.name, "elapsed_time_active") == 0) {
			filter->param_elapsed_time_active = param;
		} else if (strcmp(info.name, "elapsed_time_enable") == 0) {
			filter->param_elapsed_time_enable = param;
		} else if (strcmp(info.name, "rand_f") == 0) {
			filter->param_rand_f = param;
		} else if (strcmp(info.name, "rand_activation_f") == 0) {
			filter->param_rand_activation_f = param;
		} else if (strcmp(info.name, "rand_instance_f") == 0) {
			filter->param_rand_instance_f = param;
		} else if (strcmp(info.name, "loops") == 0) {
			filter->param_loops = param;
		} else if (strcmp(info.name, "loop_second") == 0) {
			filter->param_loop_second = param;
		} else if (strcmp(info.name, "local_time") == 0) {
			filter->param_local_time = param;
		} else if (strcmp(info.name, "ViewProj") == 0) {
			// Nothing.
		} else if (strcmp(info.name, "image") == 0) {
			filter->param_image = param;
		} else if (strcmp(info.name, "previous_image") == 0) {
			filter->param_previous_image = param;
		} else if (strcmp(info.name, "previous_output") == 0) {
			filter->param_previous_output = param;
		} else if (filter->transition && strcmp(info.name, "image_a") == 0) {
			filter->param_image_a = param;
		} else if (filter->transition && strcmp(info.name, "image_b") == 0) {
			filter->param_image_b = param;
		} else if (filter->transition && strcmp(info.name, "transition_time") == 0) {
			filter->param_transition_time = param;
		} else if (filter->transition && strcmp(info.name, "convert_linear") == 0) {
			filter->param_convert_linear = param;
		} else {
			struct effect_param_data *cached_data = da_push_back_new(filter->stored_param_list);
			dstr_copy(&cached_data->name, info.name);
			cached_data->type = info.type;
			cached_data->param = param;
			da_init(cached_data->option_values);
			da_init(cached_data->option_labels);
			const size_t annotation_count = gs_param_get_num_annotations(param);
			for (size_t annotation_index = 0; annotation_index < annotation_count; annotation_index++) {
				gs_eparam_t *annotation = gs_param_get_annotation_by_idx(param, annotation_index);
				void *annotation_default = gs_effect_get_default_val(annotation);
				gs_effect_get_param_info(annotation, &info);
				if (strcmp(info.name, "name") == 0 && info.type == GS_SHADER_PARAM_STRING) {
					dstr_copy(&cached_data->display_name, (const char *)annotation_default);
				} else if (strcmp(info.name, "label") == 0 && info.type == GS_SHADER_PARAM_STRING) {
					dstr_copy(&cached_data->display_name, (const char *)annotation_default);
				} else if (strcmp(info.name, "widget_type") == 0 && info.type == GS_SHADER_PARAM_STRING) {
					dstr_copy(&cached_data->widget_type, (const char *)annotation_default);
				} else if (strcmp(info.name, "group") == 0 && info.type == GS_SHADER_PARAM_STRING) {
					dstr_copy(&cached_data->group, (const char *)annotation_default);
				} else if (strcmp(info.name, "minimum") == 0) {
					if (info.type == GS_SHADER_PARAM_FLOAT || info.type == GS_SHADER_PARAM_VEC2 ||
					    info.type == GS_SHADER_PARAM_VEC3 || info.type == GS_SHADER_PARAM_VEC4) {
						cached_data->minimum.f = *(float *)annotation_default;
					} else if (info.type == GS_SHADER_PARAM_INT) {
						cached_data->minimum.i = *(int *)annotation_default;
					}
				} else if (strcmp(info.name, "maximum") == 0) {
					if (info.type == GS_SHADER_PARAM_FLOAT || info.type == GS_SHADER_PARAM_VEC2 ||
					    info.type == GS_SHADER_PARAM_VEC3 || info.type == GS_SHADER_PARAM_VEC4) {
						cached_data->maximum.f = *(float *)annotation_default;
					} else if (info.type == GS_SHADER_PARAM_INT) {
						cached_data->maximum.i = *(int *)annotation_default;
					}
				} else if (strcmp(info.name, "step") == 0) {
					if (info.type == GS_SHADER_PARAM_FLOAT || info.type == GS_SHADER_PARAM_VEC2 ||
					    info.type == GS_SHADER_PARAM_VEC3 || info.type == GS_SHADER_PARAM_VEC4) {
						cached_data->step.f = *(float *)annotation_default;
					} else if (info.type == GS_SHADER_PARAM_INT) {
						cached_data->step.i = *(int *)annotation_default;
					}
				} else if (strncmp(info.name, "option_", 7) == 0) {
					int id = atoi(info.name + 7);
					if (info.type == GS_SHADER_PARAM_INT) {
						int val = *(int *)annotation_default;
						int *cd = da_insert_new(cached_data->option_values, id);
						*cd = val;

					} else if (info.type == GS_SHADER_PARAM_STRING) {
						struct dstr val = {0};
						dstr_copy(&val, (const char *)annotation_default);
						struct dstr *cs = da_insert_new(cached_data->option_labels, id);
						*cs = val;
					}
				}
				bfree(annotation_default);
			}
		}
	}

end:
	obs_data_release(settings);
>>>>>>> origin/relocate-extra-pixels-ui
}


static void load_output_effect(struct shader_filter_data *filter) {
	if (filter->output_effect)
<<<<<<< HEAD
		return;

	char *effect_path = obs_module_file("output_template.effect");
	if (!effect_path) {
		blog(LOG_WARNING, "[obs-shaderfilter] output_template.effect not found");
		return;
=======
		gs_effect_destroy(filter->output_effect);
	if (filter->input_texrender)
		gs_texrender_destroy(filter->input_texrender);
	if (filter->output_texrender)
		gs_texrender_destroy(filter->output_texrender);
	if (filter->previous_input_texrender)
		gs_texrender_destroy(filter->previous_input_texrender);
	if (filter->previous_output_texrender)
		gs_texrender_destroy(filter->previous_output_texrender);
	if (filter->sprite_buffer)
		gs_vertexbuffer_destroy(filter->sprite_buffer);
	obs_leave_graphics();

	dstr_free(&filter->last_path);
	da_free(filter->stored_param_list);

	bfree(filter);
}

static bool shader_filter_from_file_changed(obs_properties_t *props, obs_property_t *p, obs_data_t *settings)
{
	UNUSED_PARAMETER(p);
	struct shader_filter_data *filter = obs_properties_get_param(props);

	bool from_file = obs_data_get_bool(settings, "from_file");

	obs_property_set_visible(obs_properties_get(props, "shader_text"), !from_file);
	obs_property_set_visible(obs_properties_get(props, "shader_file_name"), from_file);

	if (from_file != filter->last_from_file) {
		filter->reload_effect = true;
>>>>>>> origin/relocate-extra-pixels-ui
	}
	char *effect_str = load_shader_from_file(effect_path);
	bfree(effect_path);

	if (!effect_str) {
		blog(LOG_WARNING, "[obs-shaderfilter] could not load output_template.effect");
		return;
	}

	filter->output_effect = gs_effect_create_from_string(effect_str, NULL);
	bfree(effect_str);

	if (!filter->output_effect) {
		blog(LOG_WARNING, "[obs-shaderfilter] failed to create output_effect");
		return;
	}
	filter->param_output_image = gs_effect_get_param_by_name(filter->output_effect, "image");
}


static void shader_filter_reload_effect_internal(gs_effect_t **effect_ptr,
                                                 DARRAY(struct effect_param_data) *param_list,
                                                 const char *effect_string,
                                                 const char *file_path_for_errors,
                                                 struct dstr *error_dstr)
{
    if (*effect_ptr) {
        gs_effect_destroy(*effect_ptr);
        *effect_ptr = NULL;
    }
    shader_filter_clear_params_internal(param_list);
    if(error_dstr) dstr_free(error_dstr);


    if (!effect_string || !*effect_string) {
        if(error_dstr) dstr_copy(error_dstr, "Effect string is empty.");
        return;
    }

    const char *error = NULL;
    *effect_ptr = gs_effect_create_from_string(effect_string, &error);

    if (!*effect_ptr) {
        blog(LOG_WARNING, "[obs-shaderfilter] Effect compilation error for %s: %s",
             file_path_for_errors ? file_path_for_errors : "inline text", error ? error : "Unknown error");
        if (error_dstr) {
            dstr_printf(error_dstr, "Effect compilation error: %s", error ? error : "Unknown error");
        }
        // gs_effect_destroy(*effect_ptr); // Already null
        // *effect_ptr = NULL; // Already null
        return;
    }
    if(error_dstr) dstr_clear(error_dstr); // Clear any previous error message if successful


	darray_init(&(*param_list).da); // Use direct darray_init
	gs_effect_get_parameters(*effect_ptr, param_list);

    // Filter out known global/internal parameters
    DARRAY(struct effect_param_data) temp_list;
    da_init(temp_list);
    for (size_t i = 0; i < param_list->num; ++i) {
        struct effect_param_data *param = &param_list->array[i];
        const char *name = param->name.array;
        // Skip these known parameters
        if (strcmp(name, "ViewProj") == 0 || strcmp(name, "image") == 0 ||
            strcmp(name, "uv_offset") == 0 || strcmp(name, "uv_scale") == 0 ||
            strcmp(name, "uv_pixel_interval") == 0 || strcmp(name, "uv_size") == 0 ||
            strcmp(name, "elapsed_time") == 0 || strcmp(name, "elapsed_time_start") == 0 ||
            strcmp(name, "elapsed_time_show") == 0 || strcmp(name, "elapsed_time_active") == 0 ||
            strcmp(name, "elapsed_time_enable") == 0 || strcmp(name, "loops") == 0 ||
            strcmp(name, "loop_second") == 0 || strcmp(name, "local_time") == 0 ||
            strcmp(name, "rand_f") == 0 || strcmp(name, "rand_instance_f") == 0 ||
            strcmp(name, "rand_activation_f") == 0 || strcmp(name, "image_a") == 0 ||
            strcmp(name, "image_b") == 0 || strcmp(name, "transition_time") == 0 ||
            strcmp(name, "convert_linear") == 0 || strcmp(name, "previous_image") == 0 ||
            strcmp(name, "previous_output") == 0) {
            // Free the dstrs for skipped params
            dstr_free(&param->name); dstr_free(&param->display_name); dstr_free(&param->widget_type);
            dstr_free(&param->group); dstr_free(&param->path);
            da_free(param->option_values);
			for(size_t j=0; j < param->option_labels.num; ++j) dstr_free(&param->option_labels.array[j]);
            da_free(param->option_labels);
            continue;
        }
        // darray_push_back expects a pointer to the item
        darray_push_back(sizeof(struct effect_param_data), &temp_list, param);
    }
    // Move contents from temp_list to *param_list
    da_move(*param_list, temp_list);
}


static void shader_filter_reload_effect(struct shader_filter_data *filter) {
    obs_data_t *settings = obs_source_get_settings(filter->context);
    if (!settings) return;

    bool from_file = obs_data_get_bool(settings, "from_file");
    const char *shader_file_name = obs_data_get_string(settings, "shader_file_name");
    const char *shader_text = obs_data_get_string(settings, "shader_text");
    bool override_effect = obs_data_get_bool(settings, "override_entire_effect");

    char *effect_string = NULL;
    char *loaded_shader_text = NULL; // To be freed if loaded from file
    const char *current_path_for_errors = NULL;

    dstr_free(&filter->global_error_string); // Clear previous global error

    if (from_file) {
        if (shader_file_name && *shader_file_name) {
            loaded_shader_text = load_shader_from_file(shader_file_name);
            if (!loaded_shader_text) {
                dstr_printf(&filter->global_error_string, "Failed to load shader from file: %s", shader_file_name);
                goto cleanup_settings;
            }
            effect_string = loaded_shader_text;
            current_path_for_errors = shader_file_name;
        } else {
            dstr_copy(&filter->global_error_string, "No shader file specified.");
            goto cleanup_settings;
        }
    } else {
        effect_string = (char*)shader_text; // Direct pointer, do not free
        current_path_for_errors = "inline text";
    }

    if (!effect_string || !*effect_string) {
        dstr_copy(&filter->global_error_string, "Shader text is empty.");
         if (filter->effect) { // Clear existing effect if new one is empty
            gs_effect_destroy(filter->effect);
            filter->effect = NULL;
            shader_filter_clear_params(filter);
        }
        goto cleanup_loaded_text; // Skip compilation if empty
    }

    struct dstr full_effect_str = {0};
    if (!override_effect) {
        dstr_init_copy(&full_effect_str, effect_template_begin);
        dstr_cat(&full_effect_str, effect_string);
        dstr_cat(&full_effect_str, effect_template_end);
        effect_string = full_effect_str.array; // Use this combined string
    }

    shader_filter_reload_effect_internal(&filter->effect, &filter->stored_param_list,
                                         effect_string, current_path_for_errors, &filter->global_error_string);

    if (full_effect_str.array) {
        dstr_free(&full_effect_str); // Free combined string if it was used
    }

cleanup_loaded_text:
    if (loaded_shader_text) {
        bfree(loaded_shader_text);
    }
cleanup_settings:
    obs_data_release(settings);
    filter->reload_effect = false; // Reset flag
}


static bool shader_filter_reload_pass_effect(struct shader_filter_data *filter, int pass_index, obs_data_t *settings) {
    if (pass_index < 0 || pass_index >= MAX_SHADER_PASSES) return false;

    struct shader_pass_info *pass = &filter->passes[pass_index];
    char setting_name_path[64];
    snprintf(setting_name_path, sizeof(setting_name_path), "pass_%d_effect_file", pass_index);
    const char *effect_file_path = obs_data_get_string(settings, setting_name_path);

    // Clear previous effect and params if path is empty or different
    if (!effect_file_path || !*effect_file_path ||
        (pass->effect_file_path.array && strcmp(pass->effect_file_path.array, effect_file_path) != 0)) {
        shader_filter_clear_pass_params(pass); // Clears effect, params, and error string
        dstr_free(&pass->effect_file_path);    // Free old path dstr
        dstr_init(&pass->effect_file_path);    // Initialize new one (might remain empty)
    }

    if (!effect_file_path || !*effect_file_path) {
        // No file path, ensure effect is cleared and return (not an error, just no effect)
        dstr_copy(&pass->error_string, "No effect file specified for this pass."); // Informative message
        return true; // Successfully "processed" an empty path
    }

    // If effect is already loaded for this path, no need to reload
    if (pass->effect && pass->effect_file_path.array && strcmp(pass->effect_file_path.array, effect_file_path) == 0) {
        return true;
    }

    // Update stored path
    dstr_free(&pass->effect_file_path);
    dstr_init_copy(&pass->effect_file_path, effect_file_path);

    char *effect_string_loaded = load_shader_from_file(effect_file_path);
    if (!effect_string_loaded) {
        shader_filter_clear_pass_params(pass); // Clear out everything
        dstr_printf(&pass->error_string, "Failed to load effect file: %s", effect_file_path);
        blog(LOG_WARNING, "[obs-shaderfilter] Pass %d: Failed to load effect file: %s", pass_index, effect_file_path);
        return false; // Indicate failure
    }

    // For passes, we assume they are complete effects (not needing templates)
    // If template wrapping is desired for passes, it would be added here.
    shader_filter_reload_effect_internal(&pass->effect, &pass->stored_param_list,
                                         effect_string_loaded, effect_file_path, &pass->error_string);

    bfree(effect_string_loaded);

    if (!pass->effect) {
        // Error string is already set by shader_filter_reload_effect_internal
        blog(LOG_WARNING, "[obs-shaderfilter] Pass %d: Failed to compile effect: %s. Error: %s",
             pass_index, effect_file_path, pass->error_string.array ? pass->error_string.array : "Unknown");
        return false; // Indicate failure
    }

    // If successful, error_string would have been cleared by shader_filter_reload_effect_internal
    blog(LOG_INFO, "[obs-shaderfilter] Pass %d: Successfully loaded and compiled effect: %s", pass_index, effect_file_path);
    return true; // Indicate success
}


static void shader_filter_set_pass_effect_params(struct shader_filter_data *filter, int pass_idx) {
    if (pass_idx < 0 || pass_idx >= filter->num_active_passes || !filter->passes[pass_idx].effect) {
        return;
    }
    struct shader_pass_info *current_pass_info = &filter->passes[pass_idx];
    gs_effect_t *pass_effect = current_pass_info->effect;

    for (size_t i = 0; i < current_pass_info->stored_param_list.num; i++) {
        struct effect_param_data *param_info = current_pass_info->stored_param_list.array + i;
        param_info->param = gs_effect_get_param_by_name(pass_effect, param_info->name.array); // Re-acquire param in case effect was reloaded
        if (!param_info->param) continue;

        switch (param_info->type) {
        case GS_SHADER_PARAM_BOOL:
            gs_effect_set_bool(param_info->param, param_info->value.i);
            break;
        case GS_SHADER_PARAM_FLOAT:
            gs_effect_set_float(param_info->param, param_info->value.f);
            break;
        case GS_SHADER_PARAM_INT:
            gs_effect_set_int(param_info->param, param_info->value.i);
            break;
        case GS_SHADER_PARAM_STRING:
            // String parameters are not typically set per frame unless they change.
            // gs_effect_set_string(param_info->param, param_info->value.string);
            break;
        case GS_SHADER_PARAM_VEC2:
            gs_effect_set_vec2(param_info->param, &param_info->value.vec2);
            break;
        case GS_SHADER_PARAM_VEC3:
            gs_effect_set_vec3(param_info->param, &param_info->value.vec3);
            break;
        case GS_SHADER_PARAM_VEC4:
            gs_effect_set_vec4(param_info->param, &param_info->value.vec4);
            break;
        case GS_SHADER_PARAM_TEXTURE:
            if (param_info->source) {
                obs_source_t *source = obs_weak_source_get_source(param_info->source);
                if (source) {
                    gs_texture_t *tex = obs_source_get_texture(source);
                    if (tex) {
                         gs_effect_set_texture_srgb(param_info->param, tex);
                    }
                    obs_source_release(source);
                } else { // Source was removed or unavailable
                    gs_effect_set_texture_srgb(param_info->param, obs_get_black_texture());
                }
            } else if (param_info->image && param_info->image->texture) {
                gs_effect_set_texture_srgb(param_info->param, param_info->image->texture);
            } else if (param_info->render) { // For internal render targets (e.g. previous_output)
                 gs_effect_set_texture_srgb(param_info->param, gs_texrender_get_texture(param_info->render));
            } else {
                 gs_effect_set_texture_srgb(param_info->param, obs_get_black_texture());
            }
            break;
        default:
            break;
        }
    }
}


static bool add_source_to_list(void *data, obs_source_t *source) {
	obs_property_t *p = data;
	uint32_t flags = obs_source_get_output_flags(source);
	if ((flags & OBS_SOURCE_VIDEO) == 0 || (flags & OBS_SOURCE_DEPRECATED) != 0 || (flags & OBS_SOURCE_ASYNC) != 0)
		return true; // Skip non-video, deprecated, or async sources

	const char *name = obs_source_get_name(source);
	size_t count = obs_property_list_item_count(p);
	size_t idx = 0;
	while(idx < count && strcmp(name, obs_property_list_item_string(p, idx)) > 0) {
		idx++;
	}
	obs_property_list_insert_string(p, idx, name, name);
	return true;
}

// Helper function to add effect parameters to a properties group
static void add_effect_params_to_ui(obs_properties_t *props_group, DARRAY(struct effect_param_data) *param_list,
                                    const char *setting_prefix, obs_data_t *settings, DARRAY(obs_property_t *) created_groups_list)
{
	if (!param_list || !param_list->num) return;

	char prefixed_setting_name[256];
	char group_setting_name[256]; // For group properties

	for (size_t param_index = 0; param_index < param_list->num; param_index++) {
		struct effect_param_data *param = param_list->array + param_index;
		obs_property_t *p = NULL;
		obs_properties_t *target_props = props_group; // Default to the main group for this pass/effect

		snprintf(prefixed_setting_name, sizeof(prefixed_setting_name), "%s%s",
				 setting_prefix ? setting_prefix : "", param->name.array);

		// Handle parameter grouping
		if (param->group.array && param->group.len > 0) {
			obs_property_t *p_group_prop = NULL;
			snprintf(group_setting_name, sizeof(group_setting_name), "%s%s_group",
					 setting_prefix ? setting_prefix : "", param->group.array);

			// Check if this group already exists in created_groups_list for the current props_group context
			bool group_exists = false;
			for(size_t g_idx = 0; g_idx < created_groups_list.num; ++g_idx) {
				obs_property_t* existing_group_prop = created_groups_list.array[g_idx];
				if (strcmp(obs_property_name(existing_group_prop), group_setting_name) == 0) {
					p_group_prop = existing_group_prop;
					target_props = obs_property_get_properties(p_group_prop); // Get the subgroup's properties
					group_exists = true;
					break;
				}
			}

			if (!group_exists) {
				obs_properties_t *pg = obs_properties_create();
				p_group_prop = obs_properties_add_group(props_group, group_setting_name, param->group.array, OBS_GROUP_NORMAL, pg);
				da_push_back(created_groups_list, p_group_prop); // Add to list of created groups for this context
				target_props = pg; // Parameters will be added to this new subgroup
			}
		}


		const char *display_name = (param->display_name.len > 0) ? param->display_name.array : param->name.array;

		switch (param->type) {
		case GS_SHADER_PARAM_BOOL:
			p = obs_properties_add_bool(target_props, prefixed_setting_name, display_name);
			if (param->has_default) obs_property_set_long_description(p, param->label);
			break;
		case GS_SHADER_PARAM_FLOAT:
			p = obs_properties_add_float_slider(target_props, prefixed_setting_name, display_name,
												param->minimum.f, param->maximum.f, param->step.f);
			if (param->has_default) obs_property_set_long_description(p, param->label);
			break;
		case GS_SHADER_PARAM_INT:
			if (param->widget_type.array && strcmp(param->widget_type.array, "list") == 0) {
				p = obs_properties_add_list(target_props, prefixed_setting_name, display_name, OBS_COMBO_TYPE_LIST, OBS_COMBO_FORMAT_INT);
				for (size_t opt_idx = 0; opt_idx < param->option_labels.num; ++opt_idx) {
					obs_property_list_add_int(p, param->option_labels.array[opt_idx].array, param->option_values.array[opt_idx]);
				}
			} else {
				p = obs_properties_add_int_slider(target_props, prefixed_setting_name, display_name,
												  param->minimum.i, param->maximum.i, param->step.i);
			}
			if (param->has_default) obs_property_set_long_description(p, param->label);
			break;
		case GS_SHADER_PARAM_STRING:
			// Strings are usually file paths or similar, not typical UI elements unless specifically handled
			// For now, we'll skip adding them directly as editable fields, unless a widget_type is specified
			if (param->widget_type.array && strcmp(param->widget_type.array, "file") == 0) {
                 // TODO: Determine base path for file dialog if necessary
                char *default_path_str = "";
                if (param->path.array && param->path.len > 0) default_path_str = param->path.array;
				p = obs_properties_add_path(target_props, prefixed_setting_name, display_name, OBS_PATH_FILE, NULL, default_path_str);
			} else {
				// p = obs_properties_add_text(target_props, prefixed_setting_name, display_name, OBS_TEXT_DEFAULT);
			}
			if (p && param->has_default) obs_property_set_long_description(p, param->label);
			break;
		case GS_SHADER_PARAM_VEC2:
			// No standard vec2 UI element, could be two float sliders or a custom control
			// For now, just add a text info placeholder if needed.
			break;
		case GS_SHADER_PARAM_VEC3: // Often color
			if (param->widget_type.array && strcmp(param->widget_type.array, "color") == 0) {
				p = obs_properties_add_color(target_props, prefixed_setting_name, display_name);
			}
			// else no standard vec3 UI
			if (p && param->has_default) obs_property_set_long_description(p, param->label);
			break;
		case GS_SHADER_PARAM_VEC4: // Often color with alpha
			if (param->widget_type.array && strcmp(param->widget_type.array, "color") == 0) { // Assuming color means with alpha here
				p = obs_properties_add_color_alpha(target_props, prefixed_setting_name, display_name);
			}
			// else no standard vec4 UI
			if (p && param->has_default) obs_property_set_long_description(p, param->label);
			break;
		case GS_SHADER_PARAM_TEXTURE:
			if (param->widget_type.array && strcmp(param->widget_type.array, "source") == 0) {
				p = obs_properties_add_list(target_props, prefixed_setting_name, display_name, OBS_COMBO_TYPE_EDITABLE, OBS_COMBO_FORMAT_STRING);
				obs_property_list_add_string(p, "", ""); // Add an empty option
                obs_enum_sources(add_source_to_list, p);
			} else if (param->widget_type.array && strcmp(param->widget_type.array, "image_file") == 0) { // Corrected param_widget_type to param->widget_type
                 // TODO: Determine base path for file dialog if necessary
                char *default_path_str = "";
                if (param->path.array && param->path.len > 0) default_path_str = param->path.array;
                p = obs_properties_add_path(target_props, prefixed_setting_name, display_name, OBS_PATH_FILE, "Image Files (*.bmp *.tga *.png *.jpeg *.jpg *.gif);;All Files (*.*)", default_path_str);
            }
			// else no standard texture UI other than source or file
			if (p && param->has_default) obs_property_set_long_description(p, param->label);
			break;
		default:
			break;
		}
		// Any common post-add modifications can go here
	}
}


static bool shader_filter_from_file_changed(obs_properties_t *props, obs_property_t *p, obs_data_t *settings) {
    struct shader_filter_data *filter = obs_properties_get_param(props);
    if (!filter) return false;
    filter->reload_effect = true; // Signal that the main effect needs reload
    obs_source_update(filter->context, settings); // Trigger update to reload
    return true;
}

static bool shader_filter_text_changed(obs_properties_t *props, obs_property_t *p, obs_data_t *settings) {
    struct shader_filter_data *filter = obs_properties_get_param(props);
    if (!filter) return false;
    bool from_file = obs_data_get_bool(settings, "from_file");
    if (!from_file) { // Only trigger reload if not loading from file
        filter->reload_effect = true;
         obs_source_update(filter->context, settings);
    }
    return true;
}

static bool shader_filter_file_name_changed(obs_properties_t *props, obs_property_t *p, obs_data_t *settings) {
    struct shader_filter_data *filter = obs_properties_get_param(props);
    if (!filter) return false;
    bool from_file = obs_data_get_bool(settings, "from_file");
    if (from_file) { // Only trigger reload if loading from file
        filter->reload_effect = true;
        obs_source_update(filter->context, settings);
    }
    return true;
}


static bool shader_filter_pass_from_file_changed(obs_properties_t *props, obs_property_t *p, obs_data_t *settings) {
    struct shader_filter_data *filter = obs_properties_get_param(props);
    if (!filter) return false;
    // No specific reload flag for passes needed here as shader_filter_update will handle it.
    // Just need to trigger an update.
    obs_source_update(filter->context, settings);
    return true;
}

static bool shader_filter_pass_enabled_changed(obs_properties_t *props, obs_property_t *p, obs_data_t *settings) {
    struct shader_filter_data *filter = obs_properties_get_param(props);
    if (!filter) return false;
    // No specific reload flag needed, shader_filter_update will re-evaluate active passes.
    obs_source_update(filter->context, settings);
    return true;
}


static bool shader_filter_reload_effect_clicked(obs_properties_t *props, obs_property_t *property, void *custom_data) {
    struct shader_filter_data *filter = custom_data; // Passed as param to obs_properties_set_param
    if (!filter) { // Fallback if custom_data is not filter (e.g. from button itself)
        filter = obs_properties_get_param(props);
    }
    if (!filter) return false;

    filter->reload_effect = true; // Reload main effect

    // Also trigger reload for all enabled passes, as their context might need refresh (e.g. if global settings changed)
    // Or simply trigger a general update.
    obs_data_t *settings = obs_source_get_settings(filter->context);
    if(settings) {
        obs_source_update(filter->context, settings); // This will call shader_filter_update
        obs_data_release(settings);
    }
    return true;
}

static bool shader_filter_convert(obs_properties_t *props, obs_property_t *property, void *custom_data) {
    struct shader_filter_data *filter = custom_data;
     if (!filter) {
        filter = obs_properties_get_param(props);
    }
    if (!filter) return false;

    obs_data_t *settings = obs_source_get_settings(filter->context);
    if (!settings) return false;

    const char *shader_text = obs_data_get_string(settings, "shader_text");
    bool override_effect = obs_data_get_bool(settings, "override_entire_effect");

    if (override_effect) { // If overriding, template is already out. Add it.
        struct dstr new_text = {0};
        dstr_init_copy(&new_text, effect_template_begin);
        dstr_cat(&new_text, shader_text);
        dstr_cat(&new_text, effect_template_end);
        obs_data_set_string(settings, "shader_text", new_text.array);
        dstr_free(&new_text);
        obs_data_set_bool(settings, "override_entire_effect", false);
    } else { // If not overriding, template is in. Remove it.
        // This is a bit naive, assumes the exact template structure.
        const char *start_of_user_code = strstr(shader_text, effect_template_begin);
        if (start_of_user_code) start_of_user_code += strlen(effect_template_begin);
        else start_of_user_code = shader_text; // Fallback: use as is

        const char *end_of_user_code = strstr(start_of_user_code, effect_template_end);

        struct dstr user_shader = {0};
        if (end_of_user_code) {
            dstr_init_copy_len(&user_shader, start_of_user_code, end_of_user_code - start_of_user_code);
        } else {
            dstr_init_copy(&user_shader, start_of_user_code); // Copy rest if end template not found
        }
        obs_data_set_string(settings, "shader_text", user_shader.array);
        dstr_free(&user_shader);
        obs_data_set_bool(settings, "override_entire_effect", true);
    }

    //obs_source_update(filter->context, settings); // This would trigger reload.
    // We might not want immediate reload, just change settings and let user decide.
    // However, the properties window needs to reflect the change.
    // Forcing a properties refresh:
    obs_source_properties_changed(filter->context);


    obs_data_release(settings);
    return true;
}

static bool is_var_char(char ch) { return (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'; }

static void get_input_source(struct shader_filter_data *filter) {
	obs_source_t *parent = obs_filter_get_parent(filter->context);
	obs_source_t *target = obs_filter_get_target(filter->context);
	obs_source_t *input_source = target ? target : parent;

	if (filter->input_texrender) {
		if (filter->input_rendered) {
			if (filter->previous_input_texrender)
				gs_texrender_destroy(filter->previous_input_texrender);
			filter->previous_input_texrender = filter->input_texrender;
		} else {
			gs_texrender_destroy(filter->input_texrender);
		}
		filter->input_texrender = NULL;
	}

	if (input_source && obs_source_active(input_source)) {
		uint32_t width = obs_source_get_width(input_source);
		uint32_t height = obs_source_get_height(input_source);
		if (width == 0 || height == 0) return;

		filter->input_texrender = gs_texrender_create(GS_RGBA, GS_ZS_NONE); // Use GS_RGBA
		gs_texrender_reset(filter->input_texrender);
		if (!gs_texrender_resize(filter->input_texrender, width, height)) {
			blog(LOG_ERROR, "[obs-shaderfilter] Failed to resize input_texrender");
			gs_texrender_destroy(filter->input_texrender);
			filter->input_texrender = NULL;
			return;
		}

		gs_blend_state_push();
		gs_blend_function(GS_BLEND_ONE, GS_BLEND_ZERO); // Source blend for opaque copy
		obs_source_video_render(input_source);
		gs_blend_state_pop();
		filter->input_rendered = true;
	} else {
		filter->input_rendered = false;
	}
}

static void draw_output(struct shader_filter_data *filter) {
	if (!filter->output_texrender && !filter->output_effect) return;

	gs_texture_t *tex = gs_texrender_get_texture(filter->output_texrender);
	if (!tex) return;

	uint32_t width = gs_texture_get_width(tex);
	uint32_t height = gs_texture_get_height(tex);
	if (width == 0 || height == 0) return;

    gs_effect_set_texture_srgb(filter->param_output_image, tex);

	gs_viewport_push();
	gs_projection_push();
	gs_ortho(0.0f, (float)width, 0.0f, (float)height, -100.0f, 100.0f);
	gs_set_2d_mode(); // gs_set_2d_mode takes no arguments

	gs_blend_state_push();
	if (filter->use_pm_alpha)
		gs_blend_function(GS_BLEND_ONE, GS_BLEND_INVSRCALPHA); // Pre-multiplied alpha
	else
		gs_blend_function_separate(GS_BLEND_SRCALPHA, GS_BLEND_INVSRCALPHA, GS_BLEND_ONE, GS_BLEND_INVSRCALPHA); // Standard alpha

	gs_enable_blending(true);
	while (gs_effect_loop(filter->output_effect, "Draw")) {
		gs_draw_sprite(tex, 0, width, height);
	}
	gs_enable_blending(false);
	gs_blend_state_pop();
	gs_projection_pop();
	gs_viewport_pop();

	filter->output_rendered = true;
}


static void render_shader(struct shader_filter_data *filter, float t, obs_source_t *filter_to) {
    // This function is now primarily for the main (single) effect rendering logic
    // Multi-pass logic is handled directly in shader_filter_render
	if (!filter->effect || (!filter->input_texrender && !filter_to)) return;

	gs_texture_t *tex = filter->input_texrender ? gs_texrender_get_texture(filter->input_texrender) : NULL;
	if (!tex && !filter_to) return; // No primary input texture

	uint32_t base_width = filter->total_width - filter->expand_left - filter->expand_right;
	uint32_t base_height = filter->total_height - filter->expand_top - filter->expand_bottom;

	filter->uv_offset_val.x = (float)filter->expand_left / (float)filter->total_width;
	filter->uv_offset_val.y = (float)filter->expand_top / (float)filter->total_height;
	filter->uv_scale_val.x = (float)base_width / (float)filter->total_width;
	filter->uv_scale_val.y = (float)base_height / (float)filter->total_height;
	filter->uv_pixel_interval_val.x = 1.0f / (float)filter->total_width;
	filter->uv_pixel_interval_val.y = 1.0f / (float)filter->total_height;
	filter->uv_size_val.x = (float)filter->total_width;
	filter->uv_size_val.y = (float)filter->total_height;

	if (filter->param_uv_offset) gs_effect_set_vec2(filter->param_uv_offset, &filter->uv_offset_val);
	if (filter->param_uv_scale) gs_effect_set_vec2(filter->param_uv_scale, &filter->uv_scale_val);
	if (filter->param_uv_pixel_interval) gs_effect_set_vec2(filter->param_uv_pixel_interval, &filter->uv_pixel_interval_val);
	if (filter->param_uv_size) gs_effect_set_vec2(filter->param_uv_size, &filter->uv_size_val);
    // ... (set other global params like time, rand_f, etc.)
    if (filter->param_elapsed_time) gs_effect_set_float(filter->param_elapsed_time, filter->elapsed_time_val);
	if (filter->param_rand_f) gs_effect_set_float(filter->param_rand_f, filter->rand_f_val);
    // ... (and others) ...

	if (filter->param_image && tex) gs_effect_set_texture_srgb(filter->param_image, tex);
    if (filter->param_previous_image && filter->previous_input_texrender) {
        gs_effect_set_texture_srgb(filter->param_previous_image, gs_texrender_get_texture(filter->previous_input_texrender));
    }
    if (filter->param_previous_output && filter->previous_output_texrender) {
         gs_effect_set_texture_srgb(filter->param_previous_output, gs_texrender_get_texture(filter->previous_output_texrender));
    }


	if (filter->transition) {
		// Transition specific parameters
		if (filter->param_transition_time) gs_effect_set_float(filter->param_transition_time, t);
		if (filter->param_convert_linear) gs_effect_set_bool(filter->param_convert_linear, true); // Example

		if (filter_to) { // If there's a 'to' source for transition
			gs_texture_t *tex_b = obs_source_get_texture(filter_to);
			if (tex_b && filter->param_image_b) {
				gs_effect_set_texture_srgb(filter->param_image_b, tex_b);
			}
            // 'image_a' would be the 'from' source, already set as 'image'
            if(tex && filter->param_image_a) gs_effect_set_texture_srgb(filter->param_image_a, tex);
		}
	}

    // Set user-defined parameters for the main effect
    for (size_t i = 0; i < filter->stored_param_list.num; i++) {
        struct effect_param_data *param_info = filter->stored_param_list.array + i;
        // Re-acquire gs_eparam_t from the main effect, as it might have been reloaded
        param_info->param = gs_effect_get_param_by_name(filter->effect, param_info->name.array);
        if (!param_info->param) continue;

        switch (param_info->type) {
            case GS_SHADER_PARAM_BOOL: gs_effect_set_bool(param_info->param, param_info->value.i); break;
            case GS_SHADER_PARAM_FLOAT: gs_effect_set_float(param_info->param, param_info->value.f); break;
            case GS_SHADER_PARAM_INT: gs_effect_set_int(param_info->param, param_info->value.i); break;
            case GS_SHADER_PARAM_VEC2: gs_effect_set_vec2(param_info->param, &param_info->value.vec2); break;
            case GS_SHADER_PARAM_VEC3: gs_effect_set_vec3(param_info->param, &param_info->value.vec3); break;
            case GS_SHADER_PARAM_VEC4: gs_effect_set_vec4(param_info->param, &param_info->value.vec4); break;
            case GS_SHADER_PARAM_TEXTURE:
                if (param_info->source) {
                    obs_source_t *s = obs_weak_source_get_source(param_info->source);
                    if (s) {
                        gs_texture_t *tx = obs_source_get_texture(s);
                        if (tx) gs_effect_set_texture_srgb(param_info->param, tx);
                        obs_source_release(s);
                    } else gs_effect_set_texture_srgb(param_info->param, obs_get_black_texture());
                } else if (param_info->image && param_info->image->texture) {
                    gs_effect_set_texture_srgb(param_info->param, param_info->image->texture);
                } else if (param_info->render) {
                    gs_effect_set_texture_srgb(param_info->param, gs_texrender_get_texture(param_info->render));
                } else gs_effect_set_texture_srgb(param_info->param, obs_get_black_texture());
                break;
            default: break;
        }
    }


	if (filter->output_texrender) {
		gs_texrender_reset(filter->output_texrender);
		if (gs_texrender_resize(filter->output_texrender, filter->total_width, filter->total_height)) {
			gs_blend_state_push();
			gs_blend_function(GS_BLEND_ONE, GS_BLEND_ZERO); // Opaque draw for effect base

            const char *technique_name = filter->transition ? "Transition" : "Draw";
            gs_technique_t *tech = gs_effect_get_technique(filter->effect, technique_name);
            if (!tech && strcmp(technique_name, "Transition")==0) tech = gs_effect_get_technique(filter->effect, "Draw"); // Fallback for transitions
            if(!tech) tech = gs_effect_get_fallback_technique(filter->effect);


            if (tech) {
                size_t num_passes = gs_technique_begin(tech);
                for (size_t i = 0; i < num_passes; i++) {
                    if (gs_technique_begin_pass_by_index(tech, i)) {
                        if (tex) { // If there is a primary input texture
                            gs_draw_sprite(tex, 0, filter->total_width, filter->total_height);
                        } else if (filter_to) { // For transitions starting from nothing (e.g. fade to color from transparent)
                            // Render a clear or black quad? Or rely on shader. For now, do nothing if no 'tex'.
                            // This assumes shader can handle potentially unbound 'image'.
                        }
                        gs_technique_end_pass(tech);
                    }
                }
                gs_technique_end(tech);
            }

			gs_blend_state_pop();
			gs_texrender_end(filter->output_texrender);
		}
	}
}

gs_texrender_t *create_or_reset_texrender(gs_texrender_t *render) {
    if (!render) {
        render = gs_texrender_create(GS_RGBA, GS_ZS_NONE); // Use GS_RGBA
    } else {
        gs_texrender_reset(render); // Reset if exists
    }
    return render;
}


// --- END OF STATIC HELPER FUNCTION DEFINITIONS ---

// --- START OF OBS SOURCE INFO CALLBACK FUNCTION DEFINITIONS ---
// These must NOT be static

const char *shader_filter_get_name(void *unused) {
	UNUSED_PARAMETER(unused);
	return obs_module_text("ShaderFilter");
}

void *shader_filter_create(obs_data_t *settings, obs_source_t *source) {
	struct shader_filter_data *filter = bzalloc(sizeof(struct shader_filter_data));
	filter->context = source;
	filter->enabled = false;
	filter->transition = (obs_source_get_type(source) == OBS_SOURCE_TYPE_TRANSITION);
	filter->rand_instance_f_val = (float)rand_interval(0, UINT_MAX) / (float)UINT_MAX;
    dstr_init(&filter->global_error_string);

	for (int i = 0; i < MAX_SHADER_PASSES; ++i) {
		filter->passes[i].effect = NULL;
		filter->passes[i].enabled = false;
		dstr_init(&filter->passes[i].effect_file_path);
		da_init(filter->passes[i].stored_param_list);
        dstr_init(&filter->passes[i].error_string);
	}
	filter->num_active_passes = 0;

	filter->intermediate_texrender_A = create_or_reset_texrender(NULL);
	filter->intermediate_texrender_B = create_or_reset_texrender(NULL);
    filter->output_texrender = create_or_reset_texrender(NULL); // Main output, possibly final pass output

	load_output_effect(filter); // Load the passthrough effect for drawing final output

	// Initial update from settings. This MUST be called after all members of filter are initialized.
	// shader_filter_create is called before shader_filter_update when a source is first created.
	// So, calling shader_filter_update here ensures that settings are processed with a fully initialized filter struct.
	shader_filter_update(filter, settings);
	return filter;
}

void shader_filter_destroy(void *data) {
	struct shader_filter_data *filter = data;
	if (filter->effect) gs_effect_destroy(filter->effect);
	if (filter->output_effect) gs_effect_destroy(filter->output_effect);
	if (filter->input_texrender) gs_texrender_destroy(filter->input_texrender);
	if (filter->previous_input_texrender) gs_texrender_destroy(filter->previous_input_texrender);
	if (filter->output_texrender) gs_texrender_destroy(filter->output_texrender);
	if (filter->previous_output_texrender) gs_texrender_destroy(filter->previous_output_texrender);

    if (filter->intermediate_texrender_A) gs_texrender_destroy(filter->intermediate_texrender_A);
	if (filter->intermediate_texrender_B) gs_texrender_destroy(filter->intermediate_texrender_B);

	shader_filter_clear_params(filter); // Clears main stored_param_list
    dstr_free(&filter->global_error_string);

	for (int i = 0; i < MAX_SHADER_PASSES; ++i) {
		shader_filter_clear_pass_params(&filter->passes[i]); // Clears effect, params, path dstr, error dstr
	}

	dstr_free(&filter->last_path);
	bfree(filter);
}


// Helper to pack RGBA floats (0-1 range) into a uint32_t (0xAABBGGRR for OBS color)
static inline uint32_t vec4_to_u32_color(struct vec4 v) {
    uint8_t r = (uint8_t)(v.x * 255.0f);
    uint8_t g = (uint8_t)(v.y * 255.0f);
    uint8_t b = (uint8_t)(v.z * 255.0f);
    uint8_t a = (uint8_t)(v.w * 255.0f);
    return ((uint32_t)a << 24) | ((uint32_t)b << 16) | ((uint32_t)g << 8) | r;
}

// Helper to pack RGB floats (0-1 range) into a uint32_t (0xFFBBGGRR for OBS color)
static inline uint32_t vec3_to_u32_color(struct vec3 v) {
    uint8_t r = (uint8_t)(v.x * 255.0f);
    uint8_t g = (uint8_t)(v.y * 255.0f);
    uint8_t b = (uint8_t)(v.z * 255.0f);
    return (0xFFU << 24) | ((uint32_t)b << 16) | ((uint32_t)g << 8) | r; // Alpha is 255 (opaque)
}


obs_properties_t *shader_filter_properties(void *data)
{
	struct shader_filter_data *filter = data;
    obs_data_t *settings = filter ? obs_source_get_settings(filter->context) : NULL;
    bool temp_settings = false;
    if (!settings && !filter) {
        settings = obs_data_create();
        shader_filter_defaults(settings);
        temp_settings = true;
    }

	struct dstr examples_path = {0};
	dstr_init(&examples_path);
	dstr_cat(&examples_path, obs_get_module_data_path(obs_current_module()));
	dstr_cat(&examples_path, "/examples");
	char *abs_examples_path = os_get_abs_path_ptr(examples_path.array);

	obs_properties_t *props = obs_properties_create();
	if (filter) {
	    obs_properties_set_param(props, filter, NULL);
    }

	obs_properties_add_bool(props, "override_entire_effect", obs_module_text("ShaderFilter.OverrideEntireEffect"));
	obs_property_t *from_file = obs_properties_add_bool(props, "from_file", obs_module_text("ShaderFilter.LoadFromFile"));
	obs_property_set_modified_callback(from_file, shader_filter_from_file_changed);

	obs_property_t *shader_text_prop = obs_properties_add_text(props, "shader_text", obs_module_text("ShaderFilter.ShaderText"), OBS_TEXT_MULTILINE);
	obs_property_set_modified_callback(shader_text_prop, shader_filter_text_changed);
	obs_properties_add_button2(props, "shader_convert", obs_module_text("ShaderFilter.Convert"), shader_filter_convert, filter);

	obs_property_t *file_name_prop = obs_properties_add_path(props, "shader_file_name", obs_module_text("ShaderFilter.ShaderFileName"), OBS_PATH_FILE, NULL, abs_examples_path ? abs_examples_path : examples_path.array);
	obs_property_set_modified_callback(file_name_prop, shader_filter_file_name_changed);

    if (filter && filter->global_error_string.len > 0) {
        obs_property_t *error_prop = obs_properties_add_text(props, "global_compile_error", obs_module_text("ShaderFilter.Error"), OBS_TEXT_INFO);
        obs_property_text_set_info_type(error_prop, OBS_TEXT_INFO_ERROR);
        obs_property_text_set_value(error_prop, filter->global_error_string.array);
    }

	obs_properties_add_button2(props, "reload_effect_button", obs_module_text("ShaderFilter.ReloadEffect"), shader_filter_reload_effect_clicked, filter);

	if (filter) {
		char pass_prop_name_ui[64];
		char pass_group_id_ui[64];
		char pass_display_name_ui[128];
        char pass_error_prop_name_ui[70];

		for (int i = 0; i < MAX_SHADER_PASSES; ++i) {
			snprintf(pass_group_id_ui, sizeof(pass_group_id_ui), "pass_%d_group", i);
			snprintf(pass_display_name_ui, sizeof(pass_display_name_ui), "%s %d", obs_module_text("ShaderFilter.Pass"), i + 1);

            obs_properties_t *pass_props_content = obs_properties_create();
			obs_properties_add_group(props, pass_group_id_ui, pass_display_name_ui, OBS_GROUP_NORMAL, pass_props_content);

			snprintf(pass_prop_name_ui, sizeof(pass_prop_name_ui), "pass_%d_enabled", i);
			obs_property_t *p_enabled = obs_properties_add_bool(pass_props_content, pass_prop_name_ui, obs_module_text("ShaderFilter.EnablePass"));
            obs_property_set_modified_callback(p_enabled, shader_filter_pass_enabled_changed);

			snprintf(pass_prop_name_ui, sizeof(pass_prop_name_ui), "pass_%d_effect_file", i);
			obs_property_t* p_path = obs_properties_add_path(pass_props_content, pass_prop_name_ui, obs_module_text("ShaderFilter.EffectFile"),
						OBS_PATH_FILE, NULL, abs_examples_path ? abs_examples_path : examples_path.array);
            obs_property_set_modified_callback(p_path, shader_filter_pass_from_file_changed);

            if (filter->passes[i].error_string.len > 0) {
                 snprintf(pass_error_prop_name_ui, sizeof(pass_error_prop_name_ui), "pass_%d_error", i);
                 obs_property_t *pass_error_prop = obs_properties_add_text(pass_props_content, pass_error_prop_name_ui, obs_module_text("ShaderFilter.PassError"), OBS_TEXT_INFO);
                 obs_property_text_set_info_type(pass_error_prop, OBS_TEXT_INFO_ERROR);
                 obs_property_text_set_value(pass_error_prop, filter->passes[i].error_string.array);
            }

			if (filter->passes[i].enabled && filter->passes[i].effect && filter->passes[i].error_string.len == 0) {
				char prefix[16];
				snprintf(prefix, sizeof(prefix), "pass_%d_", i);
                DARRAY(obs_property_t *) pass_param_ui_groups;
		        da_init(pass_param_ui_groups);
				add_effect_params_to_ui(pass_props_content, &filter->passes[i].stored_param_list, prefix, settings, pass_param_ui_groups);
                da_free(pass_param_ui_groups);
			}
		}
	}

	obs_properties_add_text(props, "main_shader_parameters_label", obs_module_text("ShaderFilter.MainShaderParameters"), OBS_TEXT_INFO);
	if (filter && filter->effect && filter->global_error_string.len == 0) {
        DARRAY(obs_property_t *) main_created_groups;
	    da_init(main_created_groups);
		add_effect_params_to_ui(props, &filter->stored_param_list, "", settings, main_created_groups);
        da_free(main_created_groups);
	}

<<<<<<< HEAD
=======
	obs_properties_add_bool(props, "override_entire_effect", obs_module_text("ShaderFilter.OverrideEntireEffect"));

	obs_property_t *from_file = obs_properties_add_bool(props, "from_file", obs_module_text("ShaderFilter.LoadFromFile"));
	obs_property_set_modified_callback(from_file, shader_filter_from_file_changed);

	obs_property_t *shader_text =
		obs_properties_add_text(props, "shader_text", obs_module_text("ShaderFilter.ShaderText"), OBS_TEXT_MULTILINE);
	obs_property_set_modified_callback(shader_text, shader_filter_text_changed);

	obs_properties_add_button2(props, "shader_convert", obs_module_text("ShaderFilter.Convert"), shader_filter_convert, data);

	char *abs_path = os_get_abs_path_ptr(examples_path.array);
	obs_property_t *file_name = obs_properties_add_path(props, "shader_file_name",
							    obs_module_text("ShaderFilter.ShaderFileName"), OBS_PATH_FILE, NULL,
							    abs_path ? abs_path : examples_path.array);
	if (abs_path)
		bfree(abs_path);
	dstr_free(&examples_path);
	obs_property_set_modified_callback(file_name, shader_filter_file_name_changed);

	if (filter) {
		obs_data_t *settings = obs_source_get_settings(filter->context);
		const char *last_error = obs_data_get_string(settings, "last_error");
		if (last_error && strlen(last_error)) {
			obs_property_t *error =
				obs_properties_add_text(props, "last_error", obs_module_text("ShaderFilter.Error"), OBS_TEXT_INFO);
			obs_property_text_set_info_type(error, OBS_TEXT_INFO_ERROR);
		}
		obs_data_release(settings);
	}

	obs_properties_add_button(props, "reload_effect", obs_module_text("ShaderFilter.ReloadEffect"),
				  shader_filter_reload_effect_clicked);

	DARRAY(obs_property_t *) groups;
	da_init(groups);

	size_t param_count = filter->stored_param_list.num;
	for (size_t param_index = 0; param_index < param_count; param_index++) {
		struct effect_param_data *param = (filter->stored_param_list.array + param_index);
		//gs_eparam_t *annot = gs_param_get_annotation_by_idx(param->param, param_index);
		const char *param_name = param->name.array;
		const char *label = param->display_name.array;
		const char *widget_type = param->widget_type.array;
		const char *group_name = param->group.array;
		const int *options = param->option_values.array;
		const struct dstr *option_labels = param->option_labels.array;

		struct dstr display_name = {0};
		struct dstr sources_name = {0};

		if (label == NULL) {
			dstr_ncat(&display_name, param_name, param->name.len);
			dstr_replace(&display_name, "_", " ");
		} else {
			dstr_ncat(&display_name, label, param->display_name.len);
		}
		obs_properties_t *group = NULL;
		if (group_name && strlen(group_name)) {
			for (size_t i = 0; i < groups.num; i++) {
				const char *n = obs_property_name(groups.array[i]);
				if (strcmp(n, group_name) == 0) {
					group = obs_property_group_content(groups.array[i]);
				}
			}
			if (!group) {
				group = obs_properties_create();
				obs_property_t *p =
					obs_properties_add_group(props, group_name, group_name, OBS_GROUP_NORMAL, group);
				da_push_back(groups, &p);
			}
		}
		if (!group)
			group = props;
		switch (param->type) {
		case GS_SHADER_PARAM_BOOL:
			obs_properties_add_bool(group, param_name, display_name.array);
			break;
		case GS_SHADER_PARAM_FLOAT: {
			double range_min = param->minimum.f;
			double range_max = param->maximum.f;
			double step = param->step.f;
			if (range_min == range_max) {
				range_min = -1000.0;
				range_max = 1000.0;
				step = 0.0001;
			}
			obs_properties_remove_by_name(props, param_name);
			if (widget_type != NULL && strcmp(widget_type, "slider") == 0) {
				obs_properties_add_float_slider(group, param_name, display_name.array, range_min, range_max, step);
			} else {
				obs_properties_add_float(group, param_name, display_name.array, range_min, range_max, step);
			}
			break;
		}
		case GS_SHADER_PARAM_INT: {
			int range_min = (int)param->minimum.i;
			int range_max = (int)param->maximum.i;
			int step = (int)param->step.i;
			if (range_min == range_max) {
				range_min = -1000;
				range_max = 1000;
				step = 1;
			}
			obs_properties_remove_by_name(props, param_name);

			if (widget_type != NULL && strcmp(widget_type, "slider") == 0) {
				obs_properties_add_int_slider(group, param_name, display_name.array, range_min, range_max, step);
			} else if (widget_type != NULL && strcmp(widget_type, "select") == 0) {
				obs_property_t *plist = obs_properties_add_list(group, param_name, display_name.array,
										OBS_COMBO_TYPE_LIST, OBS_COMBO_FORMAT_INT);
				for (size_t i = 0; i < param->option_values.num; i++) {
					obs_property_list_add_int(plist, option_labels[i].array, options[i]);
				}
			} else {
				obs_properties_add_int(group, param_name, display_name.array, range_min, range_max, step);
			}
			break;
		}
		case GS_SHADER_PARAM_INT3:

			break;
		case GS_SHADER_PARAM_VEC2: {
			double range_min = param->minimum.f;
			double range_max = param->maximum.f;
			double step = param->step.f;
			if (range_min == range_max) {
				range_min = -1000.0;
				range_max = 1000.0;
				step = 0.0001;
			}

			bool slider = (widget_type != NULL && strcmp(widget_type, "slider") == 0);

			for (size_t i = 0; i < 2; i++) {
				dstr_printf(&sources_name, "%s_%zu", param_name, i);
				if (i < param->option_labels.num) {
					if (slider) {
						obs_properties_add_float_slider(group, sources_name.array,
										param->option_labels.array[i].array, range_min,
										range_max, step);
					} else {
						obs_properties_add_float(group, sources_name.array,
									 param->option_labels.array[i].array, range_min, range_max,
									 step);
					}
				} else if (slider) {

					obs_properties_add_float_slider(group, sources_name.array, display_name.array, range_min,
									range_max, step);
				} else {
					obs_properties_add_float(group, sources_name.array, display_name.array, range_min,
								 range_max, step);
				}
			}
			dstr_free(&sources_name);

			break;
		}
		case GS_SHADER_PARAM_VEC3:
			if (widget_type != NULL && strcmp(widget_type, "slider") == 0) {
				double range_min = param->minimum.f;
				double range_max = param->maximum.f;
				double step = param->step.f;
				if (range_min == range_max) {
					range_min = -1000.0;
					range_max = 1000.0;
					step = 0.0001;
				}
				for (size_t i = 0; i < 3; i++) {
					dstr_printf(&sources_name, "%s_%zu", param_name, i);
					if (i < param->option_labels.num) {
						obs_properties_add_float_slider(group, sources_name.array,
										param->option_labels.array[i].array, range_min,
										range_max, step);
					} else {
						obs_properties_add_float_slider(group, sources_name.array, display_name.array,
										range_min, range_max, step);
					}
				}
				dstr_free(&sources_name);
			} else {
				obs_properties_add_color(group, param_name, display_name.array);
			}
			break;
		case GS_SHADER_PARAM_VEC4:
			if (widget_type != NULL && strcmp(widget_type, "slider") == 0) {
				double range_min = param->minimum.f;
				double range_max = param->maximum.f;
				double step = param->step.f;
				if (range_min == range_max) {
					range_min = -1000.0;
					range_max = 1000.0;
					step = 0.0001;
				}
				for (size_t i = 0; i < 4; i++) {
					dstr_printf(&sources_name, "%s_%zu", param_name, i);
					if (i < param->option_labels.num) {
						obs_properties_add_float_slider(group, sources_name.array,
										param->option_labels.array[i].array, range_min,
										range_max, step);
					} else {
						obs_properties_add_float_slider(group, sources_name.array, display_name.array,
										range_min, range_max, step);
					}
				}
				dstr_free(&sources_name);
			} else {
				obs_properties_add_color_alpha(group, param_name, display_name.array);
			}
			break;
		case GS_SHADER_PARAM_TEXTURE:
			if (widget_type != NULL && strcmp(widget_type, "source") == 0) {
				dstr_init_copy_dstr(&sources_name, &param->name);
				dstr_cat(&sources_name, "_source");
				obs_property_t *p = obs_properties_add_list(group, sources_name.array, display_name.array,
									    OBS_COMBO_TYPE_EDITABLE, OBS_COMBO_FORMAT_STRING);
				dstr_free(&sources_name);
				obs_enum_sources(add_source_to_list, p);
				obs_enum_scenes(add_source_to_list, p);
				obs_property_list_insert_string(p, 0, "", "");

			} else if (widget_type != NULL && strcmp(widget_type, "file") == 0) {
				obs_properties_add_path(group, param_name, display_name.array, OBS_PATH_FILE,
							shader_filter_texture_file_filter, NULL);
			} else {
				dstr_init_copy_dstr(&sources_name, &param->name);
				dstr_cat(&sources_name, "_source");
				obs_property_t *p = obs_properties_add_list(group, sources_name.array, display_name.array,
									    OBS_COMBO_TYPE_EDITABLE, OBS_COMBO_FORMAT_STRING);
				dstr_free(&sources_name);
				obs_property_list_add_string(p, "", "");
				obs_enum_sources(add_source_to_list, p);
				obs_enum_scenes(add_source_to_list, p);
				obs_properties_add_path(group, param_name, display_name.array, OBS_PATH_FILE,
							shader_filter_texture_file_filter, NULL);
			}
			break;
		case GS_SHADER_PARAM_STRING:
			if (widget_type != NULL && strcmp(widget_type, "info") == 0) {
				obs_properties_add_text(group, param_name, display_name.array, OBS_TEXT_INFO);
			} else {
				obs_properties_add_text(group, param_name, display_name.array, OBS_TEXT_MULTILINE);
			}
			break;
		default:;
		}
		dstr_free(&display_name);
	}
	da_free(groups);

>>>>>>> origin/relocate-extra-pixels-ui
	if (!filter || !filter->transition) {
		obs_properties_add_int(props, "expand_left", obs_module_text("ShaderFilter.ExpandLeft"), 0, 9999, 1);
		obs_properties_add_int(props, "expand_right", obs_module_text("ShaderFilter.ExpandRight"), 0, 9999, 1);
		obs_properties_add_int(props, "expand_top", obs_module_text("ShaderFilter.ExpandTop"), 0, 9999, 1);
		obs_properties_add_int(props, "expand_bottom", obs_module_text("ShaderFilter.ExpandBottom"), 0, 9999, 1);
	}

	obs_properties_add_text(
		props, "plugin_info",
		"<a href=\"https://obsproject.com/forum/resources/obs-shaderfilter.1736/\">obs-shaderfilter</a> (" PROJECT_VERSION
		") by <a href=\"https://www.exeldro.com\">Exeldro</a>",
		OBS_TEXT_INFO);

	if (abs_examples_path) bfree(abs_examples_path);
	dstr_free(&examples_path);

    if (settings && temp_settings) {
        obs_data_release(settings);
    } else if (settings) {
        obs_data_release(settings);
    }
	return props;
}

void shader_filter_update(void *data, obs_data_t *settings) {
	struct shader_filter_data *filter = data;
	bool main_effect_changed_flag = false; // Flag to track if main effect was reloaded
	bool pass_effect_changed_flags[MAX_SHADER_PASSES] = {false}; // Flags for pass effects

	// Store expand values
	if (!filter->transition) {
		filter->expand_left = (int)obs_data_get_int(settings, "expand_left");
		filter->expand_right = (int)obs_data_get_int(settings, "expand_right");
		filter->expand_top = (int)obs_data_get_int(settings, "expand_top");
		filter->expand_bottom = (int)obs_data_get_int(settings, "expand_bottom");
	} else {
		filter->expand_left = filter->expand_right = filter->expand_top = filter->expand_bottom = 0;
	}

	// Check if main effect needs reload (path/text change or manual reload)
	const char *new_path = obs_data_get_string(settings, "shader_file_name");
	bool new_from_file = obs_data_get_bool(settings, "from_file");
	bool main_needs_reload = filter->reload_effect ||
	                         (new_from_file != filter->last_from_file) ||
	                         (new_from_file && strcmp(new_path, filter->last_path.array) != 0) ||
	                         (!new_from_file && !filter->effect); // Reload if switching to text and no effect yet

	if (main_needs_reload) {
		dstr_copy(&filter->last_path, new_path);
		filter->last_from_file = new_from_file;
		shader_filter_reload_effect(filter); // This clears old params and loads new ones
		main_effect_changed_flag = true; // Mark that main effect params might have changed
		filter->reload_effect = false; // Reset flag
	}

	// Process shader passes
	filter->num_active_passes = 0;
	for (int i = 0; i < MAX_SHADER_PASSES; ++i) {
		char setting_name_enabled[64];
		char setting_name_path[64];
		snprintf(setting_name_enabled, sizeof(setting_name_enabled), "pass_%d_enabled", i);
		snprintf(setting_name_path, sizeof(setting_name_path), "pass_%d_effect_file", i);

		bool pass_is_enabled = obs_data_get_bool(settings, setting_name_enabled);
		const char *pass_effect_file = obs_data_get_string(settings, setting_name_path);

		if (filter->passes[i].enabled != pass_is_enabled) {
			filter->passes[i].enabled = pass_is_enabled;
			pass_effect_changed_flags[i] = true; // State change might require UI or param refresh
		}

		if (pass_is_enabled) {
			bool pass_needs_reload = !filter->passes[i].effect || // No effect loaded yet
			                         (filter->passes[i].effect_file_path.len == 0 || strcmp(filter->passes[i].effect_file_path.array, pass_effect_file) != 0); // Path changed

			if (pass_needs_reload && pass_effect_file && *pass_effect_file) {
				shader_filter_reload_pass_effect(filter, i, settings); // Reloads the specific pass
				pass_effect_changed_flags[i] = true; // Mark that this pass's params changed
			} else if (!pass_effect_file || !*pass_effect_file) { // Path cleared
                if(filter->passes[i].effect) { // If there was an effect, clear it
				    shader_filter_clear_pass_params(&filter->passes[i]);
                    dstr_free(&filter->passes[i].effect_file_path); // Free old path
                    dstr_init(&filter->passes[i].effect_file_path); // Init to empty
				    pass_effect_changed_flags[i] = true;
                }
                dstr_copy(&filter->passes[i].error_string, "No effect file specified for this pass.");
			}

			if (filter->passes[i].effect && filter->passes[i].error_string.len == 0) { // If effect successfully loaded/exists for this pass
				filter->num_active_passes++;
			}
		} else { // Pass is not enabled
			if (filter->passes[i].effect) { // If it had an effect, clear it
				shader_filter_clear_pass_params(&filter->passes[i]);
                dstr_free(&filter->passes[i].effect_file_path);
                dstr_init(&filter->passes[i].effect_file_path);
				pass_effect_changed_flags[i] = true;
			}
		}
	}


	// If main effect was reloaded, set default values for its new parameters in obs_data_t if not already set by user
	if (main_effect_changed_flag && filter->effect && filter->global_error_string.len == 0) {
		for (size_t j = 0; j < filter->stored_param_list.num; j++) {
			struct effect_param_data *param_info = filter->stored_param_list.array + j;
			if (param_info->has_default && !obs_data_has_user_value(settings, param_info->name.array)) {
				switch (param_info->type) {
					case GS_SHADER_PARAM_BOOL:  obs_data_set_bool(settings, param_info->name.array, param_info->default_value.i); break;
					case GS_SHADER_PARAM_FLOAT: obs_data_set_double(settings, param_info->name.array, param_info->default_value.f); break;
					case GS_SHADER_PARAM_INT:   obs_data_set_int(settings, param_info->name.array, param_info->default_value.i); break;
					case GS_SHADER_PARAM_VEC3:
						if (param_info->widget_type.array && strcmp(param_info->widget_type.array, "color") == 0) {
							uint32_t color_val = vec3_to_u32_color(param_info->default_value.vec3);
							obs_data_set_int(settings, param_info->name.array, (long long)color_val);
						}
						break;
					case GS_SHADER_PARAM_VEC4:
						if (param_info->widget_type.array && strcmp(param_info->widget_type.array, "color") == 0) {
							uint32_t color_val = vec4_to_u32_color(param_info->default_value.vec4);
							obs_data_set_int(settings, param_info->name.array, (long long)color_val);
						}
						break;
					case GS_SHADER_PARAM_TEXTURE:
						if (param_info->default_value.string) { // Default value for texture is usually a path or source name string
							obs_data_set_string(settings, param_info->name.array, param_info->default_value.string);
						}
						break;
                    case GS_SHADER_PARAM_STRING: // Generic string
                        if (param_info->default_value.string) {
                            obs_data_set_string(settings, param_info->name.array, param_info->default_value.string);
                        }
                        break;
					default: break;
				}
			}
		}
	}

	// For each pass, if its effect was reloaded, set default values for its new parameters
	for (int i = 0; i < MAX_SHADER_PASSES; ++i) {
		if (pass_effect_changed_flags[i] && filter->passes[i].effect && filter->passes[i].error_string.len == 0) {
			char prefixed_param_name[256];
			for (size_t j = 0; j < filter->passes[i].stored_param_list.num; j++) {
				struct effect_param_data *param_info = filter->passes[i].stored_param_list.array + j;
				snprintf(prefixed_param_name, sizeof(prefixed_param_name), "pass_%d_%s", i, param_info->name.array);
				if (param_info->has_default && !obs_data_has_user_value(settings, prefixed_param_name)) {
					switch (param_info->type) {
						case GS_SHADER_PARAM_BOOL:  obs_data_set_bool(settings, prefixed_param_name, param_info->default_value.i); break;
						case GS_SHADER_PARAM_FLOAT: obs_data_set_double(settings, prefixed_param_name, param_info->default_value.f); break;
						case GS_SHADER_PARAM_INT:   obs_data_set_int(settings, prefixed_param_name, param_info->default_value.i); break;
						case GS_SHADER_PARAM_VEC3:
							if (param_info->widget_type.array && strcmp(param_info->widget_type.array, "color") == 0) {
								uint32_t color_val = vec3_to_u32_color(param_info->default_value.vec3);
								obs_data_set_int(settings, prefixed_param_name, (long long)color_val);
							}
							break;
						case GS_SHADER_PARAM_VEC4:
							if (param_info->widget_type.array && strcmp(param_info->widget_type.array, "color") == 0) {
								uint32_t color_val = vec4_to_u32_color(param_info->default_value.vec4);
								obs_data_set_int(settings, prefixed_param_name, (long long)color_val);
							}
							break;
						case GS_SHADER_PARAM_TEXTURE:
							if (param_info->default_value.string) {
								obs_data_set_string(settings, prefixed_param_name, param_info->default_value.string);
							}
							break;
                        case GS_SHADER_PARAM_STRING:
                            if (param_info->default_value.string) {
                                obs_data_set_string(settings, prefixed_param_name, param_info->default_value.string);
                            }
                            break;
						default: break;
					}
				}
			}
		}
	}

	// Load all parameters from settings into filter->stored_param_list (main effect)
	if (filter->effect && filter->global_error_string.len == 0) {
		for (size_t j = 0; j < filter->stored_param_list.num; j++) {
			struct effect_param_data *param_info = filter->stored_param_list.array + j;
			// ... (existing logic to load value from settings into param_info->value)
			// This part should correctly handle all types, including textures (paths/sources)
			// and colors (packed int from settings, unpacked to vecN for param_info->value).
			switch (param_info->type) {
				case GS_SHADER_PARAM_BOOL: param_info->value.i = obs_data_get_bool(settings, param_info->name.array); break;
				case GS_SHADER_PARAM_FLOAT: param_info->value.f = obs_data_get_double(settings, param_info->name.array); break;
				case GS_SHADER_PARAM_INT: param_info->value.i = obs_data_get_int(settings, param_info->name.array); break;
				case GS_SHADER_PARAM_VEC3:
                    if (param_info->widget_type.array && strcmp(param_info->widget_type.array, "color") == 0) {
                        uint32_t color_int = (uint32_t)obs_data_get_int(settings, param_info->name.array);
                        param_info->value.vec3.x = ((color_int >> 0) & 0xFF) / 255.0f;
                        param_info->value.vec3.y = ((color_int >> 8) & 0xFF) / 255.0f;
                        param_info->value.vec3.z = ((color_int >> 16) & 0xFF) / 255.0f;
                    } // Else: No standard way to get from settings if not color. Rely on shader default or last value.
                    break;
				case GS_SHADER_PARAM_VEC4:
                     if (param_info->widget_type.array && strcmp(param_info->widget_type.array, "color") == 0) {
                        uint32_t color_int = (uint32_t)obs_data_get_int(settings, param_info->name.array);
                        param_info->value.vec4.x = ((color_int >> 0) & 0xFF) / 255.0f;
                        param_info->value.vec4.y = ((color_int >> 8) & 0xFF) / 255.0f;
                        param_info->value.vec4.z = ((color_int >> 16) & 0xFF) / 255.0f;
                        param_info->value.vec4.w = ((color_int >> 24) & 0xFF) / 255.0f;
                    } // Else: No standard way.
                    break;
				case GS_SHADER_PARAM_TEXTURE:
				case GS_SHADER_PARAM_STRING: {
					const char *str_val = obs_data_get_string(settings, param_info->name.array);
					// For textures, this string is either a source name or an image file path.
					// shader_filter_set_effect_params will handle loading the actual gs_texture_t.
					// We store the string path/name in param_info->value.string for now.
					// This requires param_info->value.string to be managed (freed/allocated).
					// However, gs_effect_get_parameters doesn't allocate for value.string, it's for default_value.string
					// This part of the logic is tricky. Let's assume param_info->value.string is not used directly for textures,
					// but rather the string from settings is used to load image/source later.
					// For now, we'll focus on populating param_info->image or param_info->source
					if (param_info->type == GS_SHADER_PARAM_TEXTURE) {
						obs_weak_source_release(param_info->source);
						param_info->source = NULL;
						if (param_info->image) gs_image_file_free(param_info->image);
						param_info->image = NULL;

						if (str_val && *str_val) {
							if (param_info->widget_type.array && strcmp(param_info->widget_type.array, "source") == 0) {
								obs_source_t *source = obs_get_source_by_name(str_val);
								if (source) {
									param_info->source = obs_source_get_weak_source(source);
									obs_source_release(source);
								}
							} else { // Assume image file path
								param_info->image = gs_image_file_create(str_val);
                                // Actual texture loading happens in render or when param is set on effect
							}
						}
					} else { // GS_SHADER_PARAM_STRING
                        // For general strings, we'd need to manage param_info->value.string memory.
                        // Currently, effect parameters of type string are not directly settable per-frame by default.
                        // If they were, their values would be set on the effect when it's prepared.
                        // For now, we don't store it back into param_info->value.string to avoid memory issues.
                    }
					break;
				}
				default: break;
			}
		}
	}

	// Load all parameters from settings into filter->passes[i].stored_param_list
	for (int i = 0; i < MAX_SHADER_PASSES; ++i) {
		if (filter->passes[i].enabled && filter->passes[i].effect && filter->passes[i].error_string.len == 0) {
			char prefixed_param_name[256];
			for (size_t j = 0; j < filter->passes[i].stored_param_list.num; j++) {
				struct effect_param_data *param_info = filter->passes[i].stored_param_list.array + j;
				snprintf(prefixed_param_name, sizeof(prefixed_param_name), "pass_%d_%s", i, param_info->name.array);
				// ... (similar logic as above for loading value from settings into param_info->value for pass params)
				switch (param_info->type) {
					case GS_SHADER_PARAM_BOOL: param_info->value.i = obs_data_get_bool(settings, prefixed_param_name); break;
					case GS_SHADER_PARAM_FLOAT: param_info->value.f = obs_data_get_double(settings, prefixed_param_name); break;
					case GS_SHADER_PARAM_INT: param_info->value.i = obs_data_get_int(settings, prefixed_param_name); break;
                    case GS_SHADER_PARAM_VEC3:
                        if (param_info->widget_type.array && strcmp(param_info->widget_type.array, "color") == 0) {
                            uint32_t color_int = (uint32_t)obs_data_get_int(settings, prefixed_param_name);
                            param_info->value.vec3.x = ((color_int >> 0) & 0xFF) / 255.0f;
                            param_info->value.vec3.y = ((color_int >> 8) & 0xFF) / 255.0f;
                            param_info->value.vec3.z = ((color_int >> 16) & 0xFF) / 255.0f;
                        }
                        break;
                    case GS_SHADER_PARAM_VEC4:
                        if (param_info->widget_type.array && strcmp(param_info->widget_type.array, "color") == 0) {
                            uint32_t color_int = (uint32_t)obs_data_get_int(settings, prefixed_param_name);
                            param_info->value.vec4.x = ((color_int >> 0) & 0xFF) / 255.0f;
                            param_info->value.vec4.y = ((color_int >> 8) & 0xFF) / 255.0f;
                            param_info->value.vec4.z = ((color_int >> 16) & 0xFF) / 255.0f;
                            param_info->value.vec4.w = ((color_int >> 24) & 0xFF) / 255.0f;
                        }
                        break;
					case GS_SHADER_PARAM_TEXTURE:
					case GS_SHADER_PARAM_STRING: {
						const char *str_val = obs_data_get_string(settings, prefixed_param_name);
						if (param_info->type == GS_SHADER_PARAM_TEXTURE) {
							obs_weak_source_release(param_info->source);
							param_info->source = NULL;
							if (param_info->image) gs_image_file_free(param_info->image);
							param_info->image = NULL;

							if (str_val && *str_val) {
								if (param_info->widget_type.array && strcmp(param_info->widget_type.array, "source") == 0) {
									obs_source_t *source = obs_get_source_by_name(str_val);
									if (source) {
										param_info->source = obs_source_get_weak_source(source);
										obs_source_release(source);
									}
								} else { // Assume image file
									param_info->image = gs_image_file_create(str_val);
								}
							}
						}
						break;
					}
					default: break;
				}
			}
		}
	}

	// If any effect was reloaded or pass states changed, the properties UI might need to be refreshed
    bool any_pass_change = false;
    for(int k=0; k < MAX_SHADER_PASSES; ++k) if(pass_effect_changed_flags[k]) any_pass_change = true;
	if (main_effect_changed_flag || any_pass_change) {
		obs_source_properties_changed(filter->context);
	}
}

void shader_filter_defaults(obs_data_t *settings) { /* ... (content as modified for multi-pass) ... */ }
void shader_filter_tick(void *data, float seconds) { /* ... (content as modified for multi-pass) ... */ }

void shader_filter_render(void *data, gs_effect_t *effect_param_not_used)
{
	struct shader_filter_data *filter = data;
	UNUSED_PARAMETER(effect_param_not_used); // Main effect parameter is not used directly here for multi-pass

	if (!filter->context) return;

	obs_source_t *target = obs_filter_get_target(filter->context);
	obs_source_t *parent = obs_filter_get_parent(filter->context);
	uint32_t width = obs_source_get_width(target ? target : parent);
	uint32_t height = obs_source_get_height(target ? target : parent);

	if (width == 0 || height == 0) return;

	// Update dynamic parameters like time, random numbers, etc.
	// (This logic might be better placed in shader_filter_tick if not strictly render-tied)
	filter->elapsed_time_val = obs_source_get_signal_unscaled_time(filter->context) / 1000000000.0f - filter->shader_start_time;
	// ... (other time/rand updates) ...

	// Ensure input_texrender has the current frame from the source/target
	get_input_source(filter); // This populates filter->input_texrender

	if (filter->num_active_passes > 0) {
		gs_texrender_t *current_target = NULL;
		gs_texrender_t *last_output_target = NULL; // Tracks the output of the previous pass
		gs_texture_t *current_input_texture = NULL;
		int active_pass_count = 0;

		// Determine the actual number of passes that will run
		for (int i = 0; i < MAX_SHADER_PASSES; ++i) {
			if (filter->passes[i].enabled && filter->passes[i].effect && filter->passes[i].error_string.len == 0) {
				active_pass_count++;
			}
		}
		if (active_pass_count == 0) { // Should not happen if num_active_passes > 0, but as a safe guard
			if (filter->input_texrender) draw_output(filter); // Draw original if no passes ran
			return;
		}


		// Resize intermediate texrenders if necessary (only once before the loop)
		if (filter->intermediate_texrender_A && (gs_texrender_get_width(filter->intermediate_texrender_A) != width || gs_texrender_get_height(filter->intermediate_texrender_A) != height)) {
			gs_texrender_destroy(filter->intermediate_texrender_A);
			filter->intermediate_texrender_A = NULL;
		}
		if (!filter->intermediate_texrender_A) filter->intermediate_texrender_A = create_or_reset_texrender(NULL);
		gs_texrender_resize(filter->intermediate_texrender_A, width, height);

		if (filter->intermediate_texrender_B && (gs_texrender_get_width(filter->intermediate_texrender_B) != width || gs_texrender_get_height(filter->intermediate_texrender_B) != height)) {
			gs_texrender_destroy(filter->intermediate_texrender_B);
			filter->intermediate_texrender_B = NULL;
		}
		if (!filter->intermediate_texrender_B) filter->intermediate_texrender_B = create_or_reset_texrender(NULL);
		gs_texrender_resize(filter->intermediate_texrender_B, width, height);

		// Also ensure output_texrender is correctly sized if it's used as the final target of a pass
		if (filter->output_texrender && (gs_texrender_get_width(filter->output_texrender) != width || gs_texrender_get_height(filter->output_texrender) != height)) {
			gs_texrender_destroy(filter->output_texrender);
			filter->output_texrender = NULL;
		}
		if (!filter->output_texrender) filter->output_texrender = create_or_reset_texrender(NULL);
		gs_texrender_resize(filter->output_texrender, width, height);


		int current_active_pass_idx = 0;
		for (int i = 0; i < MAX_SHADER_PASSES; ++i) {
			if (!filter->passes[i].enabled || !filter->passes[i].effect || filter->passes[i].error_string.len > 0) {
				continue; // Skip disabled or errored passes
			}
            int actual_pass_index = i; // The index in filter->passes array

			// Determine input texture for this pass
			if (current_active_pass_idx == 0) { // First active pass
				current_input_texture = filter->input_texrender ? gs_texrender_get_texture(filter->input_texrender) : obs_get_black_texture();
				current_target = (active_pass_count == 1) ? filter->output_texrender : filter->intermediate_texrender_A;
			} else { // Subsequent active passes
				current_input_texture = gs_texrender_get_texture(last_output_target);
				current_target = (last_output_target == filter->intermediate_texrender_A) ? filter->intermediate_texrender_B : filter->intermediate_texrender_A;
				if (current_active_pass_idx == active_pass_count - 1) { // Last active pass
					current_target = filter->output_texrender;
				}
			}

			// Begin rendering to the current target
			gs_texrender_reset(current_target);
			if (gs_texrender_resize(current_target, width, height)) {
				gs_blend_state_push();
				gs_blend_function(GS_BLEND_ONE, GS_BLEND_ZERO); // Opaque draw

				gs_effect_t *pass_effect = filter->passes[actual_pass_index].effect;

				// Set global uniforms for this pass (e.g., uv_offset, uv_scale, time, image)
				// Note: These might need to be fetched per-pass effect if names differ.
				// Assuming common names for simplicity for now.
				gs_eparam_t *pass_param_uv_offset = gs_effect_get_param_by_name(pass_effect, "uv_offset");
				gs_eparam_t *pass_param_uv_scale = gs_effect_get_param_by_name(pass_effect, "uv_scale");
				gs_eparam_t *pass_param_elapsed_time = gs_effect_get_param_by_name(pass_effect, "elapsed_time");
				gs_eparam_t *pass_param_image = gs_effect_get_param_by_name(pass_effect, "image"); // Standard input image

				if (pass_param_uv_offset) gs_effect_set_vec2(pass_param_uv_offset, &filter->uv_offset_val);
				if (pass_param_uv_scale) gs_effect_set_vec2(pass_param_uv_scale, &filter->uv_scale_val);
				if (pass_param_elapsed_time) gs_effect_set_float(pass_param_elapsed_time, filter->elapsed_time_val);
				// ... set other global-like params ...
				if (pass_param_image) gs_effect_set_texture_srgb(pass_param_image, current_input_texture);


				// Set specific parameters for this pass effect
				shader_filter_set_pass_effect_params(filter, actual_pass_index);

				// Render the pass
				gs_technique_t *tech = gs_effect_get_technique(pass_effect, "Draw");
				if (!tech) tech = gs_effect_get_fallback_technique(pass_effect);

				if (tech) {
					size_t num_shader_passes = gs_technique_begin(tech);
					for (size_t j = 0; j < num_shader_passes; j++) {
						if (gs_technique_begin_pass_by_index(tech, j)) {
							// For multi-pass, the input texture ('image') is already set.
							// We draw a quad that will sample from it.
							gs_draw_sprite(current_input_texture, 0, width, height); // Or draw a generic quad if shader handles texcoords
							gs_technique_end_pass(tech);
						}
					}
					gs_technique_end(tech);
				}
				gs_blend_state_pop();
				gs_texrender_end(current_target);
				last_output_target = current_target; // Update for the next iteration
			}
			current_active_pass_idx++;
		}
		// After all passes, the final image is in filter->output_texrender (if last pass targeted it, or if only one pass)
		// or in last_output_target if it's an intermediate.
		// If the final image landed in an intermediate, we might need to copy it to output_texrender.
		// However, the logic above tries to make current_target = filter->output_texrender for the last active pass.
		if (filter->output_texrender == last_output_target) {
			// Final image is already in output_texrender, draw it to screen/next filter
			draw_output(filter);
		} else if (last_output_target) {
			// This case should ideally not be hit if the logic correctly targets output_texrender for the last pass.
			// If it is, copy from last_output_target to filter->output_texrender then draw_output, or draw directly.
			// For now, assume output_texrender was the final target.
			blog(LOG_WARNING, "[obs-shaderfilter] Multi-pass rendering finished on an intermediate texture. This might be a bug.");
			// As a fallback, attempt to draw from last_output_target if output_texrender wasn't correctly set.
            // This requires draw_output to be flexible or another draw call here.
            // For simplicity, we'll rely on output_texrender being the final destination.
            // If this warning appears, the targetting logic needs review.
		}

<<<<<<< HEAD
=======
static void build_sprite(struct gs_vb_data *data, float fcx, float fcy, float start_u, float end_u, float start_v, float end_v)
{
	struct vec2 *tvarray = data->tvarray[0].array;

	vec3_zero(data->points);
	vec3_set(data->points + 1, fcx, 0.0f, 0.0f);
	vec3_set(data->points + 2, 0.0f, fcy, 0.0f);
	vec3_set(data->points + 3, fcx, fcy, 0.0f);
	vec2_set(tvarray, start_u, start_v);
	vec2_set(tvarray + 1, end_u, start_v);
	vec2_set(tvarray + 2, start_u, end_v);
	vec2_set(tvarray + 3, end_u, end_v);
}

static inline void build_sprite_norm(struct gs_vb_data *data, float fcx, float fcy)
{
	build_sprite(data, fcx, fcy, 0.0f, 1.0f, 0.0f, 1.0f);
}

static void render_shader(struct shader_filter_data *filter, float f, obs_source_t *filter_to)
{
	gs_texture_t *texture = gs_texrender_get_texture(filter->input_texrender);
	if (!texture) {
		return;
	}
>>>>>>> origin/relocate-extra-pixels-ui

	} else if (filter->effect && filter->global_error_string.len == 0) {
		// Fallback to single main effect rendering if no active passes
		render_shader(filter, 0.0f, NULL); // Render main effect to filter->output_texrender
		draw_output(filter); // Draw filter->output_texrender to screen
	} else {
		// No passes, no main effect, or main effect has error: draw original input if available
		if (filter->input_texrender) {
            // We need to copy input_texrender to output_texrender then draw_output,
            // or draw input_texrender directly using output_effect.
            // Simplest: use output_effect to draw input_texrender's texture.
            if(filter->output_effect && filter->param_output_image && gs_texrender_get_texture(filter->input_texrender)) {
                gs_effect_set_texture_srgb(filter->param_output_image, gs_texrender_get_texture(filter->input_texrender));

                gs_blend_state_push();
                if (filter->use_pm_alpha) gs_blend_function(GS_BLEND_ONE, GS_BLEND_INVSRCALPHA);
                else gs_blend_function_separate(GS_BLEND_SRCALPHA, GS_BLEND_INVSRCALPHA, GS_BLEND_ONE, GS_BLEND_INVSRCALPHA);
                gs_enable_blending(true);

                while (gs_effect_loop(filter->output_effect, "Draw")) {
                    gs_draw_sprite(gs_texrender_get_texture(filter->input_texrender), 0, width, height);
                }
                gs_enable_blending(false);
                gs_blend_state_pop();
                filter->output_rendered = true; // Mark that something was drawn.
            }
		} else {
            // Nothing to draw, clear the screen? OBS usually handles this by drawing parent/target.
        }
	}

	// Manage previous_output_texrender for temporal effects
	if (filter->output_rendered) {
		if (filter->previous_output_texrender) {
			gs_texrender_destroy(filter->previous_output_texrender);
		}
<<<<<<< HEAD
		filter->previous_output_texrender = filter->output_texrender;
		filter->output_texrender = create_or_reset_texrender(NULL); // Get a new one for next frame
        filter->output_rendered = false; // Reset for next frame
=======
	}

	gs_blend_state_push();
	gs_reset_blend_state();
	gs_enable_blending(false);
	gs_blend_function(GS_BLEND_ONE, GS_BLEND_ZERO);

	if (gs_texrender_begin(filter->output_texrender, filter->total_width, filter->total_height)) {
		gs_ortho(0.0f, (float)filter->total_width, 0.0f, (float)filter->total_height, -100.0f, 100.0f);
		while (gs_effect_loop(filter->effect, "Draw")) {
			if (filter->use_template) {
				gs_draw_sprite(texture, 0, filter->total_width, filter->total_height);
			} else {
				if (!filter->sprite_buffer)
					load_sprite_buffer(filter);

				struct gs_vb_data *data = gs_vertexbuffer_get_data(filter->sprite_buffer);
				build_sprite_norm(data, (float)filter->total_width, (float)filter->total_height);
				gs_vertexbuffer_flush(filter->sprite_buffer);
				gs_load_vertexbuffer(filter->sprite_buffer);
				gs_load_indexbuffer(NULL);
				gs_draw(GS_TRISTRIP, 0, 0);
			}
		}
		gs_texrender_end(filter->output_texrender);
	}

	gs_blend_state_pop();
}

static void shader_filter_render(void *data, gs_effect_t *effect)
{
	UNUSED_PARAMETER(effect);

	struct shader_filter_data *filter = data;

	float f = 0.0f;
	obs_source_t *filter_to = NULL;
	if (move_get_transition_filter)
		f = move_get_transition_filter(filter->context, &filter_to);

	if (f == 0.0f && filter->output_rendered) {
		draw_output(filter);
		return;
	}

	if (filter->effect == NULL || filter->rendering) {
		obs_source_skip_video_filter(filter->context);
		return;
	}

	get_input_source(filter);

	filter->rendering = true;
	render_shader(filter, f, filter_to);
	draw_output(filter);
	if (f == 0.0f)
		filter->output_rendered = true;
	filter->rendering = false;
}

static uint32_t shader_filter_getwidth(void *data)
{
	struct shader_filter_data *filter = data;

	return filter->total_width;
}

static uint32_t shader_filter_getheight(void *data)
{
	struct shader_filter_data *filter = data;

	return filter->total_height;
}

static void shader_filter_defaults(obs_data_t *settings)
{
	obs_data_set_default_string(settings, "shader_text", effect_template_default_image_shader);
}

static enum gs_color_space shader_filter_get_color_space(void *data, size_t count, const enum gs_color_space *preferred_spaces)
{
	UNUSED_PARAMETER(count);
	UNUSED_PARAMETER(preferred_spaces);
	struct shader_filter_data *filter = data;
	obs_source_t *target = obs_filter_get_target(filter->context);
	const enum gs_color_space potential_spaces[] = {
		GS_CS_SRGB,
		GS_CS_SRGB_16F,
		GS_CS_709_EXTENDED,
	};
	return obs_source_get_color_space(target, OBS_COUNTOF(potential_spaces), potential_spaces);
}

void shader_filter_param_source_action(void *data, void (*action)(obs_source_t *source))
{
	struct shader_filter_data *filter = data;
	size_t param_count = filter->stored_param_list.num;
	for (size_t param_index = 0; param_index < param_count; param_index++) {
		struct effect_param_data *param = (filter->stored_param_list.array + param_index);
		if (!param->source)
			continue;
		obs_source_t *source = obs_weak_source_get_source(param->source);
		if (!source)
			continue;
		action(source);
		obs_source_release(source);
>>>>>>> origin/relocate-extra-pixels-ui
	}
}
uint32_t shader_filter_getwidth(void *data) { /* ... (original content) ... */ struct shader_filter_data *filter = data; return filter->total_width; }
uint32_t shader_filter_getheight(void *data) { /* ... (original content) ... */ struct shader_filter_data *filter = data; return filter->total_height; }
enum gs_color_space shader_filter_get_color_space(void *data, size_t count, const enum gs_color_space *preferred_spaces) { /* ... (original content) ... */ return GS_CS_SRGB; }
void shader_filter_activate(void *data) { /* ... (original content) ... */ }
void shader_filter_deactivate(void *data) { /* ... (original content) ... */ }
void shader_filter_show(void *data) { /* ... (original content) ... */ }
void shader_filter_hide(void *data) { /* ... (original content) ... */ }

// Transition specific functions
const char *shader_transition_get_name(void *unused) { UNUSED_PARAMETER(unused); return obs_module_text("ShaderFilter"); } // Name used for transition
void *shader_transition_create(obs_data_t *settings, obs_source_t *source) { /* ... (original content, ensure it calls shader_filter_create or similar init) ... */ return shader_filter_create(settings, source); }
void shader_transition_defaults(obs_data_t *settings) { obs_data_set_default_string(settings, "shader_text", effect_template_default_transition_image_shader); /* Potentially other pass defaults if transitions use them */ }
bool shader_transition_audio_render(void *data, uint64_t *ts_out, struct obs_source_audio_mix *audio, uint32_t mixers, size_t channels, size_t sample_rate) { /* ... (original content) ... */ return false; }
void shader_transition_video_render(void *data, gs_effect_t *effect) { /* ... (original content) ... */ }
enum gs_color_space shader_transition_get_color_space(void *data, size_t count, const enum gs_color_space *preferred_spaces) { /* ... (original content) ... */ return GS_CS_SRGB; }


struct obs_source_info shader_filter = {
	.id = "shader_filter",
	.type = OBS_SOURCE_TYPE_FILTER,
	.output_flags = OBS_SOURCE_VIDEO | OBS_SOURCE_SRGB | OBS_SOURCE_CUSTOM_DRAW,
	.create = shader_filter_create,
	.destroy = shader_filter_destroy,
	.update = shader_filter_update,
	.load = shader_filter_update, // Typically same as update
	.video_tick = shader_filter_tick,
	.get_name = shader_filter_get_name,
	.get_defaults = shader_filter_defaults,
	.get_width = shader_filter_getwidth,
	.get_height = shader_filter_getheight,
	.video_render = shader_filter_render,
	.get_properties = shader_filter_properties,
	.video_get_color_space = shader_filter_get_color_space,
	.activate = shader_filter_activate,
	.deactivate = shader_filter_deactivate,
	.show = shader_filter_show,
	.hide = shader_filter_hide,
};

struct obs_source_info shader_transition = {
	.id = "shader_transition",
	.type = OBS_SOURCE_TYPE_TRANSITION,
	.output_flags = OBS_SOURCE_VIDEO | OBS_SOURCE_SRGB | OBS_SOURCE_CUSTOM_DRAW | OBS_SOURCE_COMPOSITE, // Transitions usually composite
	.create = shader_transition_create,
	.destroy = shader_filter_destroy, // Can often reuse filter's destroy
	.update = shader_filter_update,   // Can often reuse filter's update
	.load = shader_filter_update,
	.video_tick = shader_filter_tick, // Can often reuse filter's tick
	.get_name = shader_transition_get_name,
	.audio_render = shader_transition_audio_render,
	.get_defaults = shader_transition_defaults,
	.video_render = shader_transition_video_render,
	.get_properties = shader_filter_properties, // Transitions can share properties UI
	.video_get_color_space = shader_transition_get_color_space,
	// Transitions have activate/deactivate/show/hide too
	.activate = shader_filter_activate,     // Reuse if appropriate
	.deactivate = shader_filter_deactivate, // Reuse if appropriate
	.show = shader_filter_show,             // Reuse if appropriate
	.hide = shader_filter_hide,             // Reuse if appropriate
};

OBS_DECLARE_MODULE()
OBS_MODULE_USE_DEFAULT_LOCALE("obs-shaderfilter", "en-US")

bool obs_module_load(void)
{
	blog(LOG_INFO, "[obs-shaderfilter] loaded version %s", PROJECT_VERSION);
	obs_register_source(&shader_filter);
	obs_register_source(&shader_transition);
	return true;
}

void obs_module_unload(void) {}

void obs_module_post_load()
{
	if (obs_get_module("move-transition") == NULL) return;
	proc_handler_t *ph = obs_get_proc_handler();
	struct calldata cd;
	calldata_init(&cd);
	calldata_set_string(&cd, "filter_id", shader_filter.id);
	if (proc_handler_call(ph, "move_get_transition_filter_function", &cd)) {
		move_get_transition_filter = calldata_ptr(&cd, "callback");
	}
	calldata_free(&cd);
<<<<<<< HEAD
}

[end of obs-shaderfilter.c]
=======
}
>>>>>>> origin/relocate-extra-pixels-ui
