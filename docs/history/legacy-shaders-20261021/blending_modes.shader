// Blending Mode Library for obs-shaderfilter
//
// This file is not a standalone shader. It's a library of functions
// designed to be included in other shaders using the #include directive.
//
// Version 2: Added division-by-zero guards for stability.

// --- Blend Mode "Enum" (for reference in your main shader) ---
// 0: Normal      | 8: Linear Burn
// 1: Multiply    | 9: Color Burn
// 2: Screen      | 10: Difference
// 3: Overlay     | 11: Exclusion
// 4: Hard Light  | 12: Vivid Light
// 5: Soft Light  | 13: Linear Light
// 6: Add         | 14: Pin Light
// 7: Color Dodge | 15+ HSL Modes...

// --- HSL Helper Functions ---
float3 rgb_to_hsl(float3 c) {
    float max_c = max(c.r, max(c.g, c.b));
    float min_c = min(c.r, min(c.g, c.b));
    float h = 0.0, s = 0.0, l = (max_c + min_c) / 2.0;
    if (max_c == min_c) {
        h = s = 0.0;
    } else {
        float d = max_c - min_c;
        s = l > 0.5 ? d / (2.0 - max_c - min_c) : d / (max_c + min_c);
        if (max_c == c.r) { h = (c.g - c.b) / d + (c.g < c.b ? 6.0 : 0.0); }
        else if (max_c == c.g) { h = (c.b - c.r) / d + 2.0; }
        else if (max_c == c.b) { h = (c.r - c.g) / d + 4.0; }
        h /= 6.0;
    }
    return float3(h, s, l);
}

float hue_to_rgb_component(float p, float q, float t) {
    if (t < 0.0) t += 1.0;
    if (t > 1.0) t -= 1.0;
    if (t < 1.0/6.0) return p + (q - p) * 6.0 * t;
    if (t < 1.0/2.0) return q;
    if (t < 2.0/3.0) return p + (q - p) * (2.0/3.0 - t) * 6.0;
    return p;
}

float3 hsl_to_rgb(float3 c) {
    float r, g, b;
    if (c.y == 0.0) {
        r = g = b = c.z;
    } else {
        float q = c.z < 0.5 ? c.z * (1.0 + c.y) : c.z + c.y - c.z * c.y;
        float p = 2.0 * c.z - q;
        r = hue_to_rgb_component(p, q, c.x + 1.0/3.0);
        g = hue_to_rgb_component(p, q, c.x);
        b = hue_to_rgb_component(p, q, c.x - 1.0/3.0);
    }
    return float3(r, g, b);
}

float soft_light_component(float base, float blend) {
    if (blend < 0.5) {
        return base - (1.0 - 2.0 * blend) * base * (1.0 - base);
    } else {
        float d = (base < 0.25) ? ((16.0 * base - 12.0) * base + 4.0) * base : sqrt(base);
        return base + (2.0 * blend - 1.0) * (d - base);
    }
}

// Main blend function
float4 blend(int mode, float4 base, float4 blend_layer) {
    float3 result_rgb;

    switch (mode) {
        default: // 0: Normal
            result_rgb = blend_layer.rgb; break;
        case 1: // Multiply
            result_rgb = base.rgb * blend_layer.rgb; break;
        case 2: // Screen
            result_rgb = 1.0 - (1.0 - base.rgb) * (1.0 - blend_layer.rgb); break;
        case 3: // Overlay
            result_rgb = lerp(2.0 * base.rgb * blend_layer.rgb, 1.0 - 2.0 * (1.0 - base.rgb) * (1.0 - blend_layer.rgb), step(0.5, base.rgb)); break;
        case 4: // Hard Light
            result_rgb = lerp(2.0 * base.rgb * blend_layer.rgb, 1.0 - 2.0 * (1.0 - base.rgb) * (1.0 - blend_layer.rgb), step(0.5, blend_layer.rgb)); break;
        case 5: // Soft Light
            result_rgb.r = soft_light_component(base.r, blend_layer.r);
            result_rgb.g = soft_light_component(base.g, blend_layer.g);
            result_rgb.b = soft_light_component(base.b, blend_layer.b); break;
        case 6: // Add
            result_rgb = base.rgb + blend_layer.rgb; break;
        case 7: // Color Dodge
            result_rgb = base.rgb / max(1.0 - blend_layer.rgb, 0.001); break;
        case 8: // Linear Burn
            result_rgb = base.rgb + blend_layer.rgb - 1.0; break;
        case 9: // Color Burn
            result_rgb = 1.0 - (1.0 - base.rgb) / max(blend_layer.rgb, 0.001); break;
        case 10: // Difference
            result_rgb = abs(base.rgb - blend_layer.rgb); break;
        case 11: // Exclusion
            result_rgb = base.rgb + blend_layer.rgb - 2.0 * base.rgb * blend_layer.rgb; break;
        case 12: // Vivid Light
            result_rgb = lerp(1.0 - (1.0 - base.rgb) / max(2.0 * blend_layer.rgb, 0.001), base.rgb / max(2.0 * (1.0 - blend_layer.rgb), 0.001), step(0.5, blend_layer.rgb)); break;
        case 13: // Linear Light
            result_rgb = base.rgb + 2.0 * blend_layer.rgb - 1.0; break;
        case 14: // Pin Light
            result_rgb = lerp(min(base.rgb, 2.0 * blend_layer.rgb), max(base.rgb, 2.0 * blend_layer.rgb - 1.0), step(0.5, blend_layer.rgb)); break;
        case 15: // Hue
            result_rgb = hsl_to_rgb(float3(rgb_to_hsl(blend_layer.rgb).x, rgb_to_hsl(base.rgb).yz)); break;
        case 16: // Saturation
            result_rgb = hsl_to_rgb(float3(rgb_to_hsl(base.rgb).x, rgb_to_hsl(blend_layer.rgb).y, rgb_to_hsl(base.rgb).z)); break;
        case 17: // Color
            result_rgb = hsl_to_rgb(float3(rgb_to_hsl(blend_layer.rgb).xy, rgb_to_hsl(base.rgb).z)); break;
        case 18: // Luminosity
            result_rgb = hsl_to_rgb(float3(rgb_to_hsl(base.rgb).xy, rgb_to_hsl(blend_layer.rgb).z)); break;
    }

    // Final composition: lerp based on blend layer alpha and clamp the result
    result_rgb = lerp(base.rgb, result_rgb, blend_layer.a);
    return float4(clamp(result_rgb, 0.0, 1.0), base.a);
}
