<div align="center">

# Blob Flutter (3D Particle Blob)

[![Cyberpunk Blob Banner](https://github.com/abod8639/media/blob/main/blob_flutter/Picsart_2.png?raw=true)](https://blob-flutter-3d.web.app/)
<!-- ![Cyberpunk Blob Banner](assets/banner.jpg) -->

**A high-performance, interactive 3D particle blob for Flutter.**<br>
*Powered by procedural noise algorithms, multi-threaded Isolate computation, and GPU Fragment Shaders.*

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=&logo=Flutter&logoColor=white)]()
[![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=&logo=dart&logoColor=white)]()

[![Platform](https://img.shields.io/badge/Platform-Flutter%20%7C%20Web%20--%20Linux%20--%20Windows%20--%20MacOS%20--%20Android%20--%20iOS-02569B?style=&logo=flutter)](https://pub.dev/packages/blob_flutter)


[![Pub Points](https://img.shields.io/pub/points/blob_flutter?style=&logo=dart&color=2E8B57)](https://pub.dev/packages/blob_flutter/score)
[![Pub Likes](https://img.shields.io/pub/likes/blob_flutter?style=&logo=flutter&color=blueviolet)](https://pub.dev/packages/blob_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg?style=&)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/abod8639/blob_flutter?style=&logo=github&color=gold)](https://github.com/abod8639/blob_flutter)

[![Codecov](https://img.shields.io/codecov/c/github/abod8639/blob_flutter?style=&logo=codecov&logoColor=white)](https://codecov.io/gh/abod8639/blob_flutter)
[![Pub Version](https://img.shields.io/pub/v/blob_flutter?style=&logo=dart&color=blue)](https://pub.dev/packages/blob_flutter)
[![Live Demo](https://img.shields.io/badge/Live%20Demo-Try%20Online-purple?style=&logo=googlechrome&logoColor=white)](https://blob-flutter-3d.web.app/)

[Live Demo](https://blob-flutter-3d.web.app/) • [Features](#features) • [Quick Start](#quick-start) • [Algorithms](#procedural-noise-algorithms) • [Controller](#controller-usage) • [Error Handling](#error-handling) • [Architecture](#architecture--performance)

</div>

---

<p align="center">
  <img src="https://github.com/abod8639/media/blob/main/blob_flutter/Screenshot_1.png?raw=true" width="24%" alt="Screenshot 1" />
  <img src="https://github.com/abod8639/media/blob/main/blob_flutter/Screenshot_3.png?raw=true" width="24%" alt="Screenshot 3" />
  <img src="https://github.com/abod8639/media/blob/main/blob_flutter/Screenshot_5.png?raw=true" width="24%" alt="Screenshot 5" />
  <img src="https://github.com/abod8639/media/blob/main/blob_flutter/Screenshot_4.png?raw=true" width="24%" alt="Screenshot 4" />
</p>

<p align="center">
  <a href="https://blob-flutter-3d.web.app/">
    <img src="https://img.shields.io/badge/%20Live%20Demo-Experience%20Blob%20Online-purple?style=for-the-badge&logo=googlechrome&logoColor=pink" alt="Live Demo" />
  </a>
</p>

## Features

- **Zero-Jank Architecture**: Offloads heavy 3D math and vertex projections to a persistent background `Isolate`.
- **GPU Fragment Shaders**: Hardware-accelerated per-pixel color gradients (Linear, Radial, Sweep) via custom GLSL.
- **8 Procedural Noise Models**: Smooth liquid waves, crystalline spikes, cellular bubbles, and more.
- **Fluid Touch Interaction**: Natural multi-touch drag rotation, hover tracking, and tap dispersion.
- **Zero-Allocation Pipeline**: Pre-allocated buffers ensure zero heap object allocations during the render loop.
- **Ultra-Fast Path Engine**: Automatically switches to an unbranched, zero-overhead projection pipeline during non-interactive frames, eliminating tens of thousands of redundant pointer and dispersion checks per frame.
- **Resource-Conscious Engineering**: Crafted with rigorous mathematical precision to respect developers and end-user devices—maximizing performance while preventing battery drain and memory thrashing.
- **Error Handling**: Robust error handling to prevent crashes and provide meaningful error messages.

---

## Quick Start

### 1. Install
Add `blob_flutter` to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  blob_flutter: ^1.0.0
```

### 2. Import
```dart
import 'package:blob_flutter/blob_flutter.dart';
```

### 3. Use
The simplest way to render a basic Blob:

```dart
BlobFlutter(
  particleCount: 5000,
  radius: 150.0,
  pointSize: 2.0,
  noiseType: BlobNoiseType.harmonic,
  gradient: const LinearGradient(
    colors: [Colors.cyanAccent, Colors.purpleAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
)
```

---

## Controller Usage

For dynamic runtime control, use the `BlobController`. It allows you to morph geometry, change colors, and tweak physics on the fly.

```dart
class MyBlob extends StatefulWidget {
  @override
  _MyBlobState createState() => _MyBlobState();
}

class _MyBlobState extends State<MyBlob> {
  late BlobController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BlobController(
      particleCount: 5000,
      radius: 150.0,
      noiseType: BlobNoiseType.simplex,
      dampingFactor: 0.95,
      isColorAnimated: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () => _controller.setNoiseType(BlobNoiseType.spiky),
      child: BlobFlutter(
        controller: _controller,
      ),
    );
  }
}
```

> [!WARNING]
> **Avoid Parameter Conflicts (`BlobControllerConflictException`):**
> When an external `BlobController` is provided to `BlobFlutter`, passing any widget-level configuration properties (`particleCount`, `radius`, `pointSize`, `speed`, `noiseType`, `gradient`, etc.) alongside `controller` will throw a **`BlobControllerConflictException`**.
> Always configure those properties directly inside `BlobController(...)` — never define them on both.

---

## Procedural Noise Algorithms

Choose from 9 distinct mathematical displacement models using the `BlobNoiseType` enum:

| Algorithm | Visual Characteristics | Best For |
| :--- | :--- | :--- |
| `harmonic` | Smooth, organic, fluid liquid blob motion. | Liquid effects, calm assistants |
| `spiky` | Sharp peaks, crystalline spikes, urchin geometry. | Audio visualizers, energetic UI |
| `fractal` | Multi-octave turbulent cloud and terrain details. | Complex, textured surfaces |
| `cellular` | Segmented clusters, biological cells, bubbles. | Organic, microscopic visuals |
| `vortex` | Swirling cyclone, spiral galaxy, tornado. | Loading spinners, portals |
| `sphericalHarmonics`| Acoustic cymatics, nodal patterns, quantum fields. | High-tech, futuristic UI |
| `simplex` | Omni-directional, artifact-free smooth flow. | Clean, continuous deformation |
| `wave` | Flat full square carpet/net with undulating wave ripples. | Floating wave nets, square carpets, audio grids |
| `custom` | User-defined mathematical procedural noise algorithm. | Custom 3D shapes, stars, toruses, hearts, custom math |

---

## Custom Procedural Noise & 3D Math Engine

With `BlobNoiseType.custom`, you have complete creative freedom to sculpt custom 3D geometries, pulsating crystals, hollow toruses, swirling spirals, or bespoke mathematical motions.

### 1. Custom Noise Function Signature
A custom noise function evaluates per-particle displacement in 3D space:

```dart
typedef BlobCustomNoiseFunction = double Function(
  double px,        // Particle X on unit sphere (-1.0 to 1.0)
  double py,        // Particle Y on unit sphere (-1.0 to 1.0)
  double pz,        // Particle Z on unit sphere (-1.0 to 1.0)
  double frequency, // noiseFrequency parameter
  double time,      // Animation time in seconds
  double blobiness, // Global deformation multiplier
);
```

### 2. Built-in Math Helpers in `BlobMath`
`BlobMath` provides high-performance, allocation-free static utilities for sculpting 3D particles:

* **`BlobMath.azimuth(px, pz)`**: Azimuthal angle $\phi = \text{atan2}(pz, px) \in [-\pi, \pi]$ (ideal for longitude/spiral twisting).
* **`BlobMath.elevation(py)`**: Elevation angle $\theta = \text{asin}(py) \in [-\pi/2, \pi/2]$ with safe clamping against `NaN`.
* **`BlobMath.distance2D(x, z)`**: Planar radial distance $\sqrt{x^2 + z^2}$ from the Y-axis.
* **`BlobMath.fastSimplex3D(x, y, z)`**: High-speed Simplex 3D noise for organic, terrain-like surfaces.
* **`BlobMath.smoothstep(edge0, edge1, x)`**: Hermite interpolation for smooth borders and transitions.
* **`BlobMath.clampDisplacement(val)`**: Automatic safeguard against `NaN` or `Infinity`, clamping values safely to `[0.05, 5.0]`.

### 3. Usage Examples

#### Via `BlobController`:
```dart
final controller = BlobController(
  noiseType: BlobNoiseType.custom,
  customNoise: (px, py, pz, f, time, blobiness) {
    final double phi = BlobMath.azimuth(px, pz);
    return 1.0 + sin(phi * 4.0 + time) * 0.3 * blobiness;
  },
);

// Switch or update dynamically at runtime:
controller.setCustomNoise((px, py, pz, f, time, blobiness) {
  return 1.0 + BlobMath.fastSimplex3D(px * f, py * f, pz * f + time) * 0.35 * blobiness;
});
```

#### Via `BlobFlutter` Widget:
```dart
BlobFlutter(
  noiseType: BlobNoiseType.custom,
  customNoise: (px, py, pz, f, time, blobiness) {
    final double r = BlobMath.distance2D(px, pz);
    return 1.0 + cos(r * 8.0 * f - time * 3.0) * 0.25 * blobiness;
  },
)
```

### 4. Golden Rules for Glitch-Free Shapes
1. **The 1.0 Anchor:** Displacements scale the unit sphere. Always write equations relative to `1.0` (e.g. `1.0 + (wave * blobiness)`).
2. **Safe from NaN & Isolate Closures:** Custom noise closures run synchronously on the main thread (<0.5ms for 3,000 particles), allowing you to write any lambda or closure without Isolate serialization errors. All returns are automatically protected from `NaN` and `Infinity`.
3. **Zero Heap Allocations:** The function is invoked per-particle every frame. Keep all calculations on `double` primitives without instantiating objects or collections.

### 5. Practical Shape Recipes

```dart
// 1. Classic 5-Point 3D Star
controller.setCustomNoise((px, py, pz, f, time, blobiness) {
  final double angle = atan2(py, px) + time * 0.4;
  final double star2D = max(0.0, cos(5.0 * angle));
  final double sharpPoints = pow(star2D, 2.5).toDouble();
  final double zProfile = max(0.0, 1.0 - pz.abs() * 2.0);
  return (0.45 + sharpPoints * zProfile * 1.5) * blobiness;
});


// 2. Saturn Planet & Glowing Equatorial Ring
controller.setCustomNoise((px, py, pz, f, time, blobiness) {
  final double yDist = py.abs();
  final double ring = yDist < 0.15 ? pow(0.9 - yDist / 0.35, 5.0).toDouble() * 1.5 : 0.0;
  return (0.55 + ring) * blobiness;
});

```

---

## Customization Properties

### Widget Properties (`BlobFlutter`)
Configure the initial state of your blob directly in the widget.

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `particleCount` | `int` | `5000` | Total number of particles on the sphere (higher counts increase density but may affect performance). |
| `radius` | `double` | `150.0` | Base radius in logical pixels. |
| `pointSize` | `double` | `2.0` | Diameter of each rendered particle. |
| `rotationX` / `rotationY` | `double` | `0.0` | Initial base 3D orientation angles (pitch & yaw) in radians. |
| `noiseType` | `Enum` | `harmonic` | Procedural 3D noise algorithm used. |
| `customNoise` | `BlobCustomNoiseFunction?` | `null` | Custom procedural displacement function used when `noiseType` is `BlobNoiseType.custom`. |
| `controller` | `BlobController?` | `null` | External controller for runtime manipulation. |
| `gradient` | `Gradient` | `Linear` | Color gradient (Linear, Radial, or Sweep). |
| `autoPlay` | `bool` | `true` | Whether the animation loop starts automatically. Set to `false` for battery savings on static views or widget tests. |

> [!TIP]
> **Performance & Particle Count (`particleCount`):**
> Increasing the particle count enhances visual fullness and detail, but directly increases computation time in the isolate and vertex drawing load on the GPU:
> - **1,000 – 3,000:** Ideal for low-end devices, battery-sensitive apps, or subtle background elements.
> - **3,000 – 6,000 (Default: `5000`):** Sweet spot for smooth 60/120 FPS on most modern mobile devices.
> - **8,000 – 20,000+:** Recommended for modern flagship phones, desktop, or web applications with capable GPUs.
>
> *(Note: These figures are approximations and may vary depending on target device hardware and workload).*

### Controller Properties (`BlobController`)
Manipulate the blob dynamically at runtime using the controller methods.

| Setter Method | Valid Range | Description |
| :--- | :--- | :--- |
| `pause()` | - | Stops the animation ticker completely (0% CPU/battery usage). |
| `resume()` | - | Resumes the animation loop if paused. |
| `isPaused` | `true`/`false` | Getter checking whether the animation loop is currently paused. |
| `setParticleCount(val)`| `10` - `100000`| Dynamically sets particle count (reallocates buffers). |
| `setBlobiness(val)` | `0.0` - `5.0` | Amplitude of noise displacement. |
| `setSpeed(val)` | `0.0` - `10.0` | Playback speed of the animation. |
| `setRotationX(val)` / `setRotationY(val)` | `double` (radians) | Sets persistent 3D orientation pitch & yaw angles. |
| `setRotation({x, y})` | `double?` (radians) | Sets both 3D orientation angles simultaneously. |
| `setDispersion(val)` | `0.0` - `3.0` | Outward radial displacement. |
| `setNoiseFrequency(val)`| `0.1` - `5.0` | Density of the noise ripples. |
| `setNoiseType(type)` | `Enum` | Changes the deformation algorithm. |
| `setCustomNoise(fn, {switchToCustom})` | `Function?` | Sets custom procedural noise callback and optionally sets noiseType to `custom`. |
| `setIsRainbowMode(bool)`| `true`/`false` | Cycles colors through the HSV spectrum. |
| `zoomIn(val)` / `zoomOut` | - | Scales the blob size dynamically. |

*(Check the source code for a complete list of advanced physics and shader properties).*

---

## Architecture & Performance

`BlobFlutter` is built with deep respect for both developers and end-user hardware. Every mathematical model, buffer allocation, and render pass is calculated with exacting precision to deliver sustained **60 / 120 FPS** while safeguarding device resources, thermals, and battery life:

1. **Persistent Worker Isolate**: 3D math, trigonometric deformations, and matrix rotations execute in a dedicated background worker (`BlobWorker`). The UI receives data via zero-copy `TransferableTypedData`.
2. **Single GPU Draw Call**: Particle coordinates are flattened and drawn directly to graphics hardware using `Canvas.drawRawPoints`.
3. **Zero Heap Allocation**: Coordinate caches and calculation buffers are pre-allocated during initialization, avoiding Garbage Collector (GC) stutters.
4. **Hardware Shaders**: Complex color interpolation and organic shimmer waves run entirely on the GPU via custom GLSL shaders (`ui.FragmentProgram`).
5. **Resource-Conscious Loop**: Calculations and render cycles are strictly optimized so device CPU/GPU cycles are never wasted on redundant processing.
6. **Ultra-Fast Path for Automatic Frames**: During steady-state animations (when no pointers or radial dispersions are active), the math loop transitions into an unbranched, streamlined execution path. By bypassing over 18,000 conditional pointer and touch checks per frame, single-threaded environments like Flutter Web and mobile CPU architectures achieve peak JIT optimization, lower thermals, and a rock-solid, sustained 60/120 FPS.

> [!NOTE]
> **Performance Scaling:** Although computation is offloaded to a background `Isolate` to keep the UI thread jank-free, mathematical transformations and GPU vertex throughput scale linearly with `particleCount`. Very high counts on budget or older hardware may impact frame rates or cause battery drain.

---

## Error Handling

`BlobFlutter` provides actionable console diagnostics with automatic CPU fallback if shaders are unavailable.
Catch issues programmatically or render custom fallback interfaces via `onError` and `errorBuilder`.

---

<div align="center">
  <i>Built with ❤️ by dexter for fluid,interactive Flutter interfaces.</i>
</div>
