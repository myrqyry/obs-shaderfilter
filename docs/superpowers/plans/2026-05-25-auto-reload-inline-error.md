# Debounced Auto-Reload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-reload shader effect 300ms after user stops typing, using existing error display.

**Architecture:** Two new fields (`auto_reload_pending`, `auto_reload_deadline`) added to `shader_filter_data`. The text-changed callback sets a deadline; the video tick callback checks it and triggers `obs_source_update` when elapsed. The existing `last_error` → `OBS_TEXT_INFO_ERROR` path handles inline error display.

**Tech Stack:** C, OBS Studio libobs API, HLSL effect compiler

---

### Task 1: Add auto-reload fields to the filter struct

**File:** `obs-shaderfilter.c:171-265`

- [ ] **Step 1: Add `auto_reload_pending` and `auto_reload_deadline` to struct**

Insert after line 243 (`bool rendering;`):

```c
	bool rendering;

	bool auto_reload_pending;
	uint64_t auto_reload_deadline;
```

`bzalloc` in `shader_filter_create` (line 781) and `shader_transition_create` (line 3566) zero-initializes these to `false`/`0` — no explicit init needed.

- [ ] **Step 2: Commit**

```bash
git add obs-shaderfilter.c
git commit -m "feat: add auto_reload fields to shader_filter_data"
```

---

### Task 2: Schedule auto-reload on every text change

**File:** `obs-shaderfilter.c:849-866`

- [ ] **Step 3: Modify `shader_filter_text_changed` to record debounce deadline**

Replace the function body (keeping the existing GLSL detection logic at the bottom):

```c
static bool shader_filter_text_changed(obs_properties_t *props, obs_property_t *p, obs_data_t *settings)
{
	UNUSED_PARAMETER(p);
	struct shader_filter_data *filter = obs_properties_get_param(props);
	if (!filter)
		return false;

	filter->auto_reload_pending = true;
	filter->auto_reload_deadline = os_gettime_ns() + 300000000ULL;

	const char *shader_text = obs_data_get_string(settings, "shader_text");
	bool can_convert = strstr(shader_text, "void mainImage( out vec4") || strstr(shader_text, "void mainImage(out vec4") ||
			   strstr(shader_text, "void main()") || strstr(shader_text, "vec4 effect(vec4");
	obs_property_t *shader_convert = obs_properties_get(props, "shader_convert");
	bool visible = obs_property_visible(obs_properties_get(props, "shader_text"));
	if (obs_property_visible(shader_convert) != (can_convert && visible)) {
		obs_property_set_visible(shader_convert, can_convert && visible);
		return true;
	}
	return false;
}
```

- [ ] **Step 4: Commit**

```bash
git add obs-shaderfilter.c
git commit -m "feat: set auto-reload deadline on shader text change"
```

---

### Task 3: Trigger reload from video tick when debounce expires

**File:** `obs-shaderfilter.c:2884-2953`

- [ ] **Step 5: Add auto-reload check at start of `shader_filter_tick`**

Insert after the `if (!target) return;` block (after line 2889):

```c
static void shader_filter_tick(void *data, float seconds)
{
	struct shader_filter_data *filter = data;
	obs_source_t *target = filter->transition ? filter->context : obs_filter_get_target(filter->context);
	if (!target)
		return;

	if (filter->auto_reload_pending) {
		uint64_t now = os_gettime_ns();
		if (now >= filter->auto_reload_deadline) {
			filter->auto_reload_pending = false;
			filter->reload_effect = true;
			obs_source_update(filter->context, NULL);
		}
	}

	int base_width = obs_source_get_base_width(target);
	// ... rest of function unchanged
```

- [ ] **Step 6: Build plugin and verify it compiles**

Run: `cmake --build build --target obs-shaderfilter`

No tests possible (OBS plugin). Manual verification steps after build:
1. Install plugin into OBS data directory
2. Launch OBS, add any source, add "User-defined shader" filter
3. Type a valid shader in the text box — wait ~300ms — verify source renders with the shader applied
4. Edit shader text — wait ~300ms — verify new shader is applied without clicking "Reload effect"
5. Type invalid shader code — verify error appears in properties panel with `OBS_TEXT_INFO_ERROR` styling
6. Type another invalid shader quickly (multiple keystrokes in <300ms) — verify only one reload fires after typing stops

- [ ] **Step 7: Commit**

```bash
git add obs-shaderfilter.c
git commit -m "feat: trigger auto-reload from video_tick after 300ms debounce"
```

---

### Task 4: Move error display directly after shader text field

**File:** `obs-shaderfilter.c:2310-2318`

The error field is currently added to `source_group` after the file picker and before the reload button. We want it right after the shader text field so it reads as immediate feedback on the text the user just typed.

- [ ] **Step 8: Move `last_error` property creation to immediately after the shader_text property**

Current order in `shader_filter_properties`:
```
source_group:
  override_entire_effect (bool)
  from_file (bool)
  shader_text (text)
  shader_convert (button)
  shader_file_name (path)
  last_error (text info)    ← move this to after shader_text
  reload_effect (button)
  audio_source (list)
```

Remove the error block from lines 2310-2318 and re-insert it after the `shader_text` property creation on line 2296. The modified `shader_filter_properties` excerpt:

```c
	obs_property_t *shader_text =
		obs_properties_add_text(source_group, "shader_text", obs_module_text("ShaderFilter.ShaderText"), OBS_TEXT_MULTILINE);
	obs_property_set_modified_callback(shader_text, shader_filter_text_changed);

	obs_properties_add_button2(source_group, "shader_convert", obs_module_text("ShaderFilter.Convert"), shader_filter_convert,
				   data);

	if (filter) {
		obs_data_t *settings = obs_source_get_settings(filter->context);
		const char *last_error = obs_data_get_string(settings, "last_error");
		if (last_error && strlen(last_error)) {
			obs_property_t *error = obs_properties_add_text(source_group, "last_error",
									       obs_module_text("ShaderFilter.Error"),
									       OBS_TEXT_INFO);
			obs_property_text_set_info_type(error, OBS_TEXT_INFO_ERROR);
		}
		obs_data_release(settings);
	}

	char *abs_path = os_get_abs_path_ptr(examples_path.array);
	// ... rest of function continues with shader_file_name
```

Also remove the error block from its original location (lines 2310-2318, which will now be shifted).

- [ ] **Step 9: Commit**

```bash
git add obs-shaderfilter.c
git commit -m "ui: move error display inline after shader text field"
```

---

### Verification Checklist (manual)

After building and installing:

- [ ] Add filter to source, type valid shader → renders after ~300ms
- [ ] Edit shader text → auto-reload applies changes without button click
- [ ] Type rapidly for >300ms → only one reload fires after typing stops
- [ ] Enter invalid shader code → error appears inline, source goes blank (no crash)
- [ ] Fix the invalid code → auto-reload compiles, error clears, source renders again
- [ ] Switch between "Load from file" and direct text → auto-reload still works
- [ ] "Reload effect" button still works manually
- [ ] "Convert Shader" button still appears/disappears based on GLSL detection
- [ ] Transition filter variant also auto-reloads
