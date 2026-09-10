## 1.0.0

- Initial release of `blob_flutter`.
- High-performance interactive 3D particle blob powered by custom GPU fragment shaders (`blob.frag`).
- Multi-threaded background computation via dedicated worker `Isolate`.
- 7 procedural noise models (Smooth Waves, Spikes, Cellular, Wrinkles, Crystal, Swirl, Organic Pulse).
- Fluid multi-touch drag rotation, hover tracking, and tap dispersion physics.
- Zero-allocation render loop using pre-allocated buffers and `Canvas.drawRawPoints`.
- Robust error handling hierarchy (`BlobShaderException`, `BlobWorkerException`, `BlobParameterException`) with fallback UI (`errorBuilder`, `onError`).
