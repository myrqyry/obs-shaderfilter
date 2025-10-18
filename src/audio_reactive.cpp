#include "audio_reactive.hpp"
#include "shader_filter.hpp"

#include <obs-module.h>
#include <media-io/audio-io.h>
#include <util/circlebuf.h>
#include <cmath>
#include <obs-enum-sources.h>

#ifdef USE_FFTW
#include <fftw3.h>
#endif

namespace audio_reactive {

struct audio_capture_data {
#ifdef USE_FFTW
    fftwf_plan fft_plan;
    float *input_buffer;
    fftwf_complex *output_buffer;
#endif
    size_t buffer_size;
    struct circlebuf audio_buffer;
};

static void audio_capture_callback(void *param, obs_source_t *source,
                                   const struct audio_data *audio_data,
                                   bool muted)
{
    UNUSED_PARAMETER(source);
    UNUSED_PARAMETER(muted);

    audio_capture_data *capture = (audio_capture_data*)param;
    circlebuf_push_back(&capture->audio_buffer, audio_data->data[0], audio_data->frames * sizeof(float));
}

void add_properties(obs_properties_t *props, void *data)
{
    UNUSED_PARAMETER(data);

    obs_properties_t *audio_group = obs_properties_create();
    obs_properties_add_group(props,
        "audio_reactive",
        obs_module_text("AudioReactive"),
        OBS_GROUP_CHECKABLE,
        audio_group);

    obs_property_t *audio_source = obs_properties_add_list(audio_group,
        "audio_source",
        obs_module_text("AudioSource"),
        OBS_COMBO_TYPE_LIST,
        OBS_COMBO_FORMAT_STRING);

    obs_property_list_add_string(audio_source, obs_module_text("None"), "");

    obs_enum_sources([](void *param, obs_source_t *source) {
        obs_property_t *list = (obs_property_t*)param;
        uint32_t caps = obs_source_get_output_flags(source);
        if ((caps & OBS_SOURCE_AUDIO) != 0) {
            const char *name = obs_source_get_name(source);
            obs_property_list_add_string(list, name, name);
        }
        return true;
    }, audio_source);

    obs_properties_add_int_slider(audio_group,
        "spectrum_bands",
        obs_module_text("SpectrumBands"),
        8, 256, 8);

    obs_properties_add_bool(audio_group,
        "audio_reactive_enabled",
        obs_module_text("AudioReactivityEnabled"));
}

void set_defaults(obs_data_t *settings)
{
    obs_data_set_default_string(settings, "audio_source", "");
    obs_data_set_default_int(settings, "spectrum_bands", 64);
    obs_data_set_default_bool(settings, "audio_reactive_enabled", false);
}

void update_settings(void *filter_data, obs_data_t *settings)
{
    shader_filter::filter_data *filter = static_cast<shader_filter::filter_data*>(filter_data);

    filter->spectrum_bands = (int)obs_data_get_int(settings, "spectrum_bands");
    filter->audio_reactive_enabled = obs_data_get_bool(settings, "audio_reactive_enabled");

    const char* audio_source_name = obs_data_get_string(settings, "audio_source");

    if (filter->audio_source) {
        obs_source_t *source = obs_weak_source_get_source(filter->audio_source);
        if(source) {
            obs_source_remove_audio_capture_callback(source, audio_capture_callback, filter->audio_capture);
            obs_source_release(source);
        }
        obs_weak_source_release(filter->audio_source);
        filter->audio_source = nullptr;
    }

    if (audio_source_name && *audio_source_name && filter->audio_reactive_enabled) {
        obs_source_t* source = obs_get_source_by_name(audio_source_name);
        if (source) {
            filter->audio_source = obs_source_get_weak_source(source);
            if (!filter->audio_capture) {
                filter->audio_capture = new audio_capture_data();
                filter->audio_capture->buffer_size = obs_source_get_audio_mix_buffer_size(source);
                circlebuf_init(&filter->audio_capture->audio_buffer);
#ifdef USE_FFTW
                filter->audio_capture->input_buffer = (float*)fftwf_malloc(sizeof(float) * filter->audio_capture->buffer_size);
                filter->audio_capture->output_buffer = (fftwf_complex*)fftwf_malloc(sizeof(fftwf_complex) * (filter->audio_capture->buffer_size/2 + 1));
                filter->audio_capture->fft_plan = fftwf_plan_dft_r2c_1d(filter->audio_capture->buffer_size, filter->audio_capture->input_buffer, filter->audio_capture->output_buffer, FFTW_MEASURE);
#endif
            }
            obs_source_add_audio_capture_callback(source, audio_capture_callback, filter->audio_capture);
            obs_source_release(source);
        }
    }
}

void bind_audio_data(void *filter_data, gs_effect_t *effect)
{
    shader_filter::filter_data *filter = static_cast<shader_filter::filter_data*>(filter_data);

    if (filter->audio_reactive_enabled && filter->audio_capture) {
#ifdef USE_FFTW
        circlebuf_peek_front(&filter->audio_capture->audio_buffer, filter->audio_capture->input_buffer, filter->audio_capture->buffer_size * sizeof(float));
        fftwf_execute(filter->audio_capture->fft_plan);

        for (int i = 0; i < filter->spectrum_bands; i++) {
            float real = filter->audio_capture->output_buffer[i][0];
            float imag = filter->audio_capture->output_buffer[i][1];
            filter->audio_spectrum[i] = sqrtf(real * real + imag * imag);
        }
#else
        // Simulate some audio data for now
        for (int i = 0; i < filter->spectrum_bands; ++i) {
            filter->audio_spectrum[i] = (float)sin(obs_get_video_frame_time() / 100000000.0 + i) * 0.5f + 0.5f;
        }
#endif

        gs_eparam_t *param_spectrum = gs_effect_get_param_by_name(effect, "audio_spectrum");
        if (param_spectrum) {
            gs_effect_set_val(param_spectrum, filter->audio_spectrum,
                             sizeof(float) * filter->spectrum_bands);
        }

        gs_eparam_t *param_bands = gs_effect_get_param_by_name(effect, "spectrum_bands");
        if (param_bands) {
            gs_effect_set_int(param_bands, filter->spectrum_bands);
        }
    }
}

} // namespace audio_reactive