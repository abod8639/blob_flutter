import 'dart:math';
import 'package:flutter/material.dart';
import 'package:blob_flutter/blob_flutter.dart';

void main() {
  runApp(const ParticleBlobExampleApp());
}

class ParticleBlobExampleApp extends StatelessWidget {
  const ParticleBlobExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sci-Fi AI Core',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late BlobController _blobController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // State variables
  final int _particleCount = 8000;
  final double _baseRadius = 150.0;
  final double _pointSize = 2.0;
  double _blobiness = 1.0;
  double _speed = 1.0;
  double _dampingFactor = 0.95;
  double _autoRotationSpeed = 0.5;
  double _noiseFrequency = 1.0;
  double _viewDistance = 2.0;
  BlobNoiseType _noiseType = BlobNoiseType.harmonic;

  // Color & Gradient state
  Color _color1 = Colors.cyanAccent;
  Color _color2 = Colors.blueAccent;
  Color _color3 = Colors.purpleAccent;
  bool _useThreeColors = false;
  bool _isColorAnimated = true;
  double _colorAnimationSpeed = 1.0;
  double _waveIntensity = 1.0;
  int _alignmentIndex = 0; // 0: Top-Bottom, 1: Left-Right, 2: Diagonal, 3: Radial, 4: Sweep

  // Physics / Interaction state
  bool _enableHover = true;

  // UI state
  bool _isListening = false;
  bool _isAudioPulseMode = false;
  bool _isRainbowMode = false;
  int _selectedTab = 0;

  final List<Color> _colorPalette = [
    Colors.pinkAccent,
    Colors.purpleAccent,
    Colors.cyanAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.redAccent,
    Colors.amberAccent,
    Colors.tealAccent,
    Colors.white,
  ];

  final List<_ThemePreset> _themes = [
    const _ThemePreset('CYBERPUNK', Colors.blueAccent, Colors.purpleAccent, Colors.pinkAccent),
    const _ThemePreset('NEON MATRIX', Colors.greenAccent, Colors.teal, Colors.cyanAccent),
    const _ThemePreset('SOLAR FLARE', Colors.orangeAccent, Colors.redAccent, Colors.amberAccent),
    const _ThemePreset('DEEP SPACE', Colors.cyanAccent, Colors.indigoAccent, Colors.blueAccent),
    const _ThemePreset('PLASMA CORE', Colors.purpleAccent, Colors.pinkAccent, Colors.deepOrangeAccent),
    const _ThemePreset('AURORA', Colors.tealAccent, Colors.indigoAccent, Colors.purpleAccent),
  ];

  @override
  void initState() {
    super.initState();
    _blobController = BlobController(
      dampingFactor: _dampingFactor,
      isColorAnimated: _isColorAnimated,
      colorAnimationSpeed: _colorAnimationSpeed,
      waveIntensity: _waveIntensity,
      enableHover: _enableHover,
    );
    _blobController.setAutoRotationSpeed(_autoRotationSpeed);
    _blobController.setNoiseFrequency(_noiseFrequency);
    _blobController.setViewDistance(_viewDistance);

    // Setup pulse animation for "Audio" mode
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    )..addListener(() {
        if (_isAudioPulseMode) {
          _blobController.setDispersion(_pulseAnimation.value);
        }
      });
  }

  @override
  void dispose() {
    _blobController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Gradient _buildCurrentGradient() {
    final colors = _useThreeColors ? [_color1, _color2, _color3] : [_color1, _color2];

    switch (_alignmentIndex) {
      case 0: // Top to Bottom
        return LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 1: // Left to Right
        return LinearGradient(
          colors: colors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case 2: // Diagonal
        return LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 3: // Radial
        return RadialGradient(
          colors: colors,
          center: Alignment.center,
          radius: 0.85,
        );
      case 4: // Sweep
        return SweepGradient(
          colors: colors,
          center: Alignment.center,
        );
      default:
        return LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
    }
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _isAudioPulseMode = false;
        _pulseController.stop();
        _blobController.setDispersion(0.0);

        _blobController.setBlobiness(2.5);
        _blobController.setSpeed(3.0);
        _blobiness = 2.5;
        _speed = 3.0;
        _color1 = Colors.redAccent;
        _color2 = Colors.orangeAccent;
      } else {
        _blobController.setBlobiness(1.0);
        _blobController.setSpeed(1.0);
        _blobiness = 1.0;
        _speed = 1.0;
        _color1 = Colors.cyanAccent;
        _color2 = Colors.blueAccent;
      }
    });
  }

  void _togglePulseMode() {
    setState(() {
      _isAudioPulseMode = !_isAudioPulseMode;
      if (_isAudioPulseMode) {
        _isListening = false;
        _blobController.setBlobiness(1.5);
        _blobController.setSpeed(1.5);
        _blobiness = 1.5;
        _speed = 1.5;
        _color1 = Colors.purpleAccent;
        _color2 = Colors.pinkAccent;
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _blobController.setDispersion(0.0);
        _blobController.setBlobiness(1.0);
        _blobController.setSpeed(1.0);
        _blobiness = 1.0;
        _speed = 1.0;
        _color1 = Colors.cyanAccent;
        _color2 = Colors.blueAccent;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: BlobFlutter(
                  tapScaleFactor: 1.1,
                  gradient: _buildCurrentGradient(),
                  particleCount: _particleCount,
                  radius: _baseRadius,
                  pointSize: _pointSize,
                  isColorAnimated: _isColorAnimated,
                  colorAnimationSpeed: _colorAnimationSpeed,
                  waveIntensity: _waveIntensity,
                  enableHover: _enableHover,
                  noiseType: _noiseType,
                  controller: _blobController,
                ),
              ),
            ),
            _buildControlsPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildNoiseChip(String label, BlobNoiseType type) {
    final bool isSelected = _noiseType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _noiseType = type;
          _blobController.setNoiseType(type);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.cyanAccent : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildControlsPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabBar(),
          const Divider(color: Colors.white12, height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTabButton(0, 'GEOMETRY', Icons.filter_tilt_shift),
          _buildTabButton(1, 'PHYSICS', Icons.bolt),
          _buildTabButton(2, 'COLOR & GRADIENT', Icons.palette),
          _buildTabButton(3, 'SYSTEM MODES', Icons.settings_input_component),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.cyanAccent : Colors.white54,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.cyanAccent : Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Noise Algorithm Selector
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'NOISE ALGORITHM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '3D Procedural Morph',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildNoiseChip('Harmonic', BlobNoiseType.harmonic),
                      _buildNoiseChip('Spiky', BlobNoiseType.spiky),
                      _buildNoiseChip('Fractal (fBm)', BlobNoiseType.fractal),
                      _buildNoiseChip('Cellular', BlobNoiseType.cellular),
                      _buildNoiseChip('Vortex', BlobNoiseType.vortex),
                      _buildNoiseChip('Cymatics', BlobNoiseType.sphericalHarmonics),
                      _buildNoiseChip('Simplex 3D', BlobNoiseType.simplex),
                    ],
                  ),
                ],
              ),
            ),
            _buildSlider(
              label: 'Blobiness (Deform Amplitude)',
              value: _blobiness,
              min: 0.0,
              max: 5.0,
              onChanged: (val) {
                setState(() {
                  _blobiness = val;
                  _blobController.setBlobiness(val);
                });
              },
            ),
            _buildSlider(
              label: 'Noise Density / Frequency',
              value: _noiseFrequency,
              min: 0.1,
              max: 3.0,
              onChanged: (val) {
                setState(() {
                  _noiseFrequency = val;
                  _blobController.setNoiseFrequency(val);
                });
              },
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MOUSE HOVER INTERACTION',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Interact on hover without clicking',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _enableHover,
                    activeThumbColor: Colors.cyanAccent,
                    activeTrackColor: Colors.cyanAccent.withValues(alpha: 0.3),
                    onChanged: (val) {
                      setState(() {
                        _enableHover = val;
                        _blobController.setEnableHover(val);
                      });
                    },
                  ),
                ],
              ),
            ),
            _buildSlider(
              label: 'Animation Speed',
              value: _speed,
              min: 0.0,
              max: 5.0,
              onChanged: (val) {
                setState(() {
                  _speed = val;
                  _blobController.setSpeed(val);
                });
              },
            ),
            _buildSlider(
              label: 'Background Auto-Rotation',
              value: _autoRotationSpeed,
              min: -3.0,
              max: 3.0,
              onChanged: (val) {
                setState(() {
                  _autoRotationSpeed = val;
                  _blobController.setAutoRotationSpeed(val);
                });
              },
            ),
            _buildSlider(
              label: 'Inertia / Damping Factor',
              value: _dampingFactor,
              min: 0.80,
              max: 1.00,
              onChanged: (val) {
                setState(() {
                  _dampingFactor = val;
                  _blobController.setDampingFactor(val);
                });
              },
            ),
            _buildSlider(
              label: 'Camera Perspective Distance',
              value: _viewDistance,
              min: 0.8,
              max: 5.0,
              onChanged: (val) {
                setState(() {
                  _viewDistance = val;
                  _blobController.setViewDistance(val);
                });
              },
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Static vs Moving Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'COLOR MOTION',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isColorAnimated ? 'Moving Wave' : 'Static Fixed Position',
                        style: TextStyle(
                          color: _isColorAnimated ? Colors.cyanAccent : Colors.amberAccent,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isColorAnimated,
                    activeThumbColor: Colors.cyanAccent,
                    activeTrackColor: Colors.cyanAccent.withValues(alpha: 0.3),
                    inactiveThumbColor: Colors.amberAccent,
                    onChanged: (val) {
                      setState(() {
                        _isColorAnimated = val;
                        _blobController.setIsColorAnimated(val);
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Color Animation Speed & Wave Intensity (if animated)
            if (_isColorAnimated) ...[
              _buildSlider(
                label: 'Color Flow Speed',
                value: _colorAnimationSpeed,
                min: 0.1,
                max: 4.0,
                onChanged: (val) {
                  setState(() {
                    _colorAnimationSpeed = val;
                    _blobController.setColorAnimationSpeed(val);
                  });
                },
              ),
              _buildSlider(
                label: 'Wave Shimmer Intensity',
                value: _waveIntensity,
                min: 0.0,
                max: 2.0,
                onChanged: (val) {
                  setState(() {
                    _waveIntensity = val;
                    _blobController.setWaveIntensity(val);
                  });
                },
              ),
            ],

            const Divider(color: Colors.white12, height: 16),

            // Gradient Direction / Alignment Selector
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'GRADIENT POSITION / ALIGNMENT',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    _buildAlignmentChip(0, 'Top → Bottom'),
                    _buildAlignmentChip(1, 'Left → Right'),
                    _buildAlignmentChip(2, 'Diagonal'),
                    _buildAlignmentChip(3, 'Radial (Center)'),
                    _buildAlignmentChip(4, 'Sweep (360°)'),
                  ],
                ),
              ),
            ),

            const Divider(color: Colors.white12, height: 16),

            // Rainbow Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RAINBOW CYCLE EFFECT',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: _isRainbowMode,
                    activeThumbColor: Colors.cyanAccent,
                    activeTrackColor: Colors.cyanAccent.withValues(alpha: 0.3),
                    onChanged: (val) {
                      setState(() {
                        _isRainbowMode = val;
                        _blobController.setIsRainbowMode(val);
                      });
                    },
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 16),

            // Presets
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'PRESET THEMES',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: _themes.map((theme) {
                    final bool isCurrent = !_isRainbowMode &&
                        _color1 == theme.c1 &&
                        _color2 == theme.c2;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _color1 = theme.c1;
                          _color2 = theme.c2;
                          _color3 = theme.c3;
                          _isRainbowMode = false;
                          _blobController.setIsRainbowMode(false);
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Colors.cyanAccent.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent ? Colors.cyanAccent : Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [theme.c1, theme.c2, theme.c3],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              theme.name,
                              style: TextStyle(
                                color: isCurrent ? Colors.white : Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const Divider(color: Colors.white12, height: 16),

            // 3-Color Mode Switch
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'USE 3-COLOR GRADIENT',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: _useThreeColors,
                    activeThumbColor: Colors.cyanAccent,
                    activeTrackColor: Colors.cyanAccent.withValues(alpha: 0.3),
                    onChanged: (val) {
                      setState(() {
                        _useThreeColors = val;
                      });
                    },
                  ),
                ],
              ),
            ),

            _buildColorSelector('PRIMARY COLOR', _color1, (color) {
              setState(() {
                _color1 = color;
                _isRainbowMode = false;
                _blobController.setIsRainbowMode(false);
              });
            }),
            const SizedBox(height: 8),
            _buildColorSelector('SECONDARY COLOR', _color2, (color) {
              setState(() {
                _color2 = color;
                _isRainbowMode = false;
                _blobController.setIsRainbowMode(false);
              });
            }),
            if (_useThreeColors) ...[
              const SizedBox(height: 8),
              _buildColorSelector('TERTIARY COLOR', _color3, (color) {
                setState(() {
                  _color3 = color;
                  _isRainbowMode = false;
                  _blobController.setIsRainbowMode(false);
                });
              }),
            ],
          ],
        );
      case 3:
      default:
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.mic,
                  label: 'Voice Command',
                  isActive: _isListening,
                  onTap: _toggleListening,
                  activeColor: Colors.redAccent,
                ),
                _buildActionButton(
                  icon: Icons.graphic_eq,
                  label: 'Audio Pulse',
                  isActive: _isAudioPulseMode,
                  onTap: _togglePulseMode,
                  activeColor: Colors.purpleAccent,
                ),
                _buildActionButton(
                  icon: Icons.refresh,
                  label: 'Random Impulse',
                  isActive: false,
                  onTap: () {
                    _blobController.addRotationImpulse(
                      Offset(
                        (Random().nextDouble() - 0.5) * 50,
                        (Random().nextDouble() - 0.5) * 50,
                      ),
                    );
                  },
                  activeColor: Colors.white,
                ),
                _buildActionButton(
                  icon: Icons.restart_alt,
                  label: 'Reset Rotation',
                  isActive: false,
                  onTap: () {
                    _blobController.resetRotation();
                  },
                  activeColor: Colors.cyanAccent,
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildAlignmentChip(int index, String label) {
    final bool isSelected = _alignmentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _alignmentIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.cyanAccent : Colors.white60,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? activeColor : Colors.white12,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : Colors.white54,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelector(
      String label, Color selectedColor, ValueChanged<Color> onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: _colorPalette.map((color) {
                final bool isSelected = selectedColor == color;
                return GestureDetector(
                  onTap: () => onSelect(color),
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white24,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                value.toStringAsFixed(value % 1 == 0 ? 0 : 2),
                style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: Colors.cyanAccent,
          inactiveColor: Colors.white12,
        ),
      ],
    );
  }
}

class _ThemePreset {
  final String name;
  final Color c1;
  final Color c2;
  final Color c3;
  const _ThemePreset(this.name, this.c1, this.c2, this.c3);
}
