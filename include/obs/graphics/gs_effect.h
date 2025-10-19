#pragma once

// Compatibility shim: some OBS installs provide <obs/graphics/effect.h>
// while older code expects <obs/graphics/gs_effect.h>.

// Ensure graphics typedefs (gs_effect_t, gs_eparam_t, etc.) are available
#include <obs/graphics/graphics.h>

#if __has_include(<obs/graphics/gs_effect.h>) && !defined(_OBS_GS_EFFECT_SHIM)
// If the system already has gs_effect.h, include it
#include <obs/graphics/gs_effect.h>
#else
#include <obs/graphics/effect.h>
#endif
