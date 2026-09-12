import 'package:flutter/material.dart';
import 'package:blob_flutter/blob_flutter.dart';

void main() {
  runApp(const BlobExampleApp());
}

class BlobExampleApp extends StatelessWidget {
  const BlobExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blob Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
      ),
      home: const BlobShowcasePage(),
    );
  }
}

class BlobShowcasePage extends StatefulWidget {
  const BlobShowcasePage({super.key});

  @override
  State<BlobShowcasePage> createState() => _BlobShowcasePageState();
}

class _BlobShowcasePageState extends State<BlobShowcasePage> {
  late final BlobController _controller;

  // Track active selections for UI state
  BlobNoiseType _selectedNoise = BlobNoiseType.harmonic;
  int _selectedGradientIndex = 0;
  bool _isRainbow = false;
  double _speed = 1.0;
  double _blobiness = 1.0;
  double _tiltAngle = 0.0;
  int _particleCount = 4500;

  static const List<List<Color>> _gradientPresets = [
    [Color(0xFF00F5D4), Color(0xFF7B2CBF)], // Cyberpunk Cyan & Purple
    [Color(0xFFFF007F), Color(0xFFFFBE0B)], // Sunset Pink & Gold
    [Color(0xFF00B4D8), Color(0xFF06D6A0)], // Ocean Blue & Mint
    [Color(0xFFFF5400), Color(0xFFFF0054)], // Fire Orange & Red
  ];

  @override
  void initState() {
    super.initState();
    _controller = BlobController(
      particleCount: _particleCount,
      radius: 150.0,
      pointSize: 1.5,
      tapScaleFactor: 0.5,
      touchRadiusFactor: 0.6,
      speed: _speed,
      blobiness: _blobiness,
      noiseType: _selectedNoise,
      enableDragRotation: true,
      enablePinchToScale: true,
      rotationY: .5,
      // rotationX: 10,
      rotationX: _tiltAngle,


      gradient: LinearGradient(
        colors: _gradientPresets.first,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onNoiseTypeChanged(BlobNoiseType type) {
    setState(() => _selectedNoise = type);
    _controller.setNoiseType(type);
  }

  void _onGradientPresetSelected(int index) {
    setState(() {
      _selectedGradientIndex = index;
      _isRainbow = false;
    });
    _controller.setIsRainbowMode(false);
    _controller.setGradient(
      LinearGradient(
        colors: _gradientPresets[index],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  void _toggleRainbowMode() {
    final nextRainbow = !_isRainbow;
    setState(() => _isRainbow = nextRainbow);
    _controller.setIsRainbowMode(nextRainbow);
  }

  void _onSpeedChanged(double value) {
    setState(() => _speed = value);
    _controller.setSpeed(value);
  }

  void _onNoiseIntensityChanged(double value) {
    setState(() => _blobiness = value);
    _controller.setBlobiness(value);
  }

  void _onTiltAngleChanged(double value) {
    setState(() => _tiltAngle = value);
    _controller.setRotationX(value);
  }

  void _onParticleCountChanged(double value) {
    final count = value.round();
    setState(() => _particleCount = count);
    _controller.setParticleCount(count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── 3D Particle Blob Canvas ─────────────────────────────────────────
          Positioned.fill(
            child: Column(
              children: [
                const SizedBox(height: 200),
                BlobFlutter(
                  controller: _controller,
                  enableDragRotation: true,
                  enableHover: true,
                ),
              ],
            ),
          ),

          // ── Top Header ───────────────────────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Blob Flutter 3D',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drag to rotate • Tap to disperse particles',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom Control Panel ────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildControlsPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141923).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Noise Algorithm Selector
          const Text(
            'Noise Algorithm',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: BlobNoiseType.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final type = BlobNoiseType.values[index];
                final isSelected = type == _selectedNoise;
                return ChoiceChip(
                  label: Text(type.name),
                  selected: isSelected,
                  onSelected: (_) => _onNoiseTypeChanged(type),
                  selectedColor: const Color(0xFF00F5D4),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.black : Colors.white70,
                  ),
                  backgroundColor: const Color(0xFF1F2633),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF00F5D4)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // 2. Color Palettes & Rainbow Toggle
          Row(
            children: [
              const Text(
                'Color Palette',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              // Preset Color Circles
              ...List.generate(_gradientPresets.length, (i) {
                final isSelected = !_isRainbow && _selectedGradientIndex == i;
                final colors = _gradientPresets[i];
                return GestureDetector(
                  onTap: () => _onGradientPresetSelected(i),
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: colors),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              // Rainbow Mode Action Chip
              InkWell(
                onTap: _toggleRainbowMode,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _isRainbow
                        ? Colors.purpleAccent
                        : const Color(0xFF1F2633),
                    border: Border.all(
                      color: _isRainbow ? Colors.white : Colors.white24,
                    ),
                  ),
                  child: const Text(
                    'Rainbow',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3. Sliders: Speed, Noise (Deformation), Particles
          _buildSliderRow(
            label: 'Speed',
            value: _speed,
            min: 0.0,
            max: 3.0,
            divisions: 30,
            displayValue: '${_speed.toStringAsFixed(1)}x',
            onChanged: _onSpeedChanged,
          ),
          const SizedBox(height: 6),
          _buildSliderRow(
            label: 'Noise',
            value: _blobiness,
            min: 0.0,
            max: 3.0,
            divisions: 30,
            displayValue: '${_blobiness.toStringAsFixed(1)}x',
            onChanged: _onNoiseIntensityChanged,
          ),
          const SizedBox(height: 6),
          _buildSliderRow(
            label: 'Tilt',
            value: _tiltAngle,
            min: -1.57,
            max: 1.57,
            divisions: 30,
            displayValue: '${(_tiltAngle * 180 / 3.14159).round()}°',
            onChanged: _onTiltAngleChanged,
          ),
          const SizedBox(height: 6),
          _buildSliderRow(
            label: 'Particles',
            value: _particleCount.toDouble(),
            min: 1000.0,
            max: 10000.0,
            divisions: 18,
            displayValue: '$_particleCount',
            onChanged: _onParticleCountChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 65,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00F5D4),
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFF00F5D4),
              overlayColor: const Color(0x2900F5D4),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            displayValue,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ),
      ],
    );
  }
}
