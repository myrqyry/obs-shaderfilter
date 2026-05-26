# Debounced Auto-Reload & Inline Error Display

## Summary

When editing shader text in the OBS properties panel, the plugin will auto-reload the
shader 300ms after the user stops typing, and display compile errors inline near the
text box instead of burying them in `blog()` output.

## Motivation

New users hit a "blank screen" when their shader has a syntax error. The only feedback
is in Help → Log Files. The manual "Reload effect" button breaks the edit→see-result
loop. This feature makes the loop instantaneous.

## Design

### New struct fields (`obs-shaderfilter.h` / `obs-shaderfilter.c:struct shader_filter_data`)

```c
bool auto_reload_pending;       /* true while debounce timer is running */
uint64_t auto_reload_deadline;  /* nanosecond timestamp (os_gettime_ns) after which reload fires */
```

### Flow

1. **User edits shader_text** → `shader_filter_text_changed` fires (UI thread)
   - Sets `auto_reload_pending = true`
   - Sets `auto_reload_deadline = os_gettime_ns() + 300000000` (300ms)
   - Existing GLSL-detection logic remains unchanged

2. **`shader_filter_tick`** runs every video frame (~16ms, video thread)
   - If `auto_reload_pending && os_gettime_ns() >= auto_reload_deadline`:
     - Clears `auto_reload_pending`
     - Sets `reload_effect = true`
     - Calls `obs_source_update(filter->context, NULL)`

3. **`shader_filter_update`** picks up `reload_effect = true`
   - Calls `shader_filter_reload_effect(filter)` — exact same code path as "Reload effect" button
   - Calls `obs_source_update_properties(filter->context)` to refresh error display

4. **Error display** — already implemented at `obs-shaderfilter.c:2310-2318`
   - `settings["last_error"]` shown as `OBS_TEXT_INFO_ERROR` field
   - Only change: move this field higher in the properties layout (above "Reload effect")

### Thread safety

- `shader_filter_text_changed` runs on the OBS UI thread → safe for settings access
- `shader_filter_tick` runs on the video thread → `obs_source_update` is documented as
  thread-safe; it does not hold the graphics mutex at tick time, so `obs_enter_graphics()`
  inside the reload path will not deadlock
- `gs_effect_create` with invalid shader returns NULL, never crashes — already handled
  by existing NULL-check at render time (`filter->effect == NULL` → `obs_source_skip_video_filter`)

### Files touched

| File | Change |
|------|--------|
| `obs-shaderfilter.h` | Add `auto_reload_pending`, `auto_reload_deadline` fields |
| `obs-shaderfilter.c` | Modify `shader_filter_text_changed`, `shader_filter_tick` |
| `data/locale/en-US.ini` | Possibly add a locale string if needed for the error label placement |
| `docs/superpowers/specs/2026-05-25-auto-reload-inline-error-design.md` | This document |

### Non-goals

- Template picker / example browser (separate feature)
- Auto-convert on paste (separate feature)
- Live preview panel or viewport overlay

### Risks

- **Debounce too short** → repeated compiles on every keystroke. Mitigation: 300ms is a
  common UX debounce interval for text inputs.
- **Debounce too long** → user waits after stopping typing. Mitigation: 300ms is
  imperceptible; configurable if needed.
- **Threading** → `obs_source_update` called from `video_tick`. Per OBS docs this is
  safe; the update callback enters/exits graphics context correctly.
