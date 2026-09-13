/// Particle Blob Fragment Shader
///
/// Applies a dynamic or static, customizable gradient to all blob particles.
/// Supports Linear, Radial, and Sweep gradients with up to 4 colors,
/// customizable alignment/position, and controllable wave animation speed.
///
/// Uniform layout (flat float index via setFloat):
///   0-1  : uResolution          (vec2)  — viewport size in pixels
///   2    : uTime                (float) — elapsed animation time
///   3-6  : uColor1              (vec4)  — 1st color (RGBA, normalized)
///   7-10 : uColor2              (vec4)  — 2nd color (RGBA, normalized)
///   11-14: uColor3              (vec4)  — 3rd color (RGBA, normalized)
///   15-18: uColor4              (vec4)  — 4th color (RGBA, normalized)
///   19-22: uColor5              (vec4)  — 5th color (RGBA, normalized)
///   23-26: uColor6              (vec4)  — 6th color (RGBA, normalized)
///   27-30: uColor7              (vec4)  — 7th color (RGBA, normalized)
///   31-34: uColor8              (vec4)  — 8th color (RGBA, normalized)
///   35-36: uGradientStart       (vec2)  — normalized UV start / center [0.0, 1.0]
///   37-38: uGradientEnd         (vec2)  — normalized UV end / radius
///   39   : uColorAnimationSpeed (float) — color animation speed (0.0 = static)
///   40   : uGradientType        (float) — 0.0 = Linear, 1.0 = Radial, 2.0 = Sweep
///   41   : uWaveIntensity       (float) — wave shimmer intensity (0.0 = pure gradient, 1.0 = liquid)
///   42   : uColorCount          (float) — number of active colors (1.0 to 8.0)
///   43-46: uStops1              (vec4)  — color stops 1 to 4 [0.0, 1.0]
///   47-50: uStops2              (vec4)  — color stops 5 to 8 [0.0, 1.0]
///
/// Total: 51 floats.

#version 460 core

precision highp float;

#include <flutter/runtime_effect.glsl>

// ── Mathematical Constants ────────────────────────────────────────────────────
const float PI     = 3.14159265358979;
const float TWO_PI = 6.28318530717958;

// ── Uniforms ─────────────────────────────────────────────────────────────────
uniform vec2  uResolution;
uniform float uTime;
uniform vec4  uColor1;
uniform vec4  uColor2;
uniform vec4  uColor3;
uniform vec4  uColor4;
uniform vec4  uColor5;
uniform vec4  uColor6;
uniform vec4  uColor7;
uniform vec4  uColor8;
uniform vec2  uGradientStart;
uniform vec2  uGradientEnd;
uniform float uColorAnimationSpeed;
uniform float uGradientType;
uniform float uWaveIntensity;
uniform float uColorCount;
uniform vec4  uStops1;
uniform vec4  uStops2;

out vec4 fragColor;

// ── Colour Evaluation ─────────────────────────────────────────────────────────
//
// Evaluates colors based on custom gradient stops (uStops1, uStops2) and uColorCount.
// If stops are evenly distributed, behaves identically to equidistant interpolation.
// If custom stops are specified (e.g. [0.0, 0.2, 1.0]), interpolates strictly within
// the matched stop interval.
vec4 evaluateColor(float t) {
    if (uColorCount <= 1.5) {
        return uColor1;
    }

    float s0 = uStops1.x;
    float s1 = uStops1.y;
    float s2 = uStops1.z;
    float s3 = uStops1.w;
    float s4 = uStops2.x;
    float s5 = uStops2.y;
    float s6 = uStops2.z;
    float s7 = uStops2.w;

    if (t <= s0) {
        return uColor1;
    }

    if (uColorCount <= 2.5 || t <= s1) {
        float d = max(s1 - s0, 0.00001);
        float f = clamp((t - s0) / d, 0.0, 1.0);
        return mix(uColor1, uColor2, f);
    }
    if (uColorCount <= 3.5 || t <= s2) {
        float d = max(s2 - s1, 0.00001);
        float f = clamp((t - s1) / d, 0.0, 1.0);
        return mix(uColor2, uColor3, f);
    }
    if (uColorCount <= 4.5 || t <= s3) {
        float d = max(s3 - s2, 0.00001);
        float f = clamp((t - s2) / d, 0.0, 1.0);
        return mix(uColor3, uColor4, f);
    }
    if (uColorCount <= 5.5 || t <= s4) {
        float d = max(s4 - s3, 0.00001);
        float f = clamp((t - s3) / d, 0.0, 1.0);
        return mix(uColor4, uColor5, f);
    }
    if (uColorCount <= 6.5 || t <= s5) {
        float d = max(s5 - s4, 0.00001);
        float f = clamp((t - s4) / d, 0.0, 1.0);
        return mix(uColor5, uColor6, f);
    }
    if (uColorCount <= 7.5 || t <= s6) {
        float d = max(s6 - s5, 0.00001);
        float f = clamp((t - s5) / d, 0.0, 1.0);
        return mix(uColor6, uColor7, f);
    }

    float d = max(s7 - s6, 0.00001);
    float f = clamp((t - s6) / d, 0.0, 1.0);
    return mix(uColor7, uColor8, f);
}

// ── Main ──────────────────────────────────────────────────────────────────────
void main() {
    // Normalize fragment coordinate to [0.0, 1.0] UV space
    vec2 uv = FlutterFragCoord().xy / uResolution;

    float t = 0.0;

    if (uGradientType < 0.5) {
        // Linear gradient from uGradientStart to uGradientEnd
        vec2  dir   = uGradientEnd - uGradientStart;
        float lenSq = dot(dir, dir);
        t = lenSq > 0.00001
            ? dot(uv - uGradientStart, dir) / lenSq
            : uv.y;

    } else if (uGradientType < 1.5) {
        // Radial gradient centred on uGradientStart, radius = uGradientEnd.x
        float r = max(uGradientEnd.x, 0.001);
        t = length(uv - uGradientStart) / r;

    } else {
        // Sweep / Angular gradient around uGradientStart
        vec2  dir   = uv - uGradientStart;
        float angle = atan(dir.y, dir.x);          // [-PI, PI]
        t = (angle + PI) / TWO_PI;
    }

    // Wave shimmer — only computed when animation is active.
    // Both conditions are uniforms (same value for every fragment), so the
    // branch causes zero GPU warp divergence.
    if (uColorAnimationSpeed > 0.0 && uWaveIntensity > 0.0) {
        float anim    = uTime * uColorAnimationSpeed;
        float wave1   = sin(uv.x * PI     + anim * 0.5) * 0.25;
        float wave2   = cos(uv.y * PI     - anim * 0.3) * 0.15;
        float shimmer = sin((uv.x + uv.y) * TWO_PI + anim * 1.2) * 0.05;
        t += (wave1 + wave2 + shimmer) * uWaveIntensity;
    }

    fragColor = evaluateColor(clamp(t, 0.0, 1.0));
}
