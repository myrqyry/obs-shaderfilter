/*
 * Derived from Glyphfield's shaders-soft-register material by Kevin Liu (c) 2026.
 * MIT licensed; full copyright and permission notice in docs/GLYPHFIELD_SOFT_REGISTER.md.
 * Adapted for CrossTL WGSL builtins, helper outputs, and WGSL parameter mutability.
 */
#version 300 es
precision highp float;
precision highp int;

uniform vec2 u_resolution;
uniform vec2 u_pointer;
uniform float u_time;
uniform vec3 u_color_a;
uniform vec3 u_color_b;
uniform vec3 u_color_c;
uniform vec3 u_lab_a;
uniform vec3 u_lab_b;
uniform vec3 u_lab_c;
uniform float u_strength;
uniform float u_detail;
uniform float u_frequency;
uniform float u_grain;
uniform float u_amplitude;
uniform float u_density;
uniform float u_brightness;
uniform float u_rotation;
uniform float u_scale;

out vec4 fragColor;

const float PI = 3.14159265359;
const float TAU = 6.28318530718;
// Patterns are sized in a 900px-tall reference frame so previews and large exports match.
const float REFERENCE_HEIGHT = 900.0;
const mat2 OCTAVE = mat2(1.6, 1.2, -1.2, 1.6);


float seamlessAngularWave(float angle, float frequency, float phase, float minimumCycles) {
  float cycles = max(minimumCycles, floor(abs(frequency) + 0.5));
  return sin(angle * cycles + phase);
}

float seamlessAngularWarp(float angle, float phase) {
  return sin(angle + phase) * 0.34 + sin(angle * 2.0 - phase * 0.625) * 0.08;
}


// Hash without sine (Dave Hoskins, MIT): stable across GPUs, unlike fract(sin()).
float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash33(vec3 p3Initial) {
  vec3 p3 = p3Initial;
  p3 = fract(p3 * vec3(0.1031, 0.103, 0.0973));
  p3 += dot(p3, p3.yxz + 33.33);
  return fract((p3.xxy + p3.yxx) * p3.zyx);
}

// Quintic gradient noise, roughly -1..1.
float gnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  float a = dot(hash22(i) * 2.0 - 1.0, f);
  float b = dot(hash22(i + vec2(1.0, 0.0)) * 2.0 - 1.0, f - vec2(1.0, 0.0));
  float c = dot(hash22(i + vec2(0.0, 1.0)) * 2.0 - 1.0, f - vec2(0.0, 1.0));
  float d = dot(hash22(i + vec2(1.0)) * 2.0 - 1.0, f - vec2(1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 1.6;
}

float gnoise(vec3 p) {
  vec3 i = floor(p);
  vec3 f = fract(p);
  vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  float n000 = dot(hash33(i) * 2.0 - 1.0, f);
  float n100 = dot(hash33(i + vec3(1.0, 0.0, 0.0)) * 2.0 - 1.0, f - vec3(1.0, 0.0, 0.0));
  float n010 = dot(hash33(i + vec3(0.0, 1.0, 0.0)) * 2.0 - 1.0, f - vec3(0.0, 1.0, 0.0));
  float n110 = dot(hash33(i + vec3(1.0, 1.0, 0.0)) * 2.0 - 1.0, f - vec3(1.0, 1.0, 0.0));
  float n001 = dot(hash33(i + vec3(0.0, 0.0, 1.0)) * 2.0 - 1.0, f - vec3(0.0, 0.0, 1.0));
  float n101 = dot(hash33(i + vec3(1.0, 0.0, 1.0)) * 2.0 - 1.0, f - vec3(1.0, 0.0, 1.0));
  float n011 = dot(hash33(i + vec3(0.0, 1.0, 1.0)) * 2.0 - 1.0, f - vec3(0.0, 1.0, 1.0));
  float n111 = dot(hash33(i + vec3(1.0)) * 2.0 - 1.0, f - vec3(1.0));
  return mix(
    mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
    mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y),
    u.z
  ) * 1.5;
}

float fbm(vec2 pInitial, int octaves) {
  vec2 p = pInitial;
  float value = 0.0;
  float amplitude = 0.5;
  for (int index = 0; index < 6; index++) {
    if (index >= octaves) break;
    value += amplitude * gnoise(p);
    p = OCTAVE * p + 11.7;
    amplitude *= 0.5;
  }
  return value;
}

// Time is a third noise axis, so fields evolve instead of sliding.
float fbm(vec3 pInitial, int octaves) {
  vec3 p = pInitial;
  float value = 0.0;
  float amplitude = 0.5;
  for (int index = 0; index < 6; index++) {
    if (index >= octaves) break;
    value += amplitude * gnoise(p);
    p = vec3(OCTAVE * p.xy, p.z * 1.7) + 7.3;
    amplitude *= 0.5;
  }
  return value;
}

vec2 warp(vec2 p, float time, float amount, int octaves) {
  return p + vec2(fbm(vec3(p, time), octaves), fbm(vec3(p + vec2(5.2, 1.3), time), octaves)) * amount;
}

vec2 studioUvAt(vec2 fragCoord) {
  vec2 p = fragCoord / u_resolution.xy * 2.0 - 1.0;
  p.x *= u_resolution.x / u_resolution.y;
  p /= max(0.1, u_scale);
  float angle = radians(u_rotation);
  return mat2(cos(angle), -sin(angle), sin(angle), cos(angle)) * p;
}

vec2 studioUv(vec2 fragCoord) {
  return studioUvAt(fragCoord);
}

vec2 referenceCoord(vec2 fragCoord) {
  return fragCoord * (REFERENCE_HEIGHT / u_resolution.y);
}

vec2 referenceToFrag(vec2 reference) {
  return reference * (u_resolution.y / REFERENCE_HEIGHT);
}

vec3 oklabToLinear(vec3 lab) {
  float l = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z;
  float m = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z;
  float s = lab.x - 0.0894841775 * lab.y - 1.291485548 * lab.z;
  l = l * l * l;
  m = m * m * m;
  s = s * s * s;
  return max(vec3(0.0), vec3(
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s
  ));
}

vec3 paletteLab(float tInitial) {
  float t = tInitial;
  t = clamp(t, 0.0, 1.0);
  return t < 0.5 ? mix(u_lab_a, u_lab_b, t * 2.0) : mix(u_lab_b, u_lab_c, t * 2.0 - 1.0);
}

// Perceptual three-stop ramp: no muddy midpoints between palette colors.
vec3 ramp(float t) {
  return oklabToLinear(paletteLab(t));
}

vec3 mixLab(vec3 from, vec3 to, float t) {
  return oklabToLinear(mix(from, to, t));
}

float luma(vec3 color) {
  return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 spectrum(float phase) {
  vec3 display = 0.5 + 0.5 * cos(TAU * (phase + vec3(0.0, 0.33, 0.67)));
  return display * display;
}

float aastep(float edge, float value) {
  float width = max(fwidth(value), 1e-5) * 0.75;
  return smoothstep(edge - width, edge + width, value);
}

// Coverage of |offset| < halfWidth with a one-pixel soft edge.
float aaband(float offset, float halfWidth) {
  float width = max(fwidth(offset), 1e-5);
  return 1.0 - smoothstep(halfWidth - width, halfWidth + width, abs(offset));
}

int bayerIndex(ivec2 cell) {
  int x = cell.x & 7;
  int y = cell.y & 7;
  int z = x ^ y;
  return ((z & 1) << 5) | ((y & 1) << 4) | ((z & 2) << 2) | ((y & 2) << 1) | ((z & 4) >> 1) | ((y & 4) >> 2);
}

float bayer8(vec2 cell) {
  return (float(bayerIndex(ivec2(floor(cell)))) + 0.5) / 64.0;
}

vec3 linearToSrgb(vec3 colorInitial) {
  vec3 color = colorInitial;
  color = max(color, vec3(0.0));
  return mix(color * 12.92, 1.055 * pow(color, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), color));
}

// Untouched below 0.82; brighter values roll off toward white instead of clipping.
vec3 highlightShoulder(vec3 color) {
  float peak = max(max(color.r, color.g), color.b);
  if (peak <= 0.82) return color;
  float mapped = 0.82 + 0.18 * (1.0 - exp(-(peak - 0.82) / 0.18));
  return mix(color * (mapped / peak), vec3(mapped), clamp((peak - 1.0) * 0.3, 0.0, 0.55));
}

vec4 writeColorWithGrain(vec3 colorInitial, float grainAmount, vec2 fragCoord) {
  vec3 color = colorInitial;
  // Brightness keeps its display-space meaning from earlier versions.
  color = highlightShoulder(max(color, vec3(0.0)) * pow(max(u_brightness, 0.0), 2.2));
  vec3 display = linearToSrgb(color);
  float grainCell = max(1.0, u_resolution.y / 1100.0);
  vec2 grainCoord = floor(fragCoord / grainCell);
  float frame = mod(floor(u_time * 24.0), 61.0);
  float grain = hash12(grainCoord + frame * vec2(17.0, 59.0)) + hash12(grainCoord.yx + frame * vec2(41.0, 23.0)) - 1.0;
  float tone = luma(display);
  display += grain * (grainAmount / 100.0) * 0.2 * (0.55 + 1.8 * tone * (1.0 - tone));
  // Triangular one-step dither removes 8-bit banding from smooth gradients.
  display += (hash12(fragCoord + 0.37) + hash12(fragCoord * 1.31 + 19.19) - 1.0) / 255.0;
  return vec4(clamp(display, 0.0, 1.0), 1.0);
}

vec4 writeColor(vec3 color, vec2 fragCoord) {
  return writeColorWithGrain(color, u_grain, fragCoord);
}

float screenDots(vec2 reference, float angle, float spacing, float tone) {
  vec2 rotated = mat2(cos(angle), -sin(angle), sin(angle), cos(angle)) * reference / spacing;
  float dotDistance = length(fract(rotated) - 0.5);
  float radius = sqrt(clamp(tone, 0.0, 1.0)) * 0.66;
  float width = max(fwidth(rotated.x), 1e-4);
  float dots = 1.0 - smoothstep(radius - width, radius + width, dotDistance);
  return mix(dots, tone * 0.8, smoothstep(0.25, 0.5, width));
}

void main() {
  vec2 p = studioUv(gl_FragCoord.xy);
  float time = u_time * 0.2;
  vec2 q = warp(p * 0.6 * max(0.7, u_detail * 0.32), time, 0.6 + u_strength * 1.4, 4) / 0.6;
  float flow = 0.5 + 0.5 * sin((q.x + q.y * 0.42) * (0.7 + u_frequency * 0.22) + time);
  float counter = 0.5 + 0.5 * sin((q.y - q.x * 0.3) * (0.6 + u_frequency * 0.18) - time * 0.8 + 1.3);

  // Risograph print: two halftone inks multiplied onto light paper, softly misregistered.
  vec2 reference = referenceCoord(gl_FragCoord.xy);
  float spacing = mix(26.0, 12.0, clamp(u_density / 1.5, 0.0, 1.0));
  vec2 registration = vec2(1.6, -1.1) * (0.8 + u_amplitude * 0.15);
  float inkB = screenDots(reference + registration, 0.26, spacing, smoothstep(0.1, 0.95, flow));
  float inkA = screenDots(reference, 1.31, spacing, smoothstep(0.25, 1.0, counter) * 0.85);
  vec3 paper = mixLab(u_lab_c, vec3(0.98, 0.0, 0.0), 0.5);
  vec3 color = paper;
  color *= mix(vec3(1.0), oklabToLinear(u_lab_b) / max(paper, vec3(0.02)), inkB * 0.92);
  color *= mix(vec3(1.0), oklabToLinear(mix(u_lab_a, u_lab_b, 0.25)) / max(paper, vec3(0.02)), inkA * 0.88);
  // Soft underlying wash keeps the tone continuous between dots.
  color = mix(color, ramp(0.3 + flow * 0.6), 0.12 + clamp(u_grain / 100.0, 0.0, 1.0) * 0.1);
  fragColor = writeColorWithGrain(color, u_grain * 0.35, gl_FragCoord.xy);
}