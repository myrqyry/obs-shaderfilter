#pragma once

// Compatibility shim: include graphics.h which provides gs_texrender typedefs
#if __has_include(<obs/graphics/gs_texrender.h>)
#include <obs/graphics/gs_texrender.h>
#else
#include <obs/graphics/graphics.h>
#endif
