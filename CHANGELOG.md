## 1.1.0

- **True 3D Object-Space Shaders (`uColor3D`)**: Gradients rotate dynamically with the 3D geometry in world space instead of remaining flat in 2D screen space.
- **$O(N)$ Linear Depth Sorting & Depth-Cueing (`enableDepthSort`, `enableDepthCueing`)**: Zero-allocation 64-bin Bucket Sort in isolate ensures proper back-to-front rendering order (Painter's algorithm) with atmospheric depth scaling.
- **Responsive Auto-Fit (`autoFit`, `radiusFactor`)**: Automatically resizes the blob radius to dynamically fit parent container dimensions and screen orientation changes.
- **Flutter Web Optimization (`isComplex`, `webTemporalInterleaving`)**: Alternates calculation frames (striding) to slash per-frame CPU math on single-threaded JavaScript, with configurable particle limits (`maxWebParticles`).
- **Zero-Battery Multi-Tier Lifecycle (`autoPauseOffscreen`, `autoPauseOnAppBackground`, `autoPauseOnRouteChange`)**: Automatically halts tickers and isolate calculations (0% CPU/GPU) when offscreen, minimized, or when navigating to another route.

## 1.0.0

- Initial release of `blob_flutter`.
- High-performance interactive 3D particle blob powered by custom GPU fragment shaders (`blob.frag`).
- Multi-threaded background computation via dedicated worker `Isolate`.
- Procedural noise models (Smooth Waves, Spikes, Cellular, Wrinkles, Crystal, Swirl, Organic Pulse, Custom).
- Fluid multi-touch drag rotation, hover tracking, and tap dispersion physics.
- Zero-allocation render loop using pre-allocated buffers and `Canvas.drawRawPoints`.
- Robust error handling hierarchy (`BlobShaderException`, `BlobWorkerException`, `BlobParameterException`) with fallback UI (`errorBuilder`, `onError`).
