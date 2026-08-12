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
///   19-20: uGradientStart       (vec2)  — normalized UV start / center [0.0, 1.0]
///   21-22: uGradientEnd         (vec2)  — normalized UV end / radius
///   23   : uColorAnimationSpeed (float) — color animation speed (0.0 = static)
///   24   : uGradientType        (float) — 0.0 = Linear, 1.0 = Radial, 2.0 = Sweep
///   25   : uWaveIntensity       (float) — wave shimmer intensity (0.0 = pure gradient, 1.0 = liquid)
///   26   : uColorCount          (float) — number of active colors (1.0 to 4.0)
///
/// Total: 27 floats.

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
uniform vec2  uGradientStart;
uniform vec2  uGradientEnd;
uniform float uColorAnimationSpeed;
uniform float uGradientType;
uniform float uWaveIntensity;
uniform float uColorCount;

out vec4 fragColor;

// ── Colour Evaluation ─────────────────────────────────────────────────────────
//
// uColorCount is a uniform — identical for every fragment in the draw call, so
// these branches are "uniform branches" with negligible GPU overhead (no warp
// divergence).  The compiler typically flattens them into conditional moves.
vec4 evaluateColor(float t) {
    if (uColorCount <= 1.5) {
        return uColor1;
    } else if (uColorCount <= 2.5) {
        return mix(uColor1, uColor2, t);
    } else if (uColorCount <= 3.5) {
        return t <= 0.5
            ? mix(uColor1, uColor2, t * 2.0)
            : mix(uColor2, uColor3, (t - 0.5) * 2.0);
    } else {
        if (t <= 0.333333) {
            return mix(uColor1, uColor2, t * 3.0);
        } else if (t <= 0.666666) {
            return mix(uColor2, uColor3, (t - 0.333333) * 3.0);
        } else {
            return mix(uColor3, uColor4, (t - 0.666666) * 3.0);
        }
    }
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
