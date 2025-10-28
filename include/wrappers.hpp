#pragma once

#include <obs/graphics/graphics.h>

class gs_effect_guard {
public:
    gs_effect_t* effect = nullptr;
    ~gs_effect_guard() { if (effect) gs_effect_destroy(effect); }
    gs_effect_t* release() { auto e = effect; effect = nullptr; return e; }
};
