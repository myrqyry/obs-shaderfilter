# AGENTS.md - AI Agent Context for obs-shaderfilter-plus-next

> **Last Updated**: October 19, 2025  
> **Project Status**: Phase 2 - Audio Reactivity Polish  
> **Maintainer**: myrqyry

---

## 🎯 Project Overview

**obs-shaderfilter-plus-next** is an advanced fork of the popular obs-shaderfilter plugin for OBS Studio. It extends the original with professional-grade features for real-time GPU shader effects, multi-input video compositing, and audio-reactive visuals.

### Key Differentiators from Original
- **Multi-input texture support**: Use multiple OBS video sources in shaders
- **Audio reactivity**: Real-time FFT spectrum analysis drives shader parameters
- **Hot reload**: Live shader editing without filter reset
- **Ping-pong framebuffers**: Temporal feedback effects (in progress)
- **Modular C++ architecture**: Clean separation of concerns vs. monolithic C code

### Target Users
- Live streamers creating audio-reactive overlays
- Video producers applying real-time GPU effects
- VJs and visual artists performing with OBS
- Shader developers prototyping effects

---

## 📁 Project Structure

```
obs-shaderfilter/
├── CMakeLists.txt              # Cross-platform build configuration
├── include/
│   ├── shader_filter.hpp       # Main filter interface and data structures
│   ├── multi_input.hpp         # Multi-texture input management
│   ├── audio_reactive.hpp      # Audio capture and FFT processing
│   └── hot_reload.hpp          # File watching and shader reload
├── src/
│   ├── obs-shaderfilter.cpp    # Plugin entry point (OBS module registration)
│   ├── shader_filter.cpp       # Core filter lifecycle and rendering
│   ├── multi_input.cpp         # Source enumeration and texture binding
│   ├── audio_reactive.cpp      # Audio callback, FFT, spectrum processing
│   └── hot_reload.cpp          # Filesystem watcher thread
├── data/
│   ├── shaders/
│   │   └── examples/           # Example shaders showcasing features
│   │       ├── test_multi_input.effect
│   │       ├── audio_reactive_blend.effect
│   │       └── akira_trails.effect (planned)
│   └── locale/
│       └── en-US.ini           # UI text translations
├── cmake/                      # CMake helper modules
├── build.sh / build.bat        # Build scripts for Linux/Windows
└── README.md                   # User-facing documentation
```

---

## 🏗️ Architecture Overview

### Core Components

#### 1. **Filter Lifecycle** (`shader_filter.cpp`)
The main OBS source filter implementation following OBS's plugin API:

```
struct filter_data {
    obs_source_t *context;           // OBS filter context
    gs_effect_t *effect;             // Compiled shader effect
    
    // Multi-input
    obs_weak_source_t *secondary_source;
    obs_weak_source_t *mask_source;
    gs_texrender_t *secondary_texrender;
    gs_texrender_t *mask_texrender;
    
    // Audio reactivity
    float *audio_spectrum;           // Normalized  spectrum[1]
    int spectrum_bands;
    float audio_attack, audio_release, audio_gain;
    float *smoothed_spectrum;        // Temporally smoothed
    std::mutex spectrum_mutex;       // Thread safety
    
    // Ping-pong buffers (future)
    gs_texrender_t *feedback_buffer_a;
    gs_texrender_t *feedback_buffer_b;
    bool is_buffer_a_active;
    
    // Shader management
    char *shader_path;
    bool hot_reload_enabled;
};
```

**Key Functions:**
- `filter_create()` - Allocates filter data, registers callbacks
- `filter_destroy()` - Cleanup graphics resources, release sources
- `filter_update()` - Responds to user property changes
- `filter_render()` - Per-frame rendering, binds uniforms, executes shader
- `filter_properties()` - Builds UI property window

#### 2. **Multi-Input System** (`multi_input.cpp`)
Enables shaders to composite multiple OBS sources:

- Enumerates OBS video sources for UI dropdowns
- Renders secondary sources to off-screen textures each frame
- Binds textures to shader uniforms (`secondary_image`, `mask_image`)
- Handles source lifetime with weak references (prevents crashes if source deleted)

**Graphics Pipeline:**
```
OBS Source → gs_texrender_t (offscreen) → gs_texture_t → Shader Uniform
```

#### 3. **Audio Reactivity** (`audio_reactive.cpp`)
Real-time audio-driven shader parameters:

- Registers audio callback on selected OBS audio source
- Captures PCM audio samples in thread-safe ring buffer
- Applies Hann window + FFTW complex FFT
- Logarithmically bins frequencies (human hearing scale)
- Smooths with exponential moving average (attack/release)
- Normalizes and binds spectrum array to `audio_spectrum` uniform

**Audio Thread Safety:**
- Audio callback runs on OBS audio thread
- Render thread accesses spectrum data
- Protected by `std::mutex spectrum_mutex`
- Always lock before reading/writing shared buffers

#### 4. **Hot Reload** (`hot_reload.cpp`)
Watches shader files for changes:

- Filesystem watcher thread (`std::thread`)
- Polls `std::filesystem::last_write_time` every 500ms
- On file change, triggers shader recompilation
- Thread-safe file list with `std::mutex watch_mutex`

---

## 🔧 Development Environment

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| CMake | 3.16+ | Build system |
| C++ Compiler | C++17 | Language standard |
| OBS Studio | 30.0+ | Headers and libraries |
| FFTW | 3.x | FFT processing (audio reactivity) |
| Git | Any | Version control |

### Supported Platforms
- **Linux**: Ubuntu 20.04+, Arch, Fedora
- **Windows**: Visual Studio 2019/2022, MinGW
- **macOS**: 11.0+ (Intel and Apple Silicon)

### Building from Source

#### In-Tree Build (Recommended for Development)
```
# Clone OBS Studio source
git clone --recursive https://github.com/obsproject/obs-studio.git
cd obs-studio

# Add plugin as submodule
cd plugins
git submodule add https://github.com/myrqyry/obs-shaderfilter.git

# Register plugin in plugins/CMakeLists.txt
echo "add_subdirectory(obs-shaderfilter)" >> CMakeLists.txt

# Build entire OBS with plugin
cd ..
mkdir build && cd build
cmake -DUNIX_STRUCTURE=1 ..
cmake --build . -j$(nproc)
```

#### Standalone Build (For Quick Testing)
```
# Linux - requires libobs-dev installed
./build.sh

# Windows
build.bat --obs-dir "C:\Program Files\obs-studio"

# macOS
./build.sh --obs-dir "/Applications/OBS.app/Contents/Resources"
```

### Testing
1. Copy built `.so`/`.dll` to OBS plugins directory
2. Launch OBS, add any source
3. Right-click source → Filters → Add → "Shader Filter"
4. Load test shader from `data/shaders/examples/`
5. Verify multi-input/audio controls appear

---

## 📝 Code Conventions

### Style Guidelines

**Formatting:**
- **Indentation**: 4 spaces (no tabs)
- **Braces**: K&R style (opening brace on same line)
- **Line Length**: 100 characters max
- **Naming**:
  - `snake_case` for functions, variables
  - `PascalCase` for structs, classes
  - `UPPER_CASE` for macros, constants

**Example:**
```
void process_audio_spectrum(filter_data *filter, const float *samples, size_t count)
{
    if (!filter || !samples) {
        blog(LOG_ERROR, "[Audio] Null pointer in process_audio_spectrum");
        return;
    }
    
    std::lock_guard<std::mutex> lock(filter->spectrum_mutex);
    // ... processing logic
}
```

### OBS-Specific Patterns

**Graphics Context:**
Always enter/exit graphics context for OBS API calls:
```
obs_enter_graphics();
gs_texrender_t *tex = gs_texrender_create(GS_RGBA, GS_ZS_NONE);
obs_leave_graphics();
```

**Source References:**
Use weak references to avoid circular dependencies:
```
obs_source_t *source = obs_get_source_by_name("MySource");
filter->weak_source = obs_source_get_weak_source(source);
obs_source_release(source); // Release strong ref immediately

// Later, in render:
obs_source_t *src = obs_weak_source_get_source(filter->weak_source);
if (src) {
    obs_source_video_render(src);
    obs_source_release(src);
}
```

**Logging:**
Use OBS blog macros:
```
blog(LOG_INFO, "[ShaderFilter] Shader loaded: %s", path);
blog(LOG_WARNING, "[ShaderFilter] Source not found: %s", name);
blog(LOG_ERROR, "[ShaderFilter] FFT failed: %s", error);
```

### Thread Safety Rules

1. **Audio Callback**: Always lock `spectrum_mutex` before modifying `audio_spectrum`
2. **Hot Reload**: Lock `watch_mutex` when accessing `watched_files` map
3. **Render Thread**: Lock mutexes when reading shared state from other threads
4. **Graphics Resources**: Only create/destroy in graphics context (render thread)

---

## 🎨 Shader Development

### Standard Uniforms (Auto-provided)

All shaders have access to these uniforms:

```
uniform float4x4 ViewProj;          // OBS view/projection matrix
uniform texture2d image;            // Primary input source
uniform float2 uv_offset;           // Border expansion offset
uniform float2 uv_scale;            // Border expansion scale
uniform float2 uv_size;             // Viewport dimensions
uniform float2 uv_pixel_interval;   // Texel size in UV space
uniform float elapsed_time;         // Seconds since filter created
```

### Multi-Input Uniforms

```
uniform texture2d secondary_image;  // Secondary video source
uniform texture2d mask_image;       // Mask source (grayscale)
```

### Audio Reactivity Uniforms

```
uniform float audio_spectrum;  // Frequency spectrum[1]
uniform int spectrum_bands;         // Number of active bands (e.g., 64)
```

**Frequency Mapping** (logarithmic bins):
- `audio_spectrum[0]` = 20-40 Hz (sub-bass)
- `audio_spectrum[8]` = 80-160 Hz (bass)
- `audio_spectrum[32]` = 1-2 kHz (midrange)
- `audio_spectrum[56]` = 8-16 kHz (treble)

### Example Shader Template

```
uniform float4x4 ViewProj;
uniform texture2d image;
uniform texture2d secondary_image;
uniform float audio_spectrum;
uniform int spectrum_bands;

uniform float mix_amount<
    string label = "Mix Amount";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.5;

sampler_state textureSampler {
    Filter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

struct VertexData {
    float4 pos : POSITION;
    float2 uv : TEXCOORD0;
};

VertexData VSDefault(VertexData v_in) {
    VertexData v_out;
    v_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
    v_out.uv = v_in.uv;
    return v_out;
}

float4 PSEffect(VertexData v_in) : TARGET {
    float4 color_a = image.Sample(textureSampler, v_in.uv);
    float4 color_b = secondary_image.Sample(textureSampler, v_in.uv);
    
    // Audio-reactive mixing
    float bass = audio_spectrum; // 80-160 Hz
    float dynamic_mix = mix_amount + (bass * 0.5);
    
    return lerp(color_a, color_b, saturate(dynamic_mix));
}

technique Draw {
    pass {
        vertex_shader = VSDefault(v_in);
        pixel_shader = PSEffect(v_in);
    }
}
```

---

## 🚀 Current Development Status

### Completed (✅)
- **Phase 1**: Multi-input texture support with UI controls
- **Phase 2A**: Audio capture, FFT processing, thread-safe buffering
- Core plugin architecture (modular C++, CMake build system)
- Hot reload file watching (basic implementation)

### In Progress (🔄)
- **Phase 2B**: Audio smoothing controls (attack, release, gain)
- Example audio-reactive shaders
- Documentation updates

### Planned (📋)
- **Phase 3**: Hot reload error handling improvements
- **Phase 4**: Dynamic UI source list refresh
- **Phase 5**: Ping-pong framebuffer feedback effects
- **Phase 6**: CI/CD pipeline (GitHub Actions)
- **Phase 7**: Release packaging and distribution

---

## 🐛 Common Pitfalls & Gotchas

### 1. Graphics Context Violations
**Problem**: Calling `gs_*` functions outside graphics context crashes OBS.

**Solution**: Always wrap in `obs_enter_graphics()` / `obs_leave_graphics()`:
```
void cleanup_textures(filter_data *filter) {
    obs_enter_graphics();
    if (filter->render_target) {
        gs_texrender_destroy(filter->render_target);
    }
    obs_leave_graphics();
}
```

### 2. Memory Leaks from Strong Source References
**Problem**: Holding `obs_source_t*` creates circular reference → memory leak.

**Solution**: Use `obs_weak_source_t*` and release immediately:
```
// ❌ BAD: Holds strong reference indefinitely
filter->source = obs_get_source_by_name("MySource");

// ✅ GOOD: Use weak reference
obs_source_t *src = obs_get_source_by_name("MySource");
filter->weak_source = obs_source_get_weak_source(src);
obs_source_release(src); // Release immediately
```

### 3. Race Conditions in Audio Processing
**Problem**: Audio callback and render thread access shared spectrum simultaneously.

**Solution**: Always lock mutex:
```
// In audio callback
{
    std::lock_guard<std::mutex> lock(filter->spectrum_mutex);
    memcpy(filter->audio_spectrum, fft_output, sizeof(float) * bands);
}

// In render function
{
    std::lock_guard<std::mutex> lock(filter->spectrum_mutex);
    gs_effect_set_float_array(effect, "audio_spectrum", 
                               filter->audio_spectrum, bands);
}
```

### 4. Shader Compilation Errors Not Visible
**Problem**: OBS silently fails shader compilation, source renders blank.

**Solution**: Check OBS log file (`Help → Log Files → View Current Log`):
```
[shader_filter] Effect compilation failed: syntax error at line 45
```

### 5. Texture Size Mismatches
**Problem**: Secondary source resolution changes mid-stream, texrender stale.

**Solution**: Check dimensions every frame and recreate:
```
uint32_t width = obs_source_get_width(source);
uint32_t height = obs_source_get_height(source);

if (gs_texrender_get_width(texrender) != width ||
    gs_texrender_get_height(texrender) != height) {
    gs_texrender_destroy(texrender);
    texrender = gs_texrender_create(GS_RGBA, GS_ZS_NONE);
}
```

---

## 📚 Key OBS API References

### Most-Used Functions

**Source Management:**
```
obs_source_t* obs_get_source_by_name(const char *name);
void obs_source_release(obs_source_t *source);
obs_weak_source_t* obs_source_get_weak_source(obs_source_t *source);
obs_source_t* obs_weak_source_get_source(obs_weak_source_t *weak);
uint32_t obs_source_get_width(obs_source_t *source);
void obs_source_video_render(obs_source_t *source);
```

**Graphics Resources:**
```
gs_texrender_t* gs_texrender_create(enum gs_color_format format, enum gs_zstencil_format zsformat);
void gs_texrender_destroy(gs_texrender_t *texrender);
bool gs_texrender_begin(gs_texrender_t *texrender, uint32_t cx, uint32_t cy);
void gs_texrender_end(gs_texrender_t *texrender);
gs_texture_t* gs_texrender_get_texture(const gs_texrender_t *texrender);
```

**Shader/Effect Management:**
```
gs_effect_t* gs_effect_create_from_file(const char *file, char **error_string);
void gs_effect_destroy(gs_effect_t *effect);
gs_eparam_t* gs_effect_get_param_by_name(const gs_effect_t *effect, const char *name);
void gs_effect_set_texture(gs_eparam_t *param, gs_texture_t *val);
void gs_effect_set_float_array(gs_eparam_t *param, const float *array, size_t count);
```

**Properties (UI):**
```
obs_properties_t* obs_properties_create();
obs_property_t* obs_properties_add_float_slider(obs_properties_t *props, const char *name, const char *description, double min, double max, double step);
obs_property_t* obs_properties_add_list(obs_properties_t *props, const char *name, const char *description, enum obs_combo_type type, enum obs_combo_format format);
void obs_property_list_add_string(obs_property_t *p, const char *name, const char *val);
```

---

## 🧪 Testing Guidelines

### Before Submitting Code

1. **Compile Test**: `cmake --build build` must succeed with zero warnings
2. **Load Test**: Plugin loads in OBS without crashing
3. **Filter Test**: Can add filter to multiple sources simultaneously
4. **UI Test**: All new properties appear and respond to input
5. **Thread Safety**: No race conditions under rapid property changes
6. **Memory Test**: Run for 5+ minutes, check for leaks (Valgrind on Linux)

### Test Scenarios

**Multi-Input:**
- Add two webcams, verify blending works
- Delete secondary source mid-stream, verify graceful fallback
- Resize sources, verify no artifacts

**Audio Reactivity:**
- Play music, verify spectrum updates in real-time
- Switch audio sources, verify callback switches
- Mute audio, verify spectrum zeros out

**Hot Reload:**
- Edit shader file while filter active
- Save multiple times rapidly
- Delete shader file, verify no crash

---

## 🔍 Where to Find Things

| What You Need | Where to Look |
|---------------|---------------|
| Add new UI control | `src/audio_reactive.cpp` → `add_properties()` |
| Modify rendering logic | `src/shader_filter.cpp` → `filter_render()` |
| Change FFT processing | `src/audio_reactive.cpp` → FFT helper functions |
| Add new shader uniform | `src/shader_filter.cpp` → `filter_render()` → `gs_effect_set_*` |
| Fix build errors | `CMakeLists.txt`, check OBS headers path |
| Add UI text | `data/locale/en-US.ini` |
| Test new feature | `data/shaders/examples/` → create test shader |

---

## 💡 Tips for AI Agents

### When Adding Features

1. **Check existing patterns first** - Look at similar code (e.g., if adding UI slider, see how existing sliders are done)
2. **Maintain thread safety** - If touching audio/hot reload, use mutexes
3. **Follow OBS lifecycle** - Create in `filter_create`, destroy in `filter_destroy`
4. **Match code style** - Use 4-space indent, snake_case, K&R braces
5. **Add logging** - Use `blog()` for important state changes
6. **Update locale** - Add translations to `en-US.ini` for new UI text

### When Fixing Bugs

1. **Check OBS logs first** - Most issues logged with `[ShaderFilter]` prefix
2. **Verify graphics context** - Crashes often from `gs_*` calls outside context
3. **Test with multiple instances** - Filter should work on multiple sources
4. **Check thread safety** - Use `-fsanitize=thread` if available

### When Refactoring

1. **Keep commits atomic** - One logical change per commit
2. **Don't break existing shaders** - Maintain uniform compatibility
3. **Update this file** - Keep AGENTS.md current with architecture changes

---

## 📞 Getting Help

- **OBS API Docs**: https://obsproject.com/docs/
- **Original Plugin**: https://github.com/exeldro/obs-shaderfilter
- **HLSL Reference**: https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl
- **FFTW Docs**: https://www.fftw.org/fftw3_doc/

---

**This file is maintained for AI coding agents. Keep it updated as the project evolves.**