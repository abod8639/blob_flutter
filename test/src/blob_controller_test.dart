import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blob_flutter/src/blob_controller.dart';
import 'package:blob_flutter/src/blob_noise_type.dart';

void main() {
  group('BlobController Tests', () {
    test('initial values and custom constructor parameters', () {
      final controller = BlobController(
        radius: 180.0,
        pointSize: 3.5,
        particleCount: 3000,
        scale: 1.2,
        minScale: 0.2,
        maxScale: 4.0,
        centerOffset: const Offset(10, -20),
        alignment: Alignment.topRight,
        dampingFactor: 0.9,
        tapScaleFactor: 2.0,
        touchRadiusFactor: 1.5,
        speed: 2.5,
        autoRotationSpeed: 1.2,
        blobiness: 1.5,
        dispersion: 0.3,
        noiseFrequency: 1.8,
        viewDistance: 2.5,
        hover: true,
        isColorAnimated: false,
        colorAnimationSpeed: 2.5,
        waveIntensity: 0.5,
        pinchToScale: true,
        dragRotation: true,
        hoverRotation: true,
        noiseType: BlobNoiseType.vortex,
        gradient: const RadialGradient(colors: [Colors.red, Colors.blue]),
      );

      expect(controller.radius, 180.0);
      expect(controller.pointSize, 3.5);
      expect(controller.particleCount, 3000);
      expect(controller.scale, 1.2);
      expect(controller.minScale, 0.2);
      expect(controller.maxScale, 4.0);
      expect(controller.centerOffset, const Offset(10, -20));
      expect(controller.alignment, Alignment.topRight);
      expect(controller.effectiveRadius, 180.0 * 1.2);
      expect(controller.dampingFactor, 0.9);
      expect(controller.tapScaleFactor, 2.0);
      expect(controller.touchRadiusFactor, 1.5);
      expect(controller.blobiness, 1.5);
      expect(controller.speed, 2.5);
      expect(controller.dispersion, 0.3);
      expect(controller.autoRotationSpeed, 1.2);
      expect(controller.noiseFrequency, 1.8);
      expect(controller.viewDistance, 2.5);
      expect(controller.hover, true);
      expect(controller.isColorAnimated, false);
      expect(controller.colorAnimationSpeed, 2.5);
      expect(controller.waveIntensity, 0.5);
      expect(controller.pinchToScale, true);
      expect(controller.dragRotation, true);
      expect(controller.hoverRotation, true);
      expect(controller.noiseType, BlobNoiseType.vortex);
      expect(controller.gradient, isA<RadialGradient>());
    });

    test('constructor asserts on invalid parameters', () {
      expect(() => BlobController(radius: 0.0), throwsAssertionError);
      expect(() => BlobController(pointSize: 0.0), throwsAssertionError);
      expect(() => BlobController(particleCount: 0), throwsAssertionError);
      expect(() => BlobController(speed: -0.1), throwsAssertionError);
      expect(() => BlobController(scale: 0.0), throwsAssertionError);
      expect(() => BlobController(minScale: 5.0, maxScale: 2.0),
          throwsAssertionError);
      expect(() => BlobController(dampingFactor: -0.1), throwsAssertionError);
      expect(() => BlobController(dampingFactor: 1.1), throwsAssertionError);
      expect(() => BlobController(tapScaleFactor: -0.5), throwsAssertionError);
      expect(
          () => BlobController(touchRadiusFactor: -0.5), throwsAssertionError);
      expect(() => BlobController(blobiness: -0.1), throwsAssertionError);
      expect(() => BlobController(dispersion: -0.1), throwsAssertionError);
      expect(() => BlobController(noiseFrequency: -0.1), throwsAssertionError);
      expect(() => BlobController(viewDistance: 0.0), throwsAssertionError);
      expect(() => BlobController(colorAnimationSpeed: -0.1),
          throwsAssertionError);
      expect(() => BlobController(waveIntensity: -0.1), throwsAssertionError);
    });

    test('property setters clamp inputs correctly', () {
      final controller = BlobController();

      controller.setRadius(6000.0); // clamped to 5000.0
      expect(controller.radius, 5000.0);
      controller.setRadius(0.5); // clamped to 1.0
      expect(controller.radius, 1.0);

      controller.setPointSize(120.0); // clamped to 100.0
      expect(controller.pointSize, 100.0);
      controller.setPointSize(0.05); // clamped to 0.1
      expect(controller.pointSize, 0.1);

      controller.setParticleCount(200000); // clamped to 100000
      expect(controller.particleCount, 100000);
      controller.setParticleCount(5); // clamped to 10
      expect(controller.particleCount, 10);

      controller.setScale(15.0); // clamped to maxScale 10.0
      expect(controller.scale, 10.0);
      controller.setScale(0.01); // clamped to minScale 0.1
      expect(controller.scale, 0.1);

      controller.setScaleLimits(minScale: 0.5, maxScale: 3.0);
      expect(controller.minScale, 0.5);
      expect(controller.maxScale, 3.0);
      expect(controller.scale, 0.5); // auto-clamped to new minScale

      controller.setColorAnimationSpeed(15.0); // clamped to 10.0
      expect(controller.colorAnimationSpeed, 10.0);
      controller.setColorAnimationSpeed(-2.0); // clamped to 0.0
      expect(controller.colorAnimationSpeed, 0.0);

      controller.setWaveIntensity(8.0); // clamped to 5.0
      expect(controller.waveIntensity, 5.0);
      controller.setWaveIntensity(-1.0); // clamped to 0.0
      expect(controller.waveIntensity, 0.0);

      controller.setIsRainbowMode(true);
      expect(controller.isRainbowMode, true);

      controller.setIsColorAnimated(false);
      expect(controller.isColorAnimated, false);

      const grad = SweepGradient(colors: [Colors.green, Colors.yellow]);
      controller.setGradient(grad);
      expect(controller.gradient, grad);

      controller.setBlobiness(6.0); // clamped to 5.0
      expect(controller.blobiness, 5.0);
      controller.setBlobiness(-1.0); // clamped to 0.0
      expect(controller.blobiness, 0.0);

      controller.setSpeed(12.0); // clamped to 10.0
      expect(controller.speed, 10.0);
      controller.setSpeed(-2.0); // clamped to 0.0
      expect(controller.speed, 0.0);

      controller.setDispersion(4.0); // clamped to 3.0
      expect(controller.dispersion, 3.0);
      controller.setDispersion(-0.5); // clamped to 0.0
      expect(controller.dispersion, 0.0);

      controller.setDampingFactor(1.5); // clamped to 1.0
      expect(controller.dampingFactor, 1.0);
      controller.setDampingFactor(-0.2); // clamped to 0.0
      expect(controller.dampingFactor, 0.0);

      controller.setTapScaleFactor(6.0);
      expect(controller.tapScaleFactor, 6.0);
      controller.setTapScaleFactor(-1.0); // clamped to 0.0
      expect(controller.tapScaleFactor, 0.0);

      controller.setTouchRadiusFactor(15.0); // clamped to 10.0
      expect(controller.touchRadiusFactor, 10.0);
      controller.setTouchRadiusFactor(0.01); // clamped to 0.1
      expect(controller.touchRadiusFactor, 0.1);

      controller.setAutoRotationSpeed(4.0); // clamped to 3.0
      expect(controller.autoRotationSpeed, 3.0);
      controller.setAutoRotationSpeed(-4.0); // clamped to -3.0
      expect(controller.autoRotationSpeed, -3.0);

      controller.setNoiseFrequency(6.0); // clamped to 5.0
      expect(controller.noiseFrequency, 5.0);
      controller.setNoiseFrequency(0.05); // clamped to 0.1
      expect(controller.noiseFrequency, 0.1);

      controller.setViewDistance(6.0); // clamped to 5.0
      expect(controller.viewDistance, 5.0);
      controller.setViewDistance(0.5); // clamped to 0.8
      expect(controller.viewDistance, 0.8);

      controller.setHover(true);
      expect(controller.hover, true);
      controller.setIsHoverEnabled(false);
      expect(controller.hover, false);

      controller.setDragRotation(true);
      expect(controller.dragRotation, true);

      controller.setHoverRotation(true);
      expect(controller.hoverRotation, true);

      controller.setNoiseType(BlobNoiseType.cellular);
      expect(controller.noiseType, BlobNoiseType.cellular);
    });

    test(
        'geometry helper methods zoomIn, zoomOut, applyScaleFactor, and resets',
        () {
      final controller = BlobController(radius: 150.0, scale: 1.0);

      controller.zoomIn(0.2);
      expect(controller.scale, closeTo(1.2, 0.0001));

      controller.zoomOut(0.4);
      expect(controller.scale, closeTo(0.8, 0.0001));

      controller.applyScaleFactor(2.0);
      expect(controller.scale, closeTo(1.6, 0.0001));

      controller.resetScale();
      expect(controller.scale, 1.0);

      controller.setCenterOffset(const Offset(40, -50));
      expect(controller.centerOffset, const Offset(40, -50));

      controller.resetCenterOffset();
      expect(controller.centerOffset, Offset.zero);

      controller.setAlignment(Alignment.bottomLeft);
      expect(controller.alignment, Alignment.bottomLeft);

      controller.setPinchToScale(false);
      expect(controller.pinchToScale, false);

      controller.setScale(2.0);
      controller.setCenterOffset(const Offset(30, 30));
      controller.addRotationImpulse(const Offset(10, 10));
      controller.resetGeometry();
      expect(controller.scale, 1.0);
      expect(controller.centerOffset, Offset.zero);
      expect(controller.rotationX, 0.0);
      expect(controller.rotationY, 0.0);

      controller.setScale(1.8);
      controller.setCenterOffset(const Offset(40, -25));
      controller.addRotationImpulse(const Offset(15, 20));
      controller.setDispersion(1.5);
      controller.resetAll();
      expect(controller.scale, 1.0);
      expect(controller.centerOffset, Offset.zero);
      expect(controller.rotationX, 0.0);
      expect(controller.rotationY, 0.0);
      expect(controller.dispersion, 0.0);

      // Test resetAll when only rotationY is non-zero
      controller.addRotationImpulse(const Offset(10, 0));
      controller.resetAll();
      expect(controller.rotationX, 0.0);
      expect(controller.rotationY, 0.0);

      // Call resetAll again when already at default values (tests false branches)
      controller.resetAll();
      expect(controller.scale, 1.0);
    });

    test(
        'notifies listeners when properties are updated and avoids notifying on duplicate values',
        () {
      final controller = BlobController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setRadius(200.0);
      expect(notifyCount, 1);
      controller.setRadius(200.0); // duplicate
      expect(notifyCount, 1);

      controller.setPointSize(3.0);
      expect(notifyCount, 2);

      controller.setParticleCount(6000);
      expect(notifyCount, 3);

      controller.setScale(1.5);
      expect(notifyCount, 4);

      controller.setCenterOffset(const Offset(10, 10));
      expect(notifyCount, 5);

      controller.setAlignment(Alignment.topCenter);
      expect(notifyCount, 6);

      controller.setPinchToScale(false);
      expect(notifyCount, 7);

      controller.setBlobiness(2.0);
      expect(notifyCount, 8);

      controller.setSpeed(2.0);
      expect(notifyCount, 9);

      controller.setDispersion(1.0);
      expect(notifyCount, 10);
    });

    test('addRotationImpulse, applyDamping, and snapping rotation logic', () {
      final controller = BlobController(dampingFactor: 0.9);
      expect(controller.rotationX, 0.0);
      expect(controller.rotationY, 0.0);

      expect(controller.applyDamping(), false);

      controller.addRotationImpulse(const Offset(10.0, 20.0));
      expect(controller.rotationX, 20.0 * 0.005);
      expect(controller.rotationY, 10.0 * 0.005);

      expect(controller.applyDamping(), true);
      expect(controller.rotationX, closeTo((20.0 * 0.005) * 0.9, 0.0001));

      // Reset rotation before tiny impulse test
      controller.resetRotation();
      controller.addRotationImpulse(const Offset(0.01, 0.01));
      controller.setDampingFactor(0.1);
      controller.applyDamping();
      expect(controller.rotationX, 0.0);
      expect(controller.rotationY, 0.0);

      final controllerNoDecay = BlobController(dampingFactor: 1.0);
      controllerNoDecay.addRotationImpulse(const Offset(10.0, 20.0));
      controllerNoDecay.applyDamping();
      expect(controllerNoDecay.rotationX, 20.0 * 0.005);
      expect(controllerNoDecay.rotationY, 10.0 * 0.005);

      final controllerInstantDecay = BlobController(dampingFactor: 0.0);
      controllerInstantDecay.addRotationImpulse(const Offset(10.0, 20.0));
      controllerInstantDecay.applyDamping();
      expect(controllerInstantDecay.rotationX, 0.0);
      expect(controllerInstantDecay.rotationY, 0.0);
    });

    test(
        'controls orientation angle with setRotationX, setRotationY, and setRotation',
        () {
      final controller = BlobController(rotationX: 0.5, rotationY: -0.3);
      expect(controller.rotationX, 0.5);
      expect(controller.rotationY, -0.3);
      expect(controller.baseRotationX, 0.5);
      expect(controller.baseRotationY, -0.3);

      controller.setRotationX(0.8);
      expect(controller.rotationX, 0.8);
      expect(controller.baseRotationX, 0.8);

      controller.setRotationY(-1.2);
      expect(controller.rotationY, -1.2);
      expect(controller.baseRotationY, -1.2);

      controller.setRotation(x: 0.0, y: 0.0);
      expect(controller.rotationX, 0.0);
      expect(controller.rotationY, 0.0);

      // Verify that applyDamping does not erase base orientation
      controller.setRotationX(1.0);
      controller.addRotationImpulse(const Offset(10.0, 20.0));
      expect(controller.rotationX, 1.0 + 20.0 * 0.005);
      controller.applyDamping();
      expect(
          controller.rotationX, closeTo(1.0 + (20.0 * 0.005) * 0.92, 0.0001));

      // After reset, returns to zero
      controller.resetRotation();
      expect(controller.rotationX, 0.0);
      expect(controller.rotationY, 0.0);
    });

    test('controls playback state with pause, resume, and setIsPaused', () {
      final controller = BlobController();
      expect(controller.isPaused, false);

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.pause();
      expect(controller.isPaused, true);
      expect(notifyCount, 1);

      // Duplicate pause should not trigger listener
      controller.pause();
      expect(notifyCount, 1);

      controller.resume();
      expect(controller.isPaused, false);
      expect(notifyCount, 2);

      // Duplicate resume should not trigger listener
      controller.resume();
      expect(notifyCount, 2);

      controller.setIsPaused(true);
      expect(controller.isPaused, true);
      expect(notifyCount, 3);

      controller.setIsPaused(false);
      expect(controller.isPaused, false);
      expect(notifyCount, 4);

      final pausedController = BlobController(isPaused: true);
      expect(pausedController.isPaused, true);
    });

    test('setScaleLimits handles partial limits, clamping, and notifyListeners', () {
      final controller = BlobController(minScale: 0.5, maxScale: 3.0, scale: 2.0);
      int notificationCount = 0;
      controller.addListener(() => notificationCount++);

      // 1. Only minScale (maxScale is null -> hits line 421 `maxScale ?? _maxScale`)
      controller.setScaleLimits(minScale: 1.0);
      expect(controller.minScale, 1.0);
      expect(controller.maxScale, 3.0);
      expect(notificationCount, 1);

      // 2. Only maxScale (minScale is null -> hits line 420 `minScale ?? _minScale`)
      controller.setScaleLimits(maxScale: 2.5);
      expect(controller.minScale, 1.0);
      expect(controller.maxScale, 2.5);
      expect(notificationCount, 2);

      // 3. Clamping current scale when scale > new maxScale
      controller.setScale(2.5);
      notificationCount = 0;
      controller.setScaleLimits(maxScale: 1.8);
      expect(controller.maxScale, 1.8);
      expect(controller.scale, 1.8); // auto clamped
      expect(notificationCount, 1);

      // 4. Clamping current scale when scale < new minScale
      controller.setScaleLimits(minScale: 2.0, maxScale: 4.0);
      expect(controller.minScale, 2.0);
      expect(controller.scale, 2.0); // auto clamped

      // 5. Calling with identical limits (changed == false, no notifyListeners)
      notificationCount = 0;
      controller.setScaleLimits(minScale: 2.0, maxScale: 4.0);
      expect(notificationCount, 0);

      // 6. Debug asserts for invalid inputs
      expect(() => controller.setScaleLimits(minScale: -0.5), throwsAssertionError);
      expect(() => controller.setScaleLimits(minScale: 5.0, maxScale: 2.0), throwsAssertionError);

      controller.dispose();
    });

    test('setScaleLimits reports FlutterError when asserts are disabled for invalid inputs', () {
      final controller = BlobController(minScale: 0.5, maxScale: 3.0);
      FlutterErrorDetails? reportedDetails;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        reportedDetails = details;
      };

      try {
        BlobController.debugEnableAssertsInSetScaleLimits = false;

        // Test effectiveMin <= 0.0
        controller.setScaleLimits(minScale: -1.0);
        expect(reportedDetails, isNotNull);
        expect(reportedDetails!.exception, isA<ArgumentError>());
        expect(reportedDetails!.context.toString(), contains('setScaleLimits'));

        reportedDetails = null;

        // Test effectiveMin > effectiveMax
        controller.setScaleLimits(minScale: 5.0, maxScale: 2.0);
        expect(reportedDetails, isNotNull);
        expect(reportedDetails!.exception, isA<ArgumentError>());
      } finally {
        BlobController.debugEnableAssertsInSetScaleLimits = true;
        FlutterError.onError = oldHandler;
        controller.dispose();
      }
    });

    test('applyScaleFactor handles factor <= 0 and factor > 0', () {
      final controller = BlobController(scale: 2.0, minScale: 0.1, maxScale: 5.0);

      // Factor <= 0 returns early without changing scale
      controller.applyScaleFactor(0.0);
      expect(controller.scale, 2.0);
      controller.applyScaleFactor(-1.0);
      expect(controller.scale, 2.0);

      // Factor > 0 multiplies scale
      controller.applyScaleFactor(1.5);
      expect(controller.scale, 3.0);

      controller.dispose();
    });
  });
}
