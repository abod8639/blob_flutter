<div align="center">

# Particle Blob 3D

**A high-performance, interactive 3D particle blob for Flutter with advanced mathematical morphing and shader support.**

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
</p>

---

<p align="center">
  <a href="#features"><b>Features</b></a> •
  <a href="#quick-start"><b>Quick Start</b></a> •
  <a href="#controller-usage"><b>Controller</b></a> •
  <a href="#architecture--performance"><b>Performance</b></a>
</p>

</div>

---

## Table of Contents

- [Features](#features)
- [Use Cases](#use-cases)
- [Quick Start](#quick-start)
- [Controller Usage](#controller-usage)
- [Customization Properties](#customization-properties)
- [Architecture & Performance](#architecture--performance)

---

## Features

* **Advanced 3D Math Engine**
  * **Fibonacci Sphere Distribution**: Evenly distributes thousands of particles in a perfect 3D sphere geometry.
  * **Organic Morphing**: Extremely fast 3D sine-wave noise algorithm morphs the sphere into organic, shifting blob shapes.
  * **Fluid Interactions**: 
    * **Drag**: Rotate the blob with natural physics and inertia.
    * **Tap & Hold**: Radially disperse particles away from your touch point dynamically.
    * **Hover**: Subtle rotation tracking for web and desktop platforms.

* **Ultra-High Performance**
  * **GPU-accelerated coloring** via `ui.FragmentShader` and `Canvas.drawRawPoints`.
  * **Zero-Allocation Render Loop**: Uses precalculated trigonometric caches and purely local CPU registers to maintain rock-solid 60/120 FPS without Garbage Collection (GC) stutters.

* **Rich Customization**
  * Tweak particle count, blobiness, rotation speed, and point size.
  * Inject custom GPU gradient colors (`color1` & `color2`).
  * Full external programmatic control via `ParticleBlobController`.

---

## Use Cases

Perfect for creating stunning, futuristic visual effects in:

- **AI Voice Assistants** - Make a glowing, responding AI core that reacts to voice.
- **Loading Screens** - Keep users mesmerized while heavy data loads.
- **Hero Sections** - Enhance app landing pages with interactive 3D elements.
- **Audio Visualizers** - Connect controller properties (`dispersion`, `blobiness`) to audio frequency bands.

---

## Quick Start

1. Import the package:
```dart
import 'package:blob_flutter/blob_flutter.dart';
```

2. Add it to your widget tree:
```dart
ParticleBlob(
  particleCount: 5000,
  radius: 130,
  pointSize: 2.0,
  tapScaleFactor: 1.0,
  gradient: LinearGradient(
    colors: [Colors.pinkAccent, Colors.deepPurpleAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
)
```

---

## Controller Usage

You can use the `ParticleBlobController` to programmatically change the blob's shape, speed, and interaction state at runtime. This is great for animating the blob during external events or linking it to user interface controls.

```dart
final ParticleBlobController _controller = ParticleBlobController(
  dampingFactor: 0.93, // Inertia applied to rotations (0.0 - 1.0)
  tapScaleFactor: 1.0, // Scale multiplier for touch dispersion
);

// Programmatic updates:
_controller.setBlobiness(2.5);        // Increase noise distortion (0.0 to 5.0)
_controller.setSpeed(3.0);            // Animation speed multiplier (0.0 to 10.0)
_controller.setDispersion(0.8);       // Blow particles outwards radially (0.0 to 3.0)
_controller.setAutoRotationSpeed(1.0); // Constant background rotation speed (-3.0 to 3.0)
_controller.setNoiseFrequency(2.0);   // Spikiness/density of waves (0.1 to 5.0)
_controller.setViewDistance(2.0);      // Perspective camera distance (0.8 to 5.0)
_controller.setIsRainbowMode(true);   // Cycle colors through rainbow spectrum

// Don't forget to dispose!
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

---

## Customization Properties

### Widget Properties (`ParticleBlob`)

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `particleCount` | `int` | `5000` | Total number of particles to render. |
| `radius` | `double` | `150.0` | Base radius of the 3D sphere in logical pixels. |
| `pointSize` | `double` | `2.0` | Render size of each individual particle. |
| `tapScaleFactor` | `double` | `1.0` | Scale multiplier applied to particle dispersion on touch/tap. |
| `gradient` | `Gradient` | `LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent])` | The gradient colors used to color the particles. |
| `controller` | `ParticleBlobController?`| `null` | External controller for runtime physics and animation changes. |

### Controller Configuration & Properties (`ParticleBlobController`)

| Property/Method | Type | Default | Range | Description |
| :--- | :--- | :--- | :--- | :--- |
| `dampingFactor` | `double` | `0.92` | `0.0` - `1.0` | Speed at which drag rotation decays. |
| `tapScaleFactor` | `double` | `1.0` | `>= 0.0` | Dispersion scale multiplier. |
| `blobiness` / `setBlobiness()` | `double` | `1.0` | `0.0` - `5.0` | Noise amplitude (displacement from perfect sphere). |
| `speed` / `setSpeed()` | `double` | `1.0` | `0.0` - `10.0` | Animation speed multiplier. |
| `dispersion` / `setDispersion()` | `double` | `0.0` | `0.0` - `3.0` | Manual base radial dispersion. |
| `autoRotationSpeed` / `setAutoRotationSpeed()` | `double` | `0.5` | `-3.0` - `3.0` | Continuous spin velocity. |
| `noiseFrequency` / `setNoiseFrequency()` | `double` | `1.0` | `0.1` - `5.0` | Wave density/frequency. |
| `viewDistance` / `setViewDistance()` | `double` | `2.0` | `0.8` - `5.0` | 3D perspective camera/view distance. |
| `isRainbowMode` / `setIsRainbowMode()` | `bool` | `false` | `true`/`false` | Cycle colors through the HSV rainbow. |

---

## Architecture & Performance

`ParticleBlob` is meticulously designed to sidestep common Flutter performance traps:

1. **Draw Calls**: Rendering 5,000 individual `Container` widgets would crash the rendering thread. Instead, `ParticleBlob` generates a flat `Float32List` array of coordinates and passes it directly to `Canvas.drawRawPoints`, completing rendering in a **single GPU draw call**.
2. **GC Pressure**: The rendering loop creates **zero** objects per frame. All trigonometric operations are pre-calculated, math variables are assigned directly to CPU registers, and the output `Float32List` is mutated entirely in-place.
3. **Fragment Shaders**: Instead of calculating colors on the CPU, the library loads a custom `.frag` asset to apply beautiful 3D-aware gradients entirely on the GPU.
