#define _USE_MATH_DEFINES
#include <cmath>

#include "audio_reactive.hpp"
#include "shader_filter_data.hpp"

#include <obs/obs-module.h>
#include <obs/media-io/audio-io.h>
#include <obs/util/circlebuf.h>
#include <cmath>
#include <vector>
#include <atomic>
#include <obs/obs-enum-sources.h>
#include <thread>

#ifdef USE_FFTW
#include <fftw3.h>
#endif

namespace audio_reactive {

struct audio_capture_data {
    size_t samples_per_frame;
    std::vector<float> hanning_window;
    fftwf_plan fft_plan = nullptr;
    std::vector<float> input_buffer;
    std::vector<fftwf_complex> output_buffer;
    struct circlebuf audio_buffer;
    std::atomic<bool> data_ready;
    std::atomic<bool> callback_active;

    audio_capture_data(size_t size)
        : samples_per_frame(size),
          hanning_window(size),
          input_buffer(size),
          output_buffer(size / 2 + 1),
          data_ready(false)
    {
        circlebuf_init(&audio_buffer);
        circlebuf_reserve(&audio_buffer, size * sizeof(float) * 4);

        for (size_t i = 0; i < size; ++i) {
            hanning_window[i] = 0.5f * (1.0f - cosf(2.0f * (float)M_PI * i / (size - 1)));
        }

#ifdef USE_FFTW
        fft_plan = fftwf_plan_dft_r2c_1d(
            static_cast<int>(size),
            input_buffer.data(),
            output_buffer.data(),
            FFTW_MEASURE
        );
#endif
    }

    ~audio_capture_data()
    {
#ifdef USE_FFTW
        if (fft_plan) {
            fftwf_destroy_plan(fft_plan);
        }
#endif
        circlebuf_free(&audio_buffer);
    }
};

static void audio_capture_callback(void *param, obs_source_t *source,
                                   const struct audio_data *audio_data,
                                   bool muted)
{
    auto *capture = static_cast<audio_capture_data*>(param);
    if (!capture) {
        return;
    }

    capture->callback_active = true;

    UNUSED_PARAMETER(source);

    if (muted || !audio_data || audio_data->frames == 0) {
        capture->callback_active = false;
        return;
    }

    circlebuf_push_back(&capture->audio_buffer,
                      audio_data->data[0],
                      audio_data->frames * sizeof(float));
    capture->data_ready = true;
    capture->callback_active = false;
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
        obs_module_text("Spectrum Bands"),
        8, 256, 8);

    obs_properties_add_float_slider(audio_group,
        "audio_reactivity",
        obs_module_text("Reactivity Strength"),
        0.0, 2.0, 0.1);

    obs_properties_add_float_slider(audio_group,
        "audio_gain",
        obs_module_text("AudioGain"),
        1.0, 10.0, 0.1);

    obs_properties_add_float_slider(audio_group,
        "audio_attack",
        obs_module_text("AudioAttack"),
        0.01, 1.0, 0.01);

    obs_properties_add_float_slider(audio_group,
        "audio_release",
        obs_module_text("AudioRelease"),
        0.01, 1.0, 0.01);
}

void set_defaults(obs_data_t *settings)
{
    obs_data_set_default_string(settings, "audio_source", "");
    obs_data_set_default_int(settings, "spectrum_bands", 128);
    obs_data_set_default_double(settings, "audio_reactivity", 1.0);
    obs_data_set_default_bool(settings, "audio_reactive", false);
    obs_data_set_default_double(settings, "audio_gain", 1.0);
    obs_data_set_default_double(settings, "audio_attack", 0.5);
    obs_data_set_default_double(settings, "audio_release", 0.3);
}

void update_settings(void *filter_data, obs_data_t *settings)
{
    auto *filter = static_cast<shader_filter::filter_data*>(filter_data);

    filter->spectrum_bands = (int)obs_data_get_int(settings, "spectrum_bands");
    filter->audio_reactivity_strength = (float)obs_data_get_double(settings, "audio_reactivity");
    filter->audio_reactive_enabled = obs_data_get_bool(settings, "audio_reactive");
    filter->audio_gain = (float)obs_data_get_double(settings, "audio_gain");
    filter->audio_attack = (float)obs_data_get_double(settings, "audio_attack");
    filter->audio_release = (float)obs_data_get_double(settings, "audio_release");

    const char* audio_source_name = obs_data_get_string(settings, "audio_source");

    // --- Teardown ---
    auto* old_capture = filter->audio_capture;
    filter->audio_capture = nullptr; // Clear pointer first

    if (filter->audio_source) {
        obs_source_t *source = obs_weak_source_get_source(filter->audio_source);
        if (source) {
            obs_source_remove_audio_capture_callback(source, audio_capture_callback, old_capture);
            obs_source_release(source);
        }
        obs_weak_source_release(filter->audio_source);
        filter->audio_source = nullptr;
    }

    if (old_capture) {
        // Spin-wait until the callback is no longer active
        while (old_capture->callback_active) {
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
        delete old_capture;
    }

    // --- Setup ---
    if (audio_source_name && *audio_source_name && filter->audio_reactive_enabled) {
        obs_source_t* source = obs_get_source_by_name(audio_source_name);
        if (source) {
            filter->audio_source = obs_source_get_weak_source(source);

            // Older/newer OBS APIs expose audio capture via callbacks; instead of
            // depending on a specific audio_io_t API we fall back to the
            // configured audio output block size constant.
            // AUDIO_OUTPUT_FRAMES is defined in audio-io.h and is a safe default.
            size_t mix_buffer_size = AUDIO_OUTPUT_FRAMES;
            filter->audio_capture = new audio_capture_data(mix_buffer_size);
            obs_source_add_audio_capture_callback(source, audio_capture_callback, filter->audio_capture);
            obs_source_release(source);
        }
    }
}

void bind_audio_data(void *filter_data, gs_effect_t *effect)
{
    auto *filter = static_cast<shader_filter::filter_data*>(filter_data);

    if (!filter->audio_reactive_enabled || !filter->audio_capture || !filter->audio_capture->data_ready) {
        return;
    }

    auto *capture = filter->audio_capture;
    size_t buffer_size = capture->samples_per_frame;

    if (capture->audio_buffer.size >= buffer_size * sizeof(float)) {
        circlebuf_read(&capture->audio_buffer, capture->input_buffer.data(), buffer_size * sizeof(float));

        for (size_t i = 0; i < buffer_size; ++i) {
            capture->input_buffer[i] *= capture->hanning_window[i];
        }

#ifdef USE_FFTW
        if(capture->fft_plan) {
            fftwf_execute(capture->fft_plan);
        }
#endif

        std::fill(filter->back_buffer.begin(), filter->back_buffer.end(), 0.0f);

        // Logarithmic scaling for frequency bands
        float min_freq = 1.0f;
        float max_freq = (float)(buffer_size / 2);
        float log_min = log10f(min_freq);
        float log_max = log10f(max_freq);
        float log_range = log_max - log_min;

        // Use back_buffer as a temporary store for the raw spectrum
        for (int i = 0; i < (buffer_size / 2); ++i) {
            float real = capture->output_buffer[i][0];
            float imag = capture->output_buffer[i][1];
            float magnitude = sqrtf(real * real + imag * imag);

            float freq = (float)i;
            if (freq < min_freq) continue;

            int band = (int)((log10f(freq) - log_min) / log_range * (filter->spectrum_bands - 1));
            if (band >= 0 && band < filter->spectrum_bands && band < (int)filter->back_buffer.size()) {
                filter->back_buffer[band] += magnitude;
            }
        }

        // Apply gain to raw FFT magnitudes
        for (int i = 0; i < filter->spectrum_bands; i++) {
            filter->back_buffer[i] *= filter->audio_gain;
        }

        // Apply exponential smoothing
        for (int i = 0; i < filter->spectrum_bands; i++) {
            float target = filter->back_buffer[i];
            float current = filter->smoothed_spectrum[i];

            // Use attack factor when rising, release when falling
            float factor = (target > current) ? filter->audio_attack : filter->audio_release;

            filter->smoothed_spectrum[i] = current + (target - current) * factor;
        }

        // Normalize to [0.0, 1.0] range
        float max_value = 0.0f;
        for (int i = 0; i < filter->spectrum_bands; i++) {
            if (filter->smoothed_spectrum[i] > max_value) {
                max_value = filter->smoothed_spectrum[i];
            }
        }

        if (max_value > 0.0f) {
            for (int i = 0; i < filter->spectrum_bands; i++) {
                filter->back_buffer[i] = fminf(filter->smoothed_spectrum[i] / max_value, 1.0f);
            }
        } else {
            // If max is zero, just clear the buffer to prevent stale data
            std::fill(filter->back_buffer.begin(), filter->back_buffer.end(), 0.0f);
        }

        // Swap buffers to make the new data available to the render thread
        {
            std::lock_guard<std::mutex> lock(filter->spectrum_mutex);
            filter->front_buffer.swap(filter->back_buffer);
        }
        capture->data_ready = false;
    }

    gs_eparam_t *spectrum_param = gs_effect_get_param_by_name(effect, "audio_spectrum");
    if (spectrum_param) {
        std::lock_guard<std::mutex> lock(filter->spectrum_mutex);
        /* gs_effect_set_float_array is not available in all OBS versions; use
         * the generic gs_effect_set_val to upload the float array data. */
        gs_effect_set_val(spectrum_param, filter->front_buffer.data(), sizeof(float) * filter->spectrum_bands);
    }

    gs_eparam_t *reactivity_param = gs_effect_get_param_by_name(effect, "audio_reactivity");
    if (reactivity_param) {
        gs_effect_set_float(reactivity_param, filter->audio_reactivity_strength);
    }
}

} // namespace audio_reactive

void audio_reactive::free_capture_data(void *capture)
{
    if (!capture) return;
    auto *c = static_cast<audio_capture_data*>(capture);
    delete c;
}