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
///
/// Total: 43 floats.

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

out vec4 fragColor;

// ── Colour Evaluation ─────────────────────────────────────────────────────────
//
// Smoothly evaluates up to 8 colors across [0.0, 1.0] based on uColorCount.
// uColorCount is a uniform identical for every fragment, yielding zero warp divergence.
vec4 evaluateColor(float t) {
    if (uColorCount <= 1.5) {
        return uColor1;
    }
    float segments = uColorCount - 1.0;
    float scaled = clamp(t * segments, 0.0, segments);
    float idx = min(floor(scaled), segments - 1.0);
    float f = scaled - idx;

    vec4 cA = uColor1;
    vec4 cB = uColor2;

    if (idx < 0.5) {
        cA = uColor1;
        cB = uColor2;
    } else if (idx < 1.5) {
        cA = uColor2;
        cB = uColor3;
    } else if (idx < 2.5) {
        cA = uColor3;
        cB = uColor4;
    } else if (idx < 3.5) {
        cA = uColor4;
        cB = uColor5;
    } else if (idx < 4.5) {
        cA = uColor5;
        cB = uColor6;
    } else if (idx < 5.5) {
        cA = uColor6;
        cB = uColor7;
    } else {
        cA = uColor7;
        cB = uColor8;
    }

    return mix(cA, cB, f);
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
