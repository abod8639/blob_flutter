import 'dart:math';
import 'dart:ui';
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
      title: 'Sci-Fi AI Core 3D',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF070A12),
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

  // Blob Geometry & Physics State
  int _particleCount = 8000;
  double _baseRadius = 150.0;
  double _pointSize = 2.0;
  double _blobiness = 1.0;
  double _speed = 1.0;
  double _dampingFactor = 0.95;
  double _autoRotationSpeed = 0.5;
  double _noiseFrequency = 1.0;
  double _viewDistance = 2.0;
  BlobNoiseType _noiseType = BlobNoiseType.harmonic;

  // Touch & Dispersion Physics State
  double _dispersion = 0.0;
  double _tapScaleFactor = 0.30;
  double _touchRadiusFactor = 0.35;
  bool _enableHover = true;

  // Color & Gradient State
  Color _color1 = Colors.cyanAccent;
  Color _color2 = Colors.blueAccent;
  Color _color3 = Colors.purpleAccent;
  final bool _useThreeColors = false;
  final bool _isColorAnimated = true;
  final double _colorAnimationSpeed = 1.0;
  final double _waveIntensity = 1.0;
  final int _alignmentIndex =
      0; // 0: Top-Bottom, 1: Left-Right, 2: Diagonal, 3: Radial, 4: Sweep
  bool _isRainbowMode = false;

  // UI Control Panel State
  bool _isPanelExpanded = true;
  int _selectedTab = 0;
  bool _isListening = false;
  bool _isAudioPulseMode = false;

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
    const _ThemePreset(
        'CYBERPUNK', Colors.blueAccent, Colors.purpleAccent, Colors.pinkAccent),
    const _ThemePreset(
        'NEON MATRIX', Colors.greenAccent, Colors.teal, Colors.cyanAccent),
    const _ThemePreset('SOLAR FLARE', Colors.orangeAccent, Colors.redAccent,
        Colors.amberAccent),
    const _ThemePreset('DEEP SPACE', Colors.cyanAccent, Colors.indigoAccent,
        Colors.blueAccent),
    const _ThemePreset('PLASMA CORE', Colors.purpleAccent, Colors.pinkAccent,
        Colors.deepOrangeAccent),
    const _ThemePreset(
        'AURORA', Colors.tealAccent, Colors.indigoAccent, Colors.purpleAccent),
  ];

  @override
  void initState() {
    super.initState();
    _blobController = BlobController(
      dampingFactor: _dampingFactor,
      tapScaleFactor: _tapScaleFactor,
      touchRadiusFactor: _touchRadiusFactor,
      isColorAnimated: _isColorAnimated,
      colorAnimationSpeed: _colorAnimationSpeed,
      waveIntensity: _waveIntensity,
      enableHover: _enableHover,
      noiseType: _noiseType,
    );
    _blobController.setAutoRotationSpeed(_autoRotationSpeed);
    _blobController.setNoiseFrequency(_noiseFrequency);
    _blobController.setViewDistance(_viewDistance);

    // Pulse animation for Audio mode
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
    final colors =
        _useThreeColors ? [_color1, _color2, _color3] : [_color1, _color2];

    switch (_alignmentIndex) {
      case 0:
        return LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 1:
        return LinearGradient(
          colors: colors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case 2:
        return LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 3:
        return RadialGradient(
          colors: colors,
          center: Alignment.center,
          radius: 0.85,
        );
      case 4:
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

  String _getNoiseName(BlobNoiseType type) {
    switch (type) {
      case BlobNoiseType.harmonic:
        return 'Harmonic';
      case BlobNoiseType.spiky:
        return 'Spiky';
      case BlobNoiseType.fractal:
        return 'Fractal';
      case BlobNoiseType.cellular:
        return 'Cellular';
      case BlobNoiseType.vortex:
        return 'Vortex';
      case BlobNoiseType.sphericalHarmonics:
        return 'Cymatics';
      case BlobNoiseType.simplex:
        return 'Simplex';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background ambient light glow matching current primary color
          // Positioned.fill(
          //   child: AnimatedContainer(
          //     duration: const Duration(milliseconds: 500),
          //     decoration: BoxDecoration(
          //       gradient: RadialGradient(
          //         center: Alignment.center,
          //         radius: 0.9,
          //         colors: [
          //           _color1.withValues(alpha: 0.12),
          //           const Color(0xFF070A12),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),

          // 3D Blob Canvas Area (Fills entire screen)
          Positioned.fill(
            child: BlobFlutter(
              tapScaleFactor: _tapScaleFactor,
              touchRadiusFactor: _touchRadiusFactor,
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

          // Top Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title & Badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color:
                                    Colors.cyanAccent.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.blur_on,
                              color: Colors.cyanAccent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SCI-FI AI CORE 3D',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              '${_particleCount.toString()} particles • ${_getNoiseName(_noiseType)}',
                              style: TextStyle(
                                color: Colors.cyanAccent.withValues(alpha: 0.8),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Quick Toggle Action Buttons
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.restart_alt,
                              color: Colors.white70),
                          tooltip: 'إعادة ضبط الدوران',
                          onPressed: () => _blobController.resetRotation(),
                        ),
                        IconButton(
                          icon: Icon(
                            _isPanelExpanded
                                ? Icons.visibility_off_outlined
                                : Icons.tune_rounded,
                            color: Colors.cyanAccent,
                          ),
                          tooltip: _isPanelExpanded
                              ? 'إخفاء لوحة التحكم'
                              : 'إظهار لوحة التحكم',
                          onPressed: () {
                            setState(() {
                              _isPanelExpanded = !_isPanelExpanded;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Quick Noise Selection Bar (Floating Top Carousel)
          Positioned(
            top: 75,
            left: 16,
            right: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: BlobNoiseType.values.map((type) {
                  final bool isSelected = _noiseType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      elevation: isSelected ? 4 : 0,
                      backgroundColor: isSelected
                          ? Colors.cyanAccent.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.4),
                      side: BorderSide(
                        color: isSelected ? Colors.cyanAccent : Colors.white24,
                        width: isSelected ? 1.5 : 0.8,
                      ),
                      label: Text(
                        _getNoiseShortName(type),
                        style: TextStyle(
                          color:
                              isSelected ? Colors.cyanAccent : Colors.white70,
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _noiseType = type;
                          _blobController.setNoiseType(type);
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Floating Collapsible Control Panel (Bottom)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              bottom: true,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: _isPanelExpanded
                    ? _buildExpandedControlPanel()
                    : _buildCollapsedPillButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getNoiseShortName(BlobNoiseType type) {
    switch (type) {
      case BlobNoiseType.harmonic:
        return 'Harmonic';
      case BlobNoiseType.spiky:
        return 'Spiky';
      case BlobNoiseType.fractal:
        return 'Fractal';
      case BlobNoiseType.cellular:
        return 'Cellular';
      case BlobNoiseType.vortex:
        return 'Vortex';
      case BlobNoiseType.sphericalHarmonics:
        return 'Cymatics';
      case BlobNoiseType.simplex:
        return 'Simplex';
    }
  }

  // Small floating pill button shown when control panel is collapsed
  Widget _buildCollapsedPillButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        key: const ValueKey('collapsed_pill'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: const Color(0xFF070A12).withValues(alpha: 0.75),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: BorderSide(
                    color: Colors.cyanAccent.withValues(alpha: 0.6),
                    width: 1.5),
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isPanelExpanded = true;
                  });
                },
                borderRadius: BorderRadius.circular(30),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // const Icon(Icons.memory,
                      //     color: Colors.cyanAccent, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'HUD TERMINAL',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.cyanAccent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _getNoiseShortName(_noiseType),
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Glassmorphic Collapsible Control Panel with Sci-Fi HUD style
  Widget _buildExpandedControlPanel() {
    return SizedBox(
        width: double.infinity,
        child: ClipRRect(
          key: const ValueKey('expanded_panel'),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(0),
              decoration: BoxDecoration(
                color: const Color(0xFF070A12).withValues(alpha: 0.65),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border.all(
                    color: Colors.cyanAccent.withValues(alpha: 0.3),
                    width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: -5,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header of panel with Title and Collapse Button
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.cyanAccent.withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      border: Border(
                        bottom: BorderSide(
                            color: Colors.cyanAccent.withValues(alpha: 0.2),
                            width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.memory,
                                color: Colors.cyanAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'HUD CONTROL TERMINAL',
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: Colors.cyanAccent, size: 24),
                          tooltip: 'Control Panel',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              _isPanelExpanded = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: _buildTabBar(),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Divider(color: Colors.white12, height: 16),
                  ),

                  // Tab Content Area
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _buildTabContent(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  Widget _buildTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTabButton(0, 'Algorithms', Icons.alt_route),
          _buildTabButton(1, 'Touch', Icons.touch_app),
          _buildTabButton(2, 'Physics', Icons.filter_tilt_shift),
          _buildTabButton(3, 'colors', Icons.palette),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.white12,
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
                color: isSelected ? Colors.cyanAccent : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
        // Tab 0: Algorithms
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Choose a 3D Particle Displacement Algorithm:',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BlobNoiseType.values.map((type) {
                return _buildNoiseAlgorithmCard(type);
              }).toList(),
            ),
          ],
        );
      case 1:
        // Tab 1: Touch & Interaction Controls
        return Column(
          children: [
            // Touch Radius Factor Slider
            _buildSlider(
              label: 'قطر التفاعل باللمس (Touch Radius Factor)',
              value: _touchRadiusFactor,
              min: 0.1,
              max: 3.0,
              displayUnit: 'x',
              onChanged: (val) {
                setState(() {
                  _touchRadiusFactor = val;
                  _blobController.setTouchRadiusFactor(val);
                });
              },
            ),

            // Tap Scale Factor
            _buildSlider(
              label: 'حساسية التشتت باللمس (Tap Scale Factor)',
              value: _tapScaleFactor,
              min: 0.0,
              max: 3.0,
              displayUnit: 'x',
              onChanged: (val) {
                setState(() {
                  _tapScaleFactor = val;
                  _blobController.setTapScaleFactor(val);
                });
              },
            ),

            // Radial Dispersion Slider
            _buildSlider(
              label: 'شدة التشتت الإشعاعي (Radial Dispersion)',
              value: _dispersion,
              min: 0.0,
              max: 2.0,
              onChanged: (val) {
                setState(() {
                  _dispersion = val;
                  _blobController.setDispersion(val);
                });
              },
            ),

            // Mouse Hover Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              margin: const EdgeInsets.only(top: 4, bottom: 6),
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
                        'تفاعل تحويم الماوس (Mouse Hover)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'تفعيل التفاعل بمجرد مرّور المؤشر دون النقر',
                        style: TextStyle(
                          color: Colors.white54,
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
          ],
        );
      case 2:
        // Tab 2: Physics & Geometry
        return Column(
          children: [
            _buildSlider(
              label: 'عدد الجسيمات (Particle Count)',
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
              label: 'نصف القطر (Base Radius)',
              value: _baseRadius,
              min: 50.0,
              max: 300.0,
              onChanged: (val) {
                setState(() {
                  _baseRadius = val;
                });
              },
            ),
            _buildSlider(
              label: 'حجم النقطة (Point Size)',
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
              label: 'سعة التشوه (Blobiness)',
              value: _blobiness,
              min: 0.0,
              max: 4.0,
              onChanged: (val) {
                setState(() {
                  _blobiness = val;
                  _blobController.setBlobiness(val);
                });
              },
            ),
            _buildSlider(
              label: 'تردد وكثافة التوجس (Noise Frequency)',
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
            _buildSlider(
              label: 'سرعة الحركة (Animation Speed)',
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
              label: 'الدوران التلقائي (Auto Rotation)',
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
              label: 'معامل الخمود والتخميد (Damping)',
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
              label: 'مسافة الكاميرا (Camera View Distance)',
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
      case 3:
      default:
        // Tab 3: Colors & System Modes
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Presets
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'السمات اللونية الجاهزة (Preset Themes):',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
                      margin: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
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
                              color: isCurrent ? Colors.white : Colors.white60,
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
            const SizedBox(height: 10),

            // Special System Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.mic,
                  label: 'الأمر الصوتي',
                  isActive: _isListening,
                  onTap: _toggleListening,
                  activeColor: Colors.redAccent,
                ),
                _buildActionButton(
                  icon: Icons.graphic_eq,
                  label: 'النبض الصوتي',
                  isActive: _isAudioPulseMode,
                  onTap: _togglePulseMode,
                  activeColor: Colors.purpleAccent,
                ),
                _buildActionButton(
                  icon: Icons.flash_on,
                  label: 'دفعة عشوائية',
                  isActive: false,
                  onTap: () {
                    _blobController.addRotationImpulse(
                      Offset(
                        (Random().nextDouble() - 0.5) * 50,
                        (Random().nextDouble() - 0.5) * 50,
                      ),
                    );
                  },
                  activeColor: Colors.amberAccent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'تخصيص اللون الأساسي (Color 1):',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _colorPalette.map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _color1 = color;
                        _isRainbowMode = false;
                        _blobController.setIsRainbowMode(false);
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color1 == color
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'تخصيص اللون الثانوي (Color 2):',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _colorPalette.map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _color2 = color;
                        _isRainbowMode = false;
                        _blobController.setIsRainbowMode(false);
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color2 == color
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildNoiseAlgorithmCard(BlobNoiseType type) {
    final bool isSelected = _noiseType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _noiseType = type;
          _blobController.setNoiseType(type);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.cyanAccent
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.blur_on,
              color: isSelected ? Colors.cyanAccent : Colors.white38,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              _getNoiseName(type),
              style: TextStyle(
                color: isSelected ? Colors.cyanAccent : Colors.white54,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? activeColor : Colors.white12,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : Colors.white54,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
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

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    String displayUnit = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}$displayUnit',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: const SliderThemeData(
            trackHeight: 3,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: Colors.cyanAccent,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.cyanAccent,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
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
