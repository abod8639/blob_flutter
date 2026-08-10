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

vec4 evaluateColor(float t) {
    if (uColorCount <= 1.5) {
        return uColor1;
    } else if (uColorCount <= 2.5) {
        return mix(uColor1, uColor2, t);
    } else if (uColorCount <= 3.5) {
        if (t <= 0.5) {
            return mix(uColor1, uColor2, t * 2.0);
        } else {
            return mix(uColor2, uColor3, (t - 0.5) * 2.0);
        }
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

void main() {
    // Normalize fragment coordinate to [0.0, 1.0] UV space
    vec2 uv = FlutterFragCoord().xy / uResolution;

    float t = 0.0;

    if (uGradientType < 0.5) {
        // Linear gradient from uGradientStart to uGradientEnd
        vec2 dir = uGradientEnd - uGradientStart;
        float lenSq = dot(dir, dir);
        if (lenSq > 0.00001) {
            t = dot(uv - uGradientStart, dir) / lenSq;
        } else {
            t = uv.y;
        }
    } else if (uGradientType < 1.5) {
        // Radial gradient from uGradientStart with radius uGradientEnd.x
        float r = max(uGradientEnd.x, 0.001);
        t = length(uv - uGradientStart) / r;
    } else {
        // Sweep / Angular gradient around uGradientStart
        vec2 sweepDir = uv - uGradientStart;
        float angle = atan(sweepDir.y, sweepDir.x); // [-PI, PI]
        t = (angle + 3.141592653589793) / (2.0 * 3.141592653589793);
    }

    // Apply animated wave/shimmer distortion if animated and wave intensity > 0
    if (uColorAnimationSpeed > 0.0 && uWaveIntensity > 0.0) {
        float animTime = uTime * uColorAnimationSpeed;
        float wave1 = sin(uv.x * 3.14159265 + animTime * 0.5) * 0.25;
        float wave2 = cos(uv.y * 3.14159265 - animTime * 0.3) * 0.15;
        float shimmer = sin((uv.x + uv.y) * 6.2831853 + animTime * 1.2) * 0.05;
        t += (wave1 + wave2 + shimmer) * uWaveIntensity;
    }

    t = clamp(t, 0.0, 1.0);

    fragColor = evaluateColor(t);
}
