#pragma once

#include <obs/graphics/graphics.h>

class gs_effect_guard {
public:
    gs_effect_t* effect = nullptr;
    ~gs_effect_guard() { if (effect) gs_effect_destroy(effect); }
    gs_effect_t* release() { auto e = effect; effect = nullptr; return e; }
};

class graphics_context_guard {
public:
    graphics_context_guard() { obs_enter_graphics(); }
    ~graphics_context_guard() { obs_leave_graphics(); }
    graphics_context_guard(const graphics_context_guard&) = delete;
    graphics_context_guard& operator=(const graphics_context_guard&) = delete;
};
