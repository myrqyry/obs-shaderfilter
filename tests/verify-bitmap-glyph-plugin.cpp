// Regression for file-loaded standalone Bitmap Glyph Motion via real plugin and libobs.
// Compares enabled / disabled / strength-zero render paths on a textured source.
#include <obs.h>
#include <obs-module.h>
#include <graphics/graphics.h>
#include <vector>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <thread>
#include <chrono>
#include <algorithm>

constexpr unsigned W = 256, H = 144;
using Frame = std::vector<uint8_t>;
struct Source { gs_texture_t *texture = nullptr; };

Frame fixture() {
    Frame pixels(W * H * 4);
    for (unsigned y = 0; y < H; ++y)
        for (unsigned x = 0; x < W; ++x) {
            size_t n = 4 * (y * W + x);
            bool fine = ((x / 3 + y / 8) % 2) == 0;
            pixels[n] = uint8_t(fine ? 222 : 36);
            pixels[n + 1] = uint8_t(x * 210 / W);
            pixels[n + 2] = uint8_t(fine ? 38 : 210);
            pixels[n + 3] = uint8_t(x < 15 ? 0 : 255);
        }
    return pixels;
}

const char *name(void *) { return "Bitmap glyph test fixture"; }
uint32_t width(void *) { return W; }
uint32_t height(void *) { return H; }
void *create(obs_data_t *, obs_source_t *) {
    auto *s = new Source;
    Frame f = fixture();
    const uint8_t *bytes = f.data();
    obs_enter_graphics();
    s->texture = gs_texture_create(W, H, GS_RGBA, 1, &bytes, 0);
    obs_leave_graphics();
    return s;
}
void destroy(void *ptr) {
    auto *s = static_cast<Source *>(ptr);
    obs_enter_graphics();
    gs_texture_destroy(s->texture);
    obs_leave_graphics();
    delete s;
}
void draw(void *ptr, gs_effect_t *) {
    auto *s = static_cast<Source *>(ptr);
    obs_source_draw(s->texture, 0, 0, W, H, false);
}
obs_source_info fixture_info = {
    .id = "shaderfilter_bitmap_fixture",
    .type = OBS_SOURCE_TYPE_INPUT,
    .output_flags = OBS_SOURCE_VIDEO,
    .get_name = name,
    .create = create,
    .destroy = destroy,
    .get_width = width,
    .get_height = height,
    .video_render = draw,
};

Frame render(obs_source_t *source) {
    Frame frame;
    obs_enter_graphics();
    auto *target = gs_texrender_create(GS_RGBA, GS_ZS_NONE);
    auto *stage = gs_stagesurface_create(W, H, GS_RGBA);
    if (target && stage && gs_texrender_begin(target, W, H)) {
        gs_projection_push();
        gs_matrix_push();
        gs_matrix_identity();
        gs_ortho(0, float(W), 0, float(H), -100, 100);
        obs_source_video_render(source);
        gs_matrix_pop();
        gs_projection_pop();
        gs_texrender_end(target);
        if (auto *out = gs_texrender_get_texture(target)) {
            gs_stage_texture(stage, out);
            uint8_t *bytes = nullptr;
            uint32_t stride = 0;
            if (gs_stagesurface_map(stage, &bytes, &stride)) {
                frame.resize(W * H * 4);
                for (unsigned y = 0; y < H; ++y)
                    std::memcpy(frame.data() + y * W * 4, bytes + y * stride, W * 4);
                gs_stagesurface_unmap(stage);
            }
        }
    }
    if (stage) gs_stagesurface_destroy(stage);
    if (target) gs_texrender_destroy(target);
    obs_leave_graphics();
    return frame;
}

size_t delta(const Frame &a, const Frame &b, int channel_start, int channel_end) {
    if (a.size() != b.size() || a.empty()) return SIZE_MAX;
    size_t count = 0;
    for (size_t i = 0; i < a.size(); i += 4)
        for (int ch = channel_start; ch < channel_end; ++ch)
            count += std::abs(int(a[i + ch]) - int(b[i + ch])) > 2;
    return count;
}

int main(int argc, char **argv) {
    if (argc != 4) {
        std::fprintf(stderr, "usage: %s PLUGIN.so PLUGIN_DATA_DIR SHADER.shader\n", argv[0]);
        return 2;
    }
    if (!obs_startup("en-US", nullptr, nullptr)) return 2;
    obs_video_info info{};
    info.graphics_module = "libobs-opengl";
    info.fps_num = 30; info.fps_den = 1;
    info.base_width = W; info.base_height = H;
    info.output_width = W; info.output_height = H;
    info.output_format = VIDEO_FORMAT_RGBA;
    info.scale_type = OBS_SCALE_DISABLE;
    if (obs_reset_video(&info) != OBS_VIDEO_SUCCESS) { obs_shutdown(); return 2; }
    obs_register_source(&fixture_info);

    obs_module_t *module = nullptr;
    bool loaded = obs_open_module(&module, argv[1], argv[2]) == MODULE_SUCCESS;
    loaded = loaded && obs_init_module(module);
    if (!loaded) { std::fprintf(stderr, "PLUGIN_LOAD_FAILED\n"); obs_shutdown(); return 3; }

    obs_source_t *source = obs_source_create("shaderfilter_bitmap_fixture", "fixture", nullptr, nullptr);
    obs_data_t *settings = obs_data_create();
    obs_data_set_bool(settings, "from_file", true);
    obs_data_set_string(settings, "shader_file_name", argv[3]);
    obs_source_t *filter = obs_source_create("shader_filter", "Bitmap Glyph Motion", settings, nullptr);
    obs_data_release(settings);
    if (!source || !filter) {
        std::fprintf(stderr, "SOURCE_OR_FILTER_CREATE_FAILED\n");
        obs_shutdown();
        return 4;
    }

    obs_source_filter_add(source, filter);
    obs_source_inc_showing(source);
    bool controls = false; // Parameter properties become available after initialization.

    bool compiled = false;

    obs_source_set_enabled(filter, false);
    Frame baseline = render(source);
    obs_source_set_enabled(filter, true);
    Frame effect;
    for (int i = 0; i < 5; ++i) {
        effect = render(source);
        std::this_thread::sleep_for(std::chrono::milliseconds(35));
    }
    // Shaderfilter may populate parameter UI after its initial effect load.
    auto *late_props = obs_source_properties(filter);
    auto *late_group = late_props ? obs_properties_get(late_props, "shader_params_group") : nullptr;
    auto *late_params = late_group ? obs_property_group_content(late_group) : nullptr;
    bool late_controls = late_params && obs_properties_get(late_params, "Mix") &&
                        obs_properties_get(late_params, "Cell_Pixels") &&
                        obs_properties_get(late_params, "Glyph_Set");
    controls = controls || late_controls;
    if (late_props) obs_properties_destroy(late_props);
    auto *state = obs_source_get_settings(filter);
    const char *error = obs_data_get_string(state, "last_error");
    compiled = !error || !*error;
    std::printf("EFFECT_COMPILED=%d CONTROLS=%d ERROR=%s\n",
                compiled, controls, error ? error : "");
    obs_data_release(state);

    auto *zero = obs_source_get_settings(filter);
    obs_data_set_double(zero, "Mix", 0.0);
    obs_source_update(filter, zero);
    obs_data_release(zero);
    Frame bypass;
    for (int i = 0; i < 5; ++i) {
        bypass = render(source);
        std::this_thread::sleep_for(std::chrono::milliseconds(35));
    }

    auto inspect = [](const char *label, const Frame &f) {
        uint64_t sum = 0;
        for (size_t i = 0; i + 3 < f.size(); i += 4)
            sum += f[i] + f[i + 1] + f[i + 2];
        size_t i = 4 * (H / 2 * W + W / 2);
        std::printf("FRAME_%s RGB_SUM=%llu CENTER=%u,%u,%u,%u\n",
                    label, (unsigned long long)sum,
                    f.empty() ? 0 : f[i], f.empty() ? 0 : f[i + 1],
                    f.empty() ? 0 : f[i + 2], f.empty() ? 0 : f[i + 3]);
    };
    inspect("BASE", baseline);
    inspect("ON", effect);
    inspect("ZERO", bypass);

    size_t visible = delta(baseline, effect, 0, 3);
    size_t bypass_diff = delta(baseline, bypass, 0, 3);
    size_t alpha_diff = delta(baseline, effect, 3, 4);
    std::printf("BITMAP_PIXELS_DIFF=%zu MIX_ZERO_DIFF=%zu ALPHA_DIFF=%zu\n",
                visible, bypass_diff, alpha_diff);

    bool pass = compiled && controls && visible > 500 &&
                bypass_diff < 100 && alpha_diff < 100;
    obs_source_dec_showing(source);
    obs_source_filter_remove(source, filter);
    obs_source_release(filter);
    obs_source_release(source);
    obs_shutdown();
    std::printf("BITMAP_GLYPH_PLUGIN_GPU_PASS=%d\n", pass);
    return pass ? 0 : 1;
}
