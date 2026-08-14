<div align="center">

# Blob Flutter (3D Particle Blob)

**A high-performance, interactive 3D particle blob for Flutter powered by procedural noise algorithms, multi-threaded Isolate computation, and GPU Fragment Shaders.**

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
</p>

---

<p align="center">
  <a href="#features"><b>Features</b></a> •
  <a href="#procedural-noise-algorithms"><b>Noise Algorithms</b></a> •
  <a href="#quick-start"><b>Quick Start</b></a> •
  <a href="#controller-usage"><b>Controller</b></a> •
  <a href="#customization-properties"><b>Properties</b></a> •
  <a href="#architecture--performance"><b>Architecture</b></a>
</p>

</div>

---

## Table of Contents

- [Features](#features)
- [Procedural Noise Algorithms](#procedural-noise-algorithms)
- [Use Cases](#use-cases)
- [Quick Start](#quick-start)
- [Controller Usage](#controller-usage)
- [Customization Properties](#customization-properties)
  - [Widget Properties (BlobFlutter)](#widget-properties-blobflutter)
  - [Controller Properties and Methods (BlobController)](#controller-properties-and-methods-blobcontroller)
- [Architecture & Performance](#architecture--performance)

---

## Features

* **Multi-Threaded Isolate Engine (Zero-Jank Architecture)**
  * Offloads heavy 3D math and vertex projections to a persistent background `Isolate` on native platforms (iOS, Android, macOS, Windows, Linux).
  * Uses `TransferableTypedData` for zero-copy memory transfers to the UI thread.
  * Native Web fallback executes synchronously without isolate overhead.

* **Procedural 3D Noise Deformation**
  * 7 distinct mathematical noise models, from smooth organic liquid waves to crystalline spiky structures and cellular bubbles.
  * Evaluated via function pointers for constant O(1) runtime dispatch.

* **GPU Fragment Shader Acceleration**
  * Hardware-accelerated per-pixel color gradients via custom GLSL fragment shaders (`shaders/blob.frag`).
  * Single GPU draw call utilizing `Canvas.drawRawPoints`.
  * Support for `LinearGradient`, `RadialGradient`, and `SweepGradient` with exact alignments and up to 4 color stops.
  * Dynamic liquid wave shimmer, configurable color animation speeds, static positioning modes, and HSV rainbow cycling.

* **Fluid Touch & Physics Interaction**
  * Natural multi-touch drag rotation with configurable inertial momentum decay (`dampingFactor`).
  * Touch and hold radial particle dispersion with customizable intensity and radius multipliers.
  * Desktop and Web cursor hover tracking without requiring mouse clicks.

* **Zero-Allocation Render Pipeline**
  * Pre-allocated Fibonacci lattice sphere coordinate buffers.
  * Zero heap object allocations during the render loop.
  * Selective widget repainting using `ValueNotifier` and frame generation counters.
  * Display refresh-rate independent ticker calculations (smooth at 60Hz, 120Hz, and VRR).

---

## Procedural Noise Algorithms

The `BlobNoiseType` enum provides 7 distinct mathematical displacement models:

| Noise Type | Mathematical Basis | Visual Characteristics |
| :--- | :--- | :--- |
| `BlobNoiseType.harmonic` | Harmonic sine-cosine superposition | Smooth, organic, fluid liquid blob motion. |
| `BlobNoiseType.spiky` | Exponential power-law ridges | Sharp peaks, crystalline spikes, urchin/virus geometries. |
| `BlobNoiseType.fractal` | Fractional Brownian Motion (fBm) | Multi-octave turbulent cloud and terrain surface details. |
| `BlobNoiseType.cellular` | Worley cellular distance field | Segmented clusters, biological cells, and organic bubbles. |
| `BlobNoiseType.vortex` | Angular Y-axis rotational shear | Swirling cyclone, spiral galaxy, and tornado deformation. |
| `BlobNoiseType.sphericalHarmonics` | Spherical standing wave harmonics | Acoustic cymatics, nodal patterns, and quantum orbital fields. |
| `BlobNoiseType.simplex` | 3D Simplex gradient noise | Omni-directional, artifact-free smooth liquid flow. |

---

## Use Cases

- **AI Voice Assistants**: Responsive, futuristic visual core that reacts to speech amplitude and frequency.
- **Audio Visualizers**: Bind sound frequencies directly to `dispersion`, `blobiness`, and `speed`.
- **Loading & Onboarding Screens**: Fluid, high-framerate interactive 3D centerpiece.
- **Hero & Landing Sections**: Interactive background or focal element on Web and Desktop applications.

---

## Quick Start

1. Add `blob_flutter` to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  blob_flutter: ^1.0.0
```

2. Import the library:

```dart
import 'package:blob_flutter/blob_flutter.dart';
```

3. Place `BlobFlutter` in your widget tree:

```dart
BlobFlutter(
  particleCount: 5000,
  radius: 150.0,
  pointSize: 2.0,
  noiseType: BlobNoiseType.harmonic,
  gradient: LinearGradient(
    colors: [Colors.cyanAccent, Colors.purpleAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
)
```

---

## Controller Usage

The `BlobController` allows full programmatic control over geometry, noise algorithms, animation velocity, physics damping, and shader properties at runtime.

```dart
class MyBlobScreen extends StatefulWidget {
  const MyBlobScreen({super.key});

  @override
  State<MyBlobScreen> createState() => _MyBlobScreenState();
}

class _MyBlobScreenState extends State<MyBlobScreen> {
  late final BlobController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BlobController(
      dampingFactor: 0.95,
      tapScaleFactor: 1.0,
      touchRadiusFactor: 1.0,
      noiseType: BlobNoiseType.simplex,
      isColorAnimated: true,
      colorAnimationSpeed: 1.2,
      waveIntensity: 1.0,
      enableHover: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerPulse() {
    // Dynamic runtime modifications
    _controller.setBlobiness(2.5);
    _controller.setDispersion(1.5);
    _controller.setSpeed(2.0);
    _controller.setNoiseType(BlobNoiseType.spiky);
    _controller.setAutoRotationSpeed(1.2);
    _controller.setIsRainbowMode(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: BlobFlutter(
          controller: _controller,
          particleCount: 6000,
          radius: 160.0,
          pointSize: 2.2,
        ),
      ),
    );
  }
}
```

---

## Customization Properties

### Widget Properties (`BlobFlutter`)

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `particleCount` | `int` | `5000` | Total number of particles distributed over the Fibonacci sphere. |
| `radius` | `double` | `150.0` | Base radius of the 3D sphere in logical pixels. |
| `pointSize` | `double` | `2.0` | Diameter of each rendered particle point in logical pixels. |
| `controller` | `BlobController?` | `null` | Optional external controller for programmatic manipulation. |
| `noiseType` | `BlobNoiseType` | `BlobNoiseType.harmonic` | Procedural 3D noise algorithm used for deformation. |
| `gradient` | `Gradient` | `LinearGradient(...)` | Color gradient. Supports `LinearGradient`, `RadialGradient`, and `SweepGradient`. |
| `tapScaleFactor` | `double` | `1.0` | Scale multiplier for particle dispersion upon touch/click interaction. |
| `touchRadiusFactor` | `double` | `1.0` | Multiplier for the spatial influence radius of touch points. |
| `isColorAnimated` | `bool` | `true` | When `true`, animates the color gradient flow across the surface. |
| `colorAnimationSpeed` | `double` | `1.0` | Speed multiplier for color waves. Set to `0.0` for static gradient colors. |
| `waveIntensity` | `double` | `1.0` | Intensity of liquid wave distortion in the fragment shader. |
| `enableHover` | `bool` | `false` | Enables particle dispersion and interaction on mouse cursor movement. |

### Controller Properties and Methods (`BlobController`)

| Property / Setter | Type | Default | Valid Range | Description |
| :--- | :--- | :--- | :--- | :--- |
| `blobiness` / `setBlobiness()` | `double` | `1.0` | `0.0` - `5.0` | Amplitude of noise displacement from a perfect sphere. |
| `speed` / `setSpeed()` | `double` | `1.0` | `0.0` - `10.0` | Playback speed multiplier for procedural noise animation. |
| `dispersion` / `setDispersion()` | `double` | `0.0` | `0.0` - `3.0` | Base outward radial displacement of particles. |
| `dampingFactor` / `setDampingFactor()` | `double` | `0.92` | `0.0` - `1.0` | Momentum retention rate per frame for drag rotations. |
| `autoRotationSpeed` / `setAutoRotationSpeed()` | `double` | `0.5` | `-3.0` - `3.0` | Continuous rotational velocity around the Y-axis. |
| `noiseFrequency` / `setNoiseFrequency()` | `double` | `1.0` | `0.1` - `5.0` | Spatial frequency and density of noise ripples. |
| `noiseType` / `setNoiseType()` | `BlobNoiseType` | `BlobNoiseType.harmonic` | Enum | The active procedural deformation algorithm. |
| `viewDistance` / `setViewDistance()` | `double` | `2.0` | `0.8` - `5.0` | Distance of the 3D perspective camera from the origin. |
| `tapScaleFactor` / `setTapScaleFactor()` | `double` | `1.0` | `>= 0.0` | Multiplier for particle dispersion upon touch/click. |
| `touchRadiusFactor` / `setTouchRadiusFactor()` | `double` | `1.0` | `0.1` - `10.0` | Radius of influence for touch points. |
| `isRainbowMode` / `setIsRainbowMode()` | `bool` | `false` | Boolean | Cycles colors dynamically through the HSV rainbow spectrum. |
| `isColorAnimated` / `setIsColorAnimated()` | `bool` | `true` | Boolean | Enables or disables gradient animation flow. |
| `colorAnimationSpeed` / `setColorAnimationSpeed()` | `double` | `1.0` | `0.0` - `10.0` | Speed of gradient flow across the blob surface. |
| `waveIntensity` / `setWaveIntensity()` | `double` | `1.0` | `0.0` - `5.0` | Wave distortion intensity applied to the shader. |
| `enableHover` / `setEnableHover()` | `bool` | `false` | Boolean | Enables or disables mouse hover interactions. |
| `gradient` / `setGradient()` | `Gradient?` | `null` | Gradient | Dynamic runtime override for the widget's color gradient. |
| `addRotationImpulse(Offset)` | `void` | - | - | Applies an immediate rotational impulse from gesture deltas. |
| `resetRotation()` | `void` | - | - | Instantly resets accumulated rotational angles to zero. |

---

## Architecture & Performance

`BlobFlutter` is engineered to deliver sustained 60 FPS and 120 FPS performance:

1. **Persistent Worker Isolate**: On native platforms, 3D trigonometric deformations, matrix rotations, and camera projections execute inside a dedicated background worker (`BlobWorker`). The UI isolate receives transformed vertices via `TransferableTypedData` with zero memory copy overhead.
2. **Single GPU Draw Call**: Particle coordinates are consolidated into a flat `Float32List` buffer and dispatched directly to the graphics hardware using `Canvas.drawRawPoints` and a reused `Paint` instance.
3. **Zero Heap Allocation Render Loop**: Coordinate caches, sine tables, and intermediate calculation buffers are pre-allocated during initialization, avoiding Garbage Collector (GC) pauses during animation.
4. **Selective Subtree Repaint**: Uses `ValueNotifier` and integer generation keys to ensure only the `CustomPainter` canvas repaints, eliminating unnecessary rebuilds of parent or child widgets.
5. **Hardware Shader Pipelines**: Complex color interpolation, multi-stop gradient geometry (`Linear`, `Radial`, `Sweep`), and organic shimmer waves run entirely on the GPU via custom GLSL shaders (`ui.FragmentProgram`).
