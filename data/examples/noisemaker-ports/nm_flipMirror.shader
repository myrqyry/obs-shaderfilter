// OBS HLSL adaptation of Noisemaker filter/flipMirror/flipMirror.glsl.
// Upstream: https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/flipMirror
// Copyright (c) 2017-2026 Noise Factor LLC, MIT.
// License: NOISEMAKER-LICENSE.txt. Adapted for OBS Shaderfilter's per-frame
// effect wrapper and full-frame UVs. No tiled renderer or multi-pass graph.
// Noisemaker filter inputs use edge-clamped texture sampling.
float4 nmSample(float2 uv) {
    float2 halfTexel = uv_pixel_interval * 0.5;
    return image.Sample(textureSampler, clamp(uv, halfTexel, 1.0 - halfTexel));
}

/*
 * Flip/Mirror effect
 * Apply horizontal/vertical flipping and various mirroring modes
 */
uniform int flipMode<
    string label = "Flip mode";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "none";
    int option_1_value = 1;
    string option_1_label = "all";
    int option_2_value = 2;
    string option_2_label = "horizontal";
    int option_3_value = 3;
    string option_3_label = "vertical";
    int option_4_value = 11;
    string option_4_label = "mirrorLtoR";
    int option_5_value = 12;
    string option_5_label = "mirrorRtoL";
    int option_6_value = 13;
    string option_6_label = "mirrorUtoD";
    int option_7_value = 14;
    string option_7_label = "mirrorDtoU";
    int option_8_value = 15;
    string option_8_label = "mirrorLtoRUtoD";
    int option_9_value = 16;
    string option_9_label = "mirrorLtoRDtoU";
    int option_10_value = 17;
    string option_10_label = "mirrorRtoLUtoD";
    int option_11_value = 18;
    string option_11_label = "mirrorRtoLDtoU";
> = 15;
float4 mainImage(VertData v_in) : TARGET {
    float4 fragColor = nmSample(v_in.uv);
    float2 texSize = uv_size;
    float2 globalCoord = (v_in.uv * uv_size) + float2(0.0, 0.0);
    float2 globalUV = globalCoord / uv_size;

    float2 warpedUV = globalUV;

    if (flipMode == 1) {
        // flip both
        warpedUV.x = 1.0 - warpedUV.x;
        warpedUV.y = 1.0 - warpedUV.y;
    } else if (flipMode == 2) {
        // flip horizontal
        warpedUV.x = 1.0 - warpedUV.x;
    } else if (flipMode == 3) {
        // flip vertical
        warpedUV.y = 1.0 - warpedUV.y;
    } else if (flipMode == 11) {
        // mirror left to right
        if (warpedUV.x > 0.5) {
            warpedUV.x = 1.0 - warpedUV.x;
        }
    } else if (flipMode == 12) {
        // mirror right to left
        if (warpedUV.x < 0.5) {
            warpedUV.x = 1.0 - warpedUV.x;
        }
    } else if (flipMode == 13) {
        // mirror up to down. warpedUV.y runs up the frame, so the top half
        // is warpedUV.y > 0.5 and the bottom half samples its reflection.
        if (warpedUV.y < 0.5) {
            warpedUV.y = 1.0 - warpedUV.y;
        }
    } else if (flipMode == 14) {
        // mirror down to up
        if (warpedUV.y > 0.5) {
            warpedUV.y = 1.0 - warpedUV.y;
        }
    } else if (flipMode == 15) {
        // mirror left to right, up to down
        if (warpedUV.x > 0.5) {
            warpedUV.x = 1.0 - warpedUV.x;
        }
        if (warpedUV.y < 0.5) {
            warpedUV.y = 1.0 - warpedUV.y;
        }
    } else if (flipMode == 16) {
        // mirror left to right, down to up
        if (warpedUV.x > 0.5) {
            warpedUV.x = 1.0 - warpedUV.x;
        }
        if (warpedUV.y > 0.5) {
            warpedUV.y = 1.0 - warpedUV.y;
        }
    } else if (flipMode == 17) {
        // mirror right to left, up to down
        if (warpedUV.x < 0.5) {
            warpedUV.x = 1.0 - warpedUV.x;
        }
        if (warpedUV.y < 0.5) {
            warpedUV.y = 1.0 - warpedUV.y;
        }
    } else if (flipMode == 18) {
        // mirror right to left, down to up
        if (warpedUV.x < 0.5) {
            warpedUV.x = 1.0 - warpedUV.x;
        }
        if (warpedUV.y > 0.5) {
            warpedUV.y = 1.0 - warpedUV.y;
        }
    }

    float2 localUV = frac((warpedUV * uv_size - float2(0.0, 0.0)) / texSize);
    fragColor = nmSample(localUV);
    return fragColor;
}
