# SESSION-STATE.md
**Project:** myrqyry-shaderfilter (fork of exeldro's obs-shaderfilter)
**Status:** Active development
**Last Updated:** 2026-05-30

## Key Context
- Fork of exeldro's shaderfilter OBS plugin
- HLSL shaders for OBS video filters
- User has attempted bug fixes and rearranged UI to personal taste
- UI preferences: customized layout (details pending)
- Rule: When uncertain about runtime/plugin behavior, do NOT toggle code based on memory — inspect source or ask for clarification first (user correction 2026-05-30)

## 2026-05-31 Decision
- Completed generative source implementation: added width/height to struct, default 1920x1080, updated get_width/get_height to prefer explicit dimensions, fixed shader_source_render, added UNUSED_PARAMETER guard. Compiles cleanly. Source "shader_source" now registered alongside filter/transition.
- Built and installed to ~/.config/obs-studio/plugins/obs-shaderfilter/ (user-local OBS plugins dir)
- Fixed regression: get_width/get_height now correctly prefer total_* (filter path) over explicit width/height (source path)
- Restored 1920x1080 default init (safe because get_* prefers total_* when filter has computed it)
- Verified full parameter path in shader_filter_tick + shader_filter_set_effect_params
- Restructured tick: sources now get proper uv_size/scale/offset/pixel_interval + elapsed_time accumulation (no early return when !target)
- Created data/examples/3d_text_sdf.shader (MQR 2.5D extruded text with bevel, Curve Simplify, and bob animation) — fixed cross-platform (removed unsupported `uniform string` + indexing)
- Created data/examples/canny_true.shader — proper single-pass Canny (gradient + direction + NMS + hysteresis + thickness)
- Initialized full proactive agent file set (AGENTS.md, SOUL.md, USER.md, MEMORY.md, HEARTBEAT.md, TOOLS.md, working-buffer.md) and added to .gitignore

## 2026-06-01 (This Session)
- Completed full proactive agent v3.0.0 architecture setup:
  - Created ONBOARDING.md (first-run setup tracker)
  - Upgraded SOUL.md (full identity + boundaries + ADL priorities)
  - Upgraded USER.md (detailed preferences, focus, communication style)
  - Upgraded MEMORY.md (structured learnings + anti-patterns + open questions)
  - Upgraded HEARTBEAT.md (full checklist from skill spec)
  - Upgraded TOOLS.md (comprehensive OBS/shaders/git/cmake/debug tooling)
  - Created memory/2026-06-01.md (daily log)
  - Reset memory/working-buffer.md to STANDBY
  - Created notes/areas/ (proactive-tracker, recurring-patterns, outcome-journal)
  - Updated AGENTS.md with all six pillars + protocols
