import 'package:blob_flutter/blob_flutter.dart';
import 'package:flutter/material.dart';

void main() => runApp(const BlobExampleApp());

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
//*   ___________________________________________
//*  /                                           \
//* |    ✨ THANK YOU FOR USING PARTICLES ✨      |
//* |                                             |
//* |   If this library helped you build          |
//* |   something amazing, please consider        |
//* |   giving it a star! It means a lot.         |
//* |                                             |
//* |        ⭐ [ star ]  particles_network       |
//*  \___________________________________________/
//*           !  !
//*           !  !
//*           L_ !

class BlobShowcasePage extends StatefulWidget {
  const BlobShowcasePage({super.key});

  @override
  State<BlobShowcasePage> createState() => _BlobShowcasePageState();
}

class _BlobShowcasePageState extends State<BlobShowcasePage> {
  late final BlobController _controller;

  static const List<List<Color>> _palettes = [
    [Color(0xFF00F5D4), Color(0xFF7B2CBF)], // Cyberpunk Cyan & Purple
    [Color(0xFFFF007F), Color(0xFFFFBE0B)], // Sunset Pink & Gold
    [Color(0xFF00B4D8), Color(0xFF06D6A0)], // Ocean Blue & Mint
    [Color(0xFFFF5400), Color(0xFFFF0054)], // Fire Orange & Red
    [Color(0xFFFFD700), Color(0xFF8B00FF)], // Gold & Purple
    [Color(0xFF4ECDC4), Color(0xFF1A535C)], // Mint & Dark Teal
    [Color(0xFF8B00FF), Color(0xFF4ECDC4)], // Purple & Mint
  ];

  int _selectedPalette = 0;
  bool _isRainbow = false;
  BlobNoiseType _selectedNoise = BlobNoiseType.harmonic;
  double _speed = 1.0;
  double _blobiness = 1.0;
  bool _showSliders = false;

  @override
  void initState() {
    super.initState();
    _controller = BlobController(
      speed: _speed,
      blobiness: _blobiness,
      noiseType: _selectedNoise,
      pinchToScale: false,
      hover: true,
      gradient: LinearGradient(
        colors: _palettes[_selectedPalette],
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

  void _selectPalette(int index) {
    setState(() {
      _selectedPalette = index;
      _isRainbow = false;
    });
    _controller.setIsRainbowMode(false);
    _controller.setGradient(
      LinearGradient(
        colors: _palettes[index],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  void _toggleRainbow() {
    final next = !_isRainbow;
    setState(() => _isRainbow = next);
    _controller.setIsRainbowMode(next);
  }

  void _selectNoise(BlobNoiseType type) {
    setState(() => _selectedNoise = type);
    _controller.setNoiseType(type);
  }

  void _updateSpeed(double value) {
    setState(() => _speed = value);
    _controller.setSpeed(value);
  }

  void _updateBlobiness(double value) {
    setState(() => _blobiness = value);
    _controller.setBlobiness(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── 3D Particle Blob Canvas ─────────────────────────────────────────
          Positioned.fill(
            child: BlobFlutter(
              controller: _controller,
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
                        letterSpacing: 1.2,
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

          // ── Bottom Controls Panel ────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: _buildControlsPanel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141923).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Noise Algorithm Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: BlobNoiseType.values.map((type) {
                final isSelected = type == _selectedNoise;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(type.name),
                    selected: isSelected,
                    onSelected: (_) => _selectNoise(type),
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
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // 2. Color Palettes, Rainbow Mode, and Tune Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            // mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(_palettes.length, (i) {
                final isSelected = !_isRainbow && _selectedPalette == i;
                return GestureDetector(
                  onTap: () => _selectPalette(i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: _palettes[i]),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: _toggleRainbow,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
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
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // const Spacer(),
              IconButton(
                icon: Icon(
                  _showSliders ? Icons.tune : Icons.tune_outlined,
                  color:
                      _showSliders ? const Color(0xFF00F5D4) : Colors.white60,
                  size: 20,
                ),
                onPressed: () => setState(() => _showSliders = !_showSliders),
                tooltip: 'Adjust parameters',
              ),
            ],
          ),

          // 3. Expandable Sliders (Speed & Noise)
          if (_showSliders) ...[
            const SizedBox(height: 8),
            _buildSlider(
              label: 'Speed',
              value: _speed,
              min: 0.0,
              max: 3.0,
              display: '${_speed.toStringAsFixed(1)}x',
              onChanged: _updateSpeed,
            ),
            _buildSlider(
              label: 'Noise',
              value: _blobiness,
              min: 0.0,
              max: 3.0,
              display: '${_blobiness.toStringAsFixed(1)}x',
              onChanged: _updateBlobiness,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 50,
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
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            display,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
        ),
      ],
    );
  }
}
