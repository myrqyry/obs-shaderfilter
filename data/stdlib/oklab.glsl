// Perceptual color helpers for native OBS effect/HLSL shaders.
// Matrices adapted from Gimle Larpes' potatoFX/Shaders/Oklab.fxh (MIT),
// which follows Björn Ottosson's Oklab implementation.
// https://github.com/GimleLarpes/potatoFX
// Source MIT notice: ../examples/potatofx-ports/POTATOFX-LICENSE.txt
// ONLY SDR sRGB encoding here: these helpers do not infer the OBS source's
// transfer function and MUST NOT be advertised as HDR10/HLG/scRGB converters.
#ifndef OBS_PERCEPTUAL_OKLAB_GLSL
#define OBS_PERCEPTUAL_OKLAB_GLSL

float pfDecodeChannel(float x) {
    x = saturate(x);
    return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4);
}
float pfEncodeChannel(float x) {
    x = max(x, 0.0);
    return x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1.0 / 2.4) - 0.055;
}
float3 pfSrgbToLinear(float3 c) {
    return float3(pfDecodeChannel(c.x), pfDecodeChannel(c.y), pfDecodeChannel(c.z));
}
float3 pfLinearToSrgb(float3 c) {
    return float3(pfEncodeChannel(c.x), pfEncodeChannel(c.y), pfEncodeChannel(c.z));
}
float3 pfLinearToOklab(float3 c) {
    float l = pow(max(dot(c, float3(0.4122214708, 0.5363325363, 0.0514459929)), 0.0), 1.0 / 3.0);
    float m = pow(max(dot(c, float3(0.2119034982, 0.6806995451, 0.1073969566)), 0.0), 1.0 / 3.0);
    float s = pow(max(dot(c, float3(0.0883024619, 0.2817188376, 0.6299787005)), 0.0), 1.0 / 3.0);
    return float3(0.2104542553*l + 0.7936177850*m - 0.0040720468*s,
                  1.9779984951*l - 2.4285922050*m + 0.4505937099*s,
                  0.0259040371*l + 0.7827717662*m - 0.8086757660*s);
}
float3 pfOklabToLinear(float3 c) {
    float l = c.x + 0.3963377774*c.y + 0.2158037573*c.z;
    float m = c.x - 0.1055613458*c.y - 0.0638541728*c.z;
    float s = c.x - 0.0894841775*c.y - 1.2914855480*c.z;
    l = l*l*l;
    m = m*m*m;
    s = s*s*s;
    return float3(4.0767416621*l - 3.3077115913*m + 0.2309699292*s,
                 -1.2684380046*l + 2.6097574011*m - 0.3413193965*s,
                 -0.0041960863*l - 0.7034186147*m + 1.7076147010*s);
}
float3 pfOklabToLch(float3 c) {
    float chroma = length(c.yz);
    // An achromatic color has no hue; avoid undefined atan2(0, 0).
    if (chroma <= 1.0e-6) return float3(c.x, 0.0, 0.0);
    return float3(c.x, chroma, atan(c.z, c.y));
}
float3 pfLchToOklab(float3 c) {
    return float3(c.x, c.y * cos(c.z), c.y * sin(c.z));
}
#endif
