<div align="center">

# Blob Flutter (3D Particle Blob)

![Cyberpunk Blob Banner](https://github.com/abod8639/media/blob/main/blob_flutter/Picsart_2.png?raw=true)
<!-- ![Cyberpunk Blob Banner](assets/banner.jpg) -->

**A high-performance, interactive 3D particle blob for Flutter.**<br>
*Powered by procedural noise algorithms, multi-threaded Isolate computation, and GPU Fragment Shaders.*

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=&logo=Flutter&logoColor=white)]()
[![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=&logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Flutter%20%7C%20All%20Platforms-02569B?style=&logo=flutter)](https://pub.dev/packages/blob_flutter)


[![Pub Points](https://img.shields.io/pub/points/blob_flutter?style=&logo=dart&color=2E8B57)](https://pub.dev/packages/blob_flutter/score)
[![Pub Likes](https://img.shields.io/pub/likes/blob_flutter?style=&logo=flutter&color=blueviolet)](https://pub.dev/packages/blob_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg?style=&)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/abod8639/particle_blob_3d?style=&logo=github&color=gold)](https://github.com/abod8639/particle_blob_3d/stargazers)

[![Codecov](https://img.shields.io/codecov/c/github/abod8639/blob_flutter?style=&logo=codecov&logoColor=white)](https://codecov.io/gh/abod8639/blob_flutter)
[![Pub Version](https://img.shields.io/pub/v/blob_flutter?style=&logo=dart&color=blue)](https://pub.dev/packages/blob_flutter)

[Features](#-features) • [Quick Start](#-quick-start) • [Algorithms](#-procedural-noise-algorithms) • [Controller](#-controller-usage) • [Error Handling](#error-handling) • [Architecture](#-architecture--performance)

</div>

---

<p align="center">
  <img src="https://github.com/abod8639/media/blob/main/blob_flutter/Screenshot_1.png?raw=true" width="24%" alt="Screenshot 1" />
  <img src="https://github.com/abod8639/media/blob/main/blob_flutter/Screenshot_3.png?raw=true" width="24%" alt="Screenshot 3" />
  <img src="https://github.com/abod8639/media/blob/main/blob_flutter/Screenshot_5.png?raw=true" width="24%" alt="Screenshot 5" />
  <img src="https://github.com/abod8639/media/blob/main/blob_flutter/Screenshot_4.png?raw=true" width="24%" alt="Screenshot 4" />
</p>

## Features

- **Zero-Jank Architecture**: Offloads heavy 3D math and vertex projections to a persistent background `Isolate`.
- **GPU Fragment Shaders**: Hardware-accelerated per-pixel color gradients (Linear, Radial, Sweep) via custom GLSL.
- **7 Procedural Noise Models**: Smooth liquid waves, crystalline spikes, cellular bubbles, and more.
- **Fluid Touch Interaction**: Natural multi-touch drag rotation, hover tracking, and tap dispersion.
- **Zero-Allocation Pipeline**: Pre-allocated buffers ensure zero heap object allocations during the render loop.
- **Resource-Conscious Engineering**: Crafted with rigorous mathematical precision to respect developers and end-user devices—maximizing performance while preventing battery drain and memory thrashing.

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
        particleCount: 5000,
        radius: 150.0,
      ),
    );
  }
}
```

---

## Procedural Noise Algorithms

Choose from 7 distinct mathematical displacement models using the `BlobNoiseType` enum:

| Algorithm | Visual Characteristics | Best For |
| :--- | :--- | :--- |
| `harmonic` | Smooth, organic, fluid liquid blob motion. | Liquid effects, calm assistants |
| `spiky` | Sharp peaks, crystalline spikes, urchin geometry. | Audio visualizers, energetic UI |
| `fractal` | Multi-octave turbulent cloud and terrain details. | Complex, textured surfaces |
| `cellular` | Segmented clusters, biological cells, bubbles. | Organic, microscopic visuals |
| `vortex` | Swirling cyclone, spiral galaxy, tornado. | Loading spinners, portals |
| `sphericalHarmonics`| Acoustic cymatics, nodal patterns, quantum fields. | High-tech, futuristic UI |
| `simplex` | Omni-directional, artifact-free smooth flow. | Clean, continuous deformation |

---

## Customization Properties

### Widget Properties (`BlobFlutter`)
Configure the initial state of your blob directly in the widget.

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `particleCount` | `int` | `5000` | Total number of particles on the sphere (higher counts increase density but may affect performance). |
| `radius` | `double` | `150.0` | Base radius in logical pixels. |
| `pointSize` | `double` | `2.0` | Diameter of each rendered particle. |
| `noiseType` | `Enum` | `harmonic` | Procedural 3D noise algorithm used. |
| `controller` | `BlobController?` | `null` | External controller for runtime manipulation. |
| `gradient` | `Gradient` | `Linear` | Color gradient (Linear, Radial, or Sweep). |

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
| `setParticleCount(val)`| `10` - `100000`| Dynamically sets particle count (reallocates buffers). |
| `setBlobiness(val)` | `0.0` - `5.0` | Amplitude of noise displacement. |
| `setSpeed(val)` | `0.0` - `10.0` | Playback speed of the animation. |
| `setDispersion(val)` | `0.0` - `3.0` | Outward radial displacement. |
| `setNoiseFrequency(val)`| `0.1` - `5.0` | Density of the noise ripples. |
| `setNoiseType(type)` | `Enum` | Changes the deformation algorithm. |
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
