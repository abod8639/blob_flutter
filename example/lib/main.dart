import 'package:flutter/material.dart';
import 'package:particle_blob/particle_blob.dart';
import 'dart:math';

void main() {
  runApp(const AICoreApp());
}

class AICoreApp extends StatelessWidget {
  const AICoreApp({super.key});

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

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  late ParticleBlobController _blobController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // State variables
  int _particleCount = 8000;
  double _baseRadius = 150.0;
  double _pointSize = 2.0;
  double _blobiness = 1.0;
  double _speed = 1.0;
  double _dampingFactor = 0.95;
  double _autoRotationSpeed = 0.5;
  double _noiseFrequency = 1.0;
  double _viewDistance = 2.0;
  Color _color1 = Colors.cyanAccent;
  Color _color2 = Colors.blueAccent;

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
    Colors.white,
  ];

  final List<_ThemePreset> _themes = [
    const _ThemePreset('CYBERPUNK', Colors.blueAccent, Colors.purpleAccent),
    const _ThemePreset('NEON MATRIX', Colors.greenAccent, Colors.teal),
    const _ThemePreset('SOLAR FLARE', Colors.orangeAccent, Colors.redAccent),
    const _ThemePreset('DEEP SPACE', Colors.cyanAccent, Colors.indigoAccent),
    const _ThemePreset('PLASMA CORE', Colors.purpleAccent, Colors.pinkAccent),
    const _ThemePreset('VOID', Colors.white, Colors.blueGrey),
  ];

  @override
  void initState() {
    super.initState();
    _blobController = ParticleBlobController(dampingFactor: _dampingFactor);
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

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _isAudioPulseMode = false; // Disable pulse mode if listening
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
        _isListening = false; // Disable listening mode
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
      body: Stack(
        children: [
          // Background grid or texture could go here
          Positioned.fill(
            top: 10,
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(
                painter: _GridPainter(),
              ),
            ),
          ),
          
          // Main blob
          Row(
            children: [
              ParticleBlob(
                tapScaleFactor: 1.1,
                  gradient: LinearGradient(
                  colors: [_color1, _color2],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                particleCount: _particleCount,
                radius: _baseRadius,
                pointSize: _pointSize,
                controller: _blobController,
              ),
              ParticleBlob(
                tapScaleFactor: 1.1,
                  gradient: LinearGradient(
                  colors: [_color1, _color2],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                particleCount: _particleCount,
                radius: _baseRadius,
                pointSize: _pointSize,
                controller: _blobController,
              ),
            ],
          ),
          
          // UI Overlay
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const Spacer(),
                _buildControlsPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SYSTEM CORE',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              Text(
                'ONLINE',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              
              color: _isListening ? Colors.red.withValues(alpha: 0.2) : Colors.cyan.withValues(alpha: 0.2),
              border: Border.all(color: _isListening ? Colors.redAccent : Colors.cyanAccent),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.redAccent : Colors.cyanAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isListening ? 'RECORDING' : 'IDLE',
                  style: TextStyle(
                    color: _isListening ? Colors.redAccent : Colors.cyanAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabBar(),
          const Divider(color: Colors.white12, height: 24),
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
          _buildTabButton(2, 'AESTHETICS', Icons.palette),
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
          color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.1) : Colors.transparent,
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
          children: [
            _buildSlider(
              label: 'Particle Count',
              value: _particleCount.toDouble(),
              min: 1000,
              max: 20000,
              onChanged: (val) {
                setState(() {
                  _particleCount = val.toInt();
                });
              },
            ),
            _buildSlider(
              label: 'Base Radius',
              value: _baseRadius,
              min: 50,
              max: 300,
              onChanged: (val) {
                setState(() {
                  _baseRadius = val;
                });
              },
            ),
            _buildSlider(
              label: 'Point Size',
              value: _pointSize,
              min: 0.5,
              max: 5.0,
              onChanged: (val) {
                setState(() {
                  _pointSize = val;
                });
              },
            ),
            _buildSlider(
              label: 'Spikiness (Noise Frequency)',
              value: _noiseFrequency,
              min: 0.1,
              max: 5.0,
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
          children: [
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
                      letterSpacing: 1.0,
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SCI-FI PRESET THEMES',
                  style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: _themes.map((theme) {
                    final bool isCurrent = !_isRainbowMode && _color1 == theme.c1 && _color2 == theme.c2;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _color1 = theme.c1;
                          _color2 = theme.c2;
                          _isRainbowMode = false;
                          _blobController.setIsRainbowMode(false);
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCurrent ? Colors.cyanAccent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent ? Colors.cyanAccent : Colors.white12,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [theme.c1, theme.c2]),
                              ),
                            ),
                            const SizedBox(width: 8),
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
              color: isActive ? activeColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
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

  Widget _buildColorSelector(String label, Color selectedColor, ValueChanged<Color> onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
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
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white24,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ] : null,
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
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
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

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0;

    const double step = 40.0;
    
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ThemePreset {
  final String name;
  final Color c1;
  final Color c2;
  const _ThemePreset(this.name, this.c1, this.c2);
}
