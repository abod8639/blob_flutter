import 'dart:ui';

import 'package:blob_flutter/blob_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const ParticleBlobExampleApp());
}

/// Root application widget for the 3D Particle Blob demonstration.
class ParticleBlobExampleApp extends StatelessWidget {
  const ParticleBlobExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlobFlutter 3D Control Center',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF060911),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

/// Comprehensive interactive dashboard demonstrating all features of [BlobController].
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late final BlobController _controller;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Geometry State
  double _radius = 160.0;
  double _pointSize = 2.2;
  int _particleCount = 6000;
  double _scale = 1.0;
  bool _enablePinchToScale = true;

  // Dynamics & Noise State
  BlobNoiseType _noiseType = BlobNoiseType.harmonic;
  double _blobiness = 1.0;
  double _speed = 1.0;
  double _autoRotationSpeed = 0.6;
  double _noiseFrequency = 1.0;
  double _viewDistance = 2.0;

  // Physics & Touch State
  double _dampingFactor = 0.95;
  double _tapScaleFactor = 1.0;
  double _touchRadiusFactor = 1.0;
  double _dispersion = 0.0;
  bool _enableHover = true;

  // Color & Shader State
  bool _isRainbowMode = false;
  bool _isColorAnimated = true;
  double _colorAnimationSpeed = 1.0;
  double _waveIntensity = 1.0;
  int _gradientTypeIndex = 2; // 0: Top-Bottom, 1: Left-Right, 2: Diagonal, 3: Radial, 4: Sweep
  Color _color1 = Colors.cyanAccent;
  Color _color2 = Colors.purpleAccent;

  // UI State
  bool _isPanelExpanded = true;
  int _selectedTab = 0;
  bool _isVoiceSimActive = false;

  final List<Color> _palette = const [
    Colors.cyanAccent,
    Colors.purpleAccent,
    Colors.pinkAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.tealAccent,
    Colors.amberAccent,
    Colors.orangeAccent,
    Colors.deepOrangeAccent,
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _controller = BlobController(
      radius: _radius,
      pointSize: _pointSize,
      particleCount: _particleCount,
      scale: _scale,
      dampingFactor: _dampingFactor,
      tapScaleFactor: _tapScaleFactor,
      touchRadiusFactor: _touchRadiusFactor,
      isColorAnimated: _isColorAnimated,
      colorAnimationSpeed: _colorAnimationSpeed,
      waveIntensity: _waveIntensity,
      enableHover: _enableHover,
      enablePinchToScale: _enablePinchToScale,
      noiseType: _noiseType,
      gradient: _computeGradient(),
    );

    _controller.setAutoRotationSpeed(_autoRotationSpeed);
    _controller.setNoiseFrequency(_noiseFrequency);
    _controller.setViewDistance(_viewDistance);

    // Audio / Voice simulation pulse controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    )..addListener(() {
        if (_isVoiceSimActive) {
          final double val = _pulseAnimation.value;
          _controller.setDispersion(val * 0.8);
          _controller.setBlobiness(1.0 + val * 0.9);
        }
      });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Gradient _computeGradient() {
    final colors = [_color1, _color2];
    switch (_gradientTypeIndex) {
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  void _applyGradient() {
    _controller.setGradient(_computeGradient());
  }

  void _toggleVoiceSimulation() {
    setState(() {
      _isVoiceSimActive = !_isVoiceSimActive;
      if (_isVoiceSimActive) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _controller.setDispersion(_dispersion);
        _controller.setBlobiness(_blobiness);
      }
    });
  }

  void _applyPreset({
    required BlobNoiseType noiseType,
    required double blobiness,
    required double speed,
    required double autoRot,
    required Color color1,
    required Color color2,
    bool rainbow = false,
  }) {
    setState(() {
      _noiseType = noiseType;
      _blobiness = blobiness;
      _speed = speed;
      _autoRotationSpeed = autoRot;
      _color1 = color1;
      _color2 = color2;
      _isRainbowMode = rainbow;

      _controller.setNoiseType(noiseType);
      _controller.setBlobiness(blobiness);
      _controller.setSpeed(speed);
      _controller.setAutoRotationSpeed(autoRot);
      _controller.setIsRainbowMode(rainbow);
      _applyGradient();
    });
  }

  String _colorToCode(Color c) {
    if (c == Colors.cyanAccent) return 'Colors.cyanAccent';
    if (c == Colors.purpleAccent) return 'Colors.purpleAccent';
    if (c == Colors.pinkAccent) return 'Colors.pinkAccent';
    if (c == Colors.blueAccent) return 'Colors.blueAccent';
    if (c == Colors.greenAccent) return 'Colors.greenAccent';
    if (c == Colors.tealAccent) return 'Colors.tealAccent';
    if (c == Colors.amberAccent) return 'Colors.amberAccent';
    if (c == Colors.orangeAccent) return 'Colors.orangeAccent';
    if (c == Colors.deepOrangeAccent) return 'Colors.deepOrangeAccent';
    if (c == Colors.white) return 'Colors.white';
    final hex = c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
    return 'const Color(0x$hex)';
  }

  String _formatDouble(double val) {
    if (val % 1 == 0) {
      return '${val.toInt()}.0';
    }
    return val.toStringAsFixed(2);
  }

  String _generateGradientCode() {
    final c1 = _colorToCode(_color1);
    final c2 = _colorToCode(_color2);
    switch (_gradientTypeIndex) {
      case 0:
        return 'const LinearGradient(\n'
            '          colors: [$c1, $c2],\n'
            '          begin: Alignment.topCenter,\n'
            '          end: Alignment.bottomCenter,\n'
            '        )';
      case 1:
        return 'const LinearGradient(\n'
            '          colors: [$c1, $c2],\n'
            '          begin: Alignment.centerLeft,\n'
            '          end: Alignment.centerRight,\n'
            '        )';
      case 2:
        return 'const LinearGradient(\n'
            '          colors: [$c1, $c2],\n'
            '          begin: Alignment.topLeft,\n'
            '          end: Alignment.bottomRight,\n'
            '        )';
      case 3:
        return 'const RadialGradient(\n'
            '          colors: [$c1, $c2],\n'
            '          radius: 0.85,\n'
            '        )';
      case 4:
        return 'const SweepGradient(\n'
            '          colors: [$c1, $c2],\n'
            '        )';
      default:
        return 'const LinearGradient(\n'
            '          colors: [$c1, $c2],\n'
            '        )';
    }
  }

  String _generateSimpleWidgetCode() {
    final buffer = StringBuffer();
    buffer.writeln('BlobFlutter(');
    buffer.writeln('  radius: ${_formatDouble(_radius)},');
    buffer.writeln('  pointSize: ${_formatDouble(_pointSize)},');
    buffer.writeln('  particleCount: $_particleCount,');
    buffer.writeln('  noiseType: BlobNoiseType.${_noiseType.name},');
    if (_speed != 1.0) {
      buffer.writeln('  speed: ${_formatDouble(_speed)},');
    }
    if (!_isColorAnimated) {
      buffer.writeln('  isColorAnimated: false,');
    }
    if (_colorAnimationSpeed != 1.0) {
      buffer.writeln('  colorAnimationSpeed: ${_formatDouble(_colorAnimationSpeed)},');
    }
    if (_waveIntensity != 1.0) {
      buffer.writeln('  waveIntensity: ${_formatDouble(_waveIntensity)},');
    }
    if (_enableHover) {
      buffer.writeln('  enableHover: true,');
    }
    buffer.writeln('  gradient: ${_generateGradientCode()},');
    buffer.write(')');
    return buffer.toString();
  }

  String _generateControllerCode() {
    final buffer = StringBuffer();
    buffer.writeln('// 1. Controller Initialization in State');
    buffer.writeln('late final BlobController _controller;');
    buffer.writeln();
    buffer.writeln('@override');
    buffer.writeln('void initState() {');
    buffer.writeln('  super.initState();');
    buffer.writeln('  _controller = BlobController(');
    buffer.writeln('    radius: ${_formatDouble(_radius)},');
    buffer.writeln('    pointSize: ${_formatDouble(_pointSize)},');
    buffer.writeln('    particleCount: $_particleCount,');
    if (_scale != 1.0) {
      buffer.writeln('    scale: ${_formatDouble(_scale)},');
    }
    if (_dampingFactor != 0.92) {
      buffer.writeln('    dampingFactor: ${_formatDouble(_dampingFactor)},');
    }
    if (_tapScaleFactor != 1.0) {
      buffer.writeln('    tapScaleFactor: ${_formatDouble(_tapScaleFactor)},');
    }
    if (_touchRadiusFactor != 1.0) {
      buffer.writeln('    touchRadiusFactor: ${_formatDouble(_touchRadiusFactor)},');
    }
    if (!_isColorAnimated) {
      buffer.writeln('    isColorAnimated: false,');
    }
    if (_colorAnimationSpeed != 1.0) {
      buffer.writeln('    colorAnimationSpeed: ${_formatDouble(_colorAnimationSpeed)},');
    }
    if (_waveIntensity != 1.0) {
      buffer.writeln('    waveIntensity: ${_formatDouble(_waveIntensity)},');
    }
    if (_enableHover) {
      buffer.writeln('    enableHover: true,');
    }
    if (!_enablePinchToScale) {
      buffer.writeln('    enablePinchToScale: false,');
    }
    if (_isRainbowMode) {
      buffer.writeln('    isRainbowMode: true,');
    }
    buffer.writeln('    noiseType: BlobNoiseType.${_noiseType.name},');
    buffer.writeln('    gradient: ${_generateGradientCode()},');
    buffer.writeln('  );');
    if (_autoRotationSpeed != 0.5) {
      buffer.writeln('  _controller.setAutoRotationSpeed(${_formatDouble(_autoRotationSpeed)});');
    }
    if (_noiseFrequency != 1.0) {
      buffer.writeln('  _controller.setNoiseFrequency(${_formatDouble(_noiseFrequency)});');
    }
    if (_viewDistance != 2.0) {
      buffer.writeln('  _controller.setViewDistance(${_formatDouble(_viewDistance)});');
    }
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('@override');
    buffer.writeln('void dispose() {');
    buffer.writeln('  _controller.dispose();');
    buffer.writeln('  super.dispose();');
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('// 2. Widget Placement');
    buffer.writeln('BlobFlutter(');
    buffer.writeln('  controller: _controller,');
    buffer.write(')');
    return buffer.toString();
  }

  void _showCodeExportDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => _CodeExportModal(
        simpleCode: _generateSimpleWidgetCode(),
        controllerCode: _generateControllerCode(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060911),
      body: Stack(
        children: [
          // 3D Particle Blob Canvas (Full Screen)
          Positioned.fill(
            child: BlobFlutter(
              controller: _controller,
              radius: _radius,
              pointSize: _pointSize,
              particleCount: _particleCount,
              noiseType: _noiseType,
              gradient: _computeGradient(),
              isColorAnimated: _isColorAnimated,
              colorAnimationSpeed: _colorAnimationSpeed,
              waveIntensity: _waveIntensity,
              enableHover: _enableHover,
            ),
          ),

          // Top Header HUD Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.cyanAccent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.blur_on_rounded,
                            color: Colors.cyanAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'BLOB CONTROLLER 3D',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.3,
                              ),
                            ),
                            Text(
                              '$_particleCount pts • ${_getNoiseName(_noiseType).toUpperCase()}',
                              style: TextStyle(
                                color: Colors.cyanAccent.withValues(alpha: 0.8),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Quick Actions
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.code_rounded, color: Colors.cyanAccent),
                          tooltip: 'Export & Copy Code',
                          onPressed: _showCodeExportDialog,
                        ),
                        IconButton(
                          icon: const Icon(Icons.restart_alt, color: Colors.white70),
                          tooltip: 'Reset Geometry & Transform',
                          onPressed: () {
                            _controller.resetAll();
                            setState(() {
                              _scale = 1.0;
                              _dispersion = 0.0;
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            _isPanelExpanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.tune_rounded,
                            color: Colors.cyanAccent,
                          ),
                          tooltip: _isPanelExpanded ? 'Hide Panel' : 'Show Panel',
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

          // Bottom Control Panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              bottom: true,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _isPanelExpanded
                    ? _buildExpandedPanel()
                    : _buildCollapsedButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        key: const ValueKey('collapsed_hud_btn'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: const Color(0xFF090D1A).withValues(alpha: 0.85),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: BorderSide(
                  color: Colors.cyanAccent.withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => setState(() => _isPanelExpanded = true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, color: Colors.cyanAccent, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'OPEN CONTROLLER HUD',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _getNoiseName(_noiseType),
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

  Widget _buildExpandedPanel() {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        key: const ValueKey('expanded_hud_panel'),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF070B16).withValues(alpha: 0.82),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border.all(
                color: Colors.cyanAccent.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withValues(alpha: 0.12),
                  blurRadius: 25,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Panel Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.dashboard_customize_rounded,
                              size: 16, color: Colors.cyanAccent.withValues(alpha: 0.9)),
                          const SizedBox(width: 8),
                          const Text(
                            'CONTROLLER RUNTIME DASHBOARD',
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.code_rounded,
                                color: Colors.cyanAccent, size: 20),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Export & Copy Code',
                            onPressed: _showCodeExportDialog,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white70, size: 20),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _isPanelExpanded = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Category Navigation Bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _buildNavTab(0, 'Algorithms', Icons.alt_route_rounded),
                      _buildNavTab(1, 'Dynamics', Icons.speed_rounded),
                      _buildNavTab(2, 'Geometry', Icons.architecture_rounded),
                      _buildNavTab(3, 'Physics', Icons.touch_app_rounded),
                      _buildNavTab(4, 'Shaders', Icons.palette_rounded),
                      _buildNavTab(5, 'Presets', Icons.auto_awesome_rounded),
                      _buildNavTab(6, 'Export Code', Icons.code_rounded),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Divider(color: Colors.white10, height: 16),
                ),

                // Scrollable Content Area
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildActiveTabContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavTab(int index, String label, IconData icon) {
    final bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
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
              size: 15,
              color: isSelected ? Colors.cyanAccent : Colors.white60,
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

  Widget _buildActiveTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildAlgorithmsTab();
      case 1:
        return _buildDynamicsTab();
      case 2:
        return _buildGeometryTab();
      case 3:
        return _buildPhysicsTab();
      case 4:
        return _buildShadersTab();
      case 5:
        return _buildPresetsTab();
      case 6:
        return _buildExportCodeTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Tab 6: Export Code ───────────────────────────────────────────────────
  Widget _buildExportCodeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ready-to-Use Flutter Code:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                foregroundColor: Colors.cyanAccent,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.open_in_full_rounded, size: 14),
              label: const Text(
                'Open Modal',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
              onPressed: _showCodeExportDialog,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF030712),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.cyanAccent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.terminal_rounded,
                          size: 14, color: Colors.cyanAccent),
                      SizedBox(width: 6),
                      Text(
                        'BlobFlutter Widget',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        color: Colors.cyanAccent, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copy Code',
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _generateSimpleWidgetCode()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: Colors.cyanAccent, size: 18),
                              SizedBox(width: 8),
                              Text('Simple widget code copied!'),
                            ],
                          ),
                          backgroundColor: const Color(0xFF0B132B),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText.rich(
                  _DartSyntaxHighlighter.format(
                    _generateSimpleWidgetCode(),
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab 0: Algorithms ─────────────────────────────────────────────────────
  Widget _buildAlgorithmsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Procedural 3D Noise Algorithm:',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: BlobNoiseType.values.map((type) {
            final bool isSelected = _noiseType == type;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _noiseType = type;
                  _controller.setNoiseType(type);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.cyanAccent.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.04),
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
                      isSelected ? Icons.check_circle_rounded : Icons.blur_on,
                      color: isSelected ? Colors.cyanAccent : Colors.white38,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getNoiseName(type),
                      style: TextStyle(
                        color: isSelected ? Colors.cyanAccent : Colors.white70,
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Tab 1: Dynamics ───────────────────────────────────────────────────────
  Widget _buildDynamicsTab() {
    return Column(
      children: [
        _buildSlider(
          label: 'Noise Amplitude (Blobiness)',
          value: _blobiness,
          min: 0.0,
          max: 4.0,
          onChanged: (v) {
            setState(() {
              _blobiness = v;
              _controller.setBlobiness(v);
            });
          },
        ),
        _buildSlider(
          label: 'Animation Speed Multiplier',
          value: _speed,
          min: 0.0,
          max: 4.0,
          displayUnit: 'x',
          onChanged: (v) {
            setState(() {
              _speed = v;
              _controller.setSpeed(v);
            });
          },
        ),
        _buildSlider(
          label: 'Auto-Rotation Velocity (Spin)',
          value: _autoRotationSpeed,
          min: -3.0,
          max: 3.0,
          onChanged: (v) {
            setState(() {
              _autoRotationSpeed = v;
              _controller.setAutoRotationSpeed(v);
            });
          },
        ),
        _buildSlider(
          label: 'Noise Frequency (Density)',
          value: _noiseFrequency,
          min: 0.2,
          max: 4.0,
          displayUnit: 'x',
          onChanged: (v) {
            setState(() {
              _noiseFrequency = v;
              _controller.setNoiseFrequency(v);
            });
          },
        ),
        _buildSlider(
          label: 'Perspective Camera Distance',
          value: _viewDistance,
          min: 1.0,
          max: 4.0,
          onChanged: (v) {
            setState(() {
              _viewDistance = v;
              _controller.setViewDistance(v);
            });
          },
        ),
      ],
    );
  }

  // ── Tab 2: Geometry & Scale ───────────────────────────────────────────────
  Widget _buildGeometryTab() {
    return Column(
      children: [
        _buildSlider(
          label: 'Sphere Base Radius',
          value: _radius,
          min: 50.0,
          max: 280.0,
          displayUnit: ' px',
          onChanged: (v) {
            setState(() {
              _radius = v;
              _controller.setRadius(v);
            });
          },
        ),
        _buildSlider(
          label: 'Particle Point Size',
          value: _pointSize,
          min: 0.8,
          max: 5.0,
          displayUnit: ' px',
          onChanged: (v) {
            setState(() {
              _pointSize = v;
              _controller.setPointSize(v);
            });
          },
        ),
        _buildSlider(
          label: 'Particle Count (Buffer)',
          value: _particleCount.toDouble(),
          min: 1000,
          max: 12000,
          onChanged: (v) {
            final int count = v.round();
            setState(() {
              _particleCount = count;
              _controller.setParticleCount(count);
            });
          },
        ),
        _buildSlider(
          label: 'Zoom / Scale Multiplier',
          value: _scale,
          min: 0.3,
          max: 3.0,
          displayUnit: 'x',
          onChanged: (v) {
            setState(() {
              _scale = v;
              _controller.setScale(v);
            });
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    foregroundColor: Colors.cyanAccent,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.zoom_in, size: 18),
                  label: const Text('Zoom In (+0.15)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    _controller.zoomIn(0.15);
                    setState(() => _scale = _controller.scale);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    foregroundColor: Colors.cyanAccent,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.zoom_out, size: 18),
                  label: const Text('Zoom Out (-0.15)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    _controller.zoomOut(0.15);
                    setState(() => _scale = _controller.scale);
                  },
                ),
              ),
            ],
          ),
        ),
        _buildToggle(
          title: 'Pinch-To-Scale Multi-Touch',
          value: _enablePinchToScale,
          onChanged: (val) {
            setState(() {
              _enablePinchToScale = val;
              _controller.setEnablePinchToScale(val);
            });
          },
        ),
      ],
    );
  }

  // ── Tab 3: Physics & Touch ────────────────────────────────────────────────
  Widget _buildPhysicsTab() {
    return Column(
      children: [
        _buildSlider(
          label: 'Inertial Damping (Drag Momentum)',
          value: _dampingFactor,
          min: 0.70,
          max: 0.99,
          onChanged: (v) {
            setState(() {
              _dampingFactor = v;
              _controller.setDampingFactor(v);
            });
          },
        ),
        _buildSlider(
          label: 'Tap Dispersion Scale Factor',
          value: _tapScaleFactor,
          min: 0.0,
          max: 3.0,
          displayUnit: 'x',
          onChanged: (v) {
            setState(() {
              _tapScaleFactor = v;
              _controller.setTapScaleFactor(v);
            });
          },
        ),
        _buildSlider(
          label: 'Touch Interaction Radius Multiplier',
          value: _touchRadiusFactor,
          min: 0.2,
          max: 3.0,
          displayUnit: 'x',
          onChanged: (v) {
            setState(() {
              _touchRadiusFactor = v;
              _controller.setTouchRadiusFactor(v);
            });
          },
        ),
        _buildSlider(
          label: 'Radial Dispersion Force',
          value: _dispersion,
          min: 0.0,
          max: 2.0,
          onChanged: (v) {
            setState(() {
              _dispersion = v;
              _controller.setDispersion(v);
            });
          },
        ),
        _buildToggle(
          title: 'Desktop Cursor Hover Tracking',
          value: _enableHover,
          onChanged: (val) {
            setState(() {
              _enableHover = val;
              _controller.setEnableHover(val);
            });
          },
        ),
      ],
    );
  }

  // ── Tab 4: Shaders & Colors ───────────────────────────────────────────────
  Widget _buildShadersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToggle(
          title: 'Rainbow Mode (HSV Cycle)',
          value: _isRainbowMode,
          onChanged: (val) {
            setState(() {
              _isRainbowMode = val;
              _controller.setIsRainbowMode(val);
            });
          },
        ),
        _buildToggle(
          title: 'Animated Color Flow',
          value: _isColorAnimated,
          onChanged: (val) {
            setState(() {
              _isColorAnimated = val;
              _controller.setIsColorAnimated(val);
            });
          },
        ),
        _buildSlider(
          label: 'Color Animation Velocity',
          value: _colorAnimationSpeed,
          min: 0.0,
          max: 4.0,
          displayUnit: 'x',
          onChanged: (v) {
            setState(() {
              _colorAnimationSpeed = v;
              _controller.setColorAnimationSpeed(v);
            });
          },
        ),
        _buildSlider(
          label: 'Liquid Wave Shimmer Intensity',
          value: _waveIntensity,
          min: 0.0,
          max: 3.0,
          displayUnit: 'x',
          onChanged: (v) {
            setState(() {
              _waveIntensity = v;
              _controller.setWaveIntensity(v);
            });
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Gradient Direction & Geometry:',
          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildGradientTypeChip(0, 'Vertical'),
              _buildGradientTypeChip(1, 'Horizontal'),
              _buildGradientTypeChip(2, 'Diagonal'),
              _buildGradientTypeChip(3, 'Radial'),
              _buildGradientTypeChip(4, 'Sweep'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Primary Color:',
          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        _buildPaletteSelector(
          selected: _color1,
          onSelect: (c) {
            setState(() {
              _color1 = c;
              _isRainbowMode = false;
              _controller.setIsRainbowMode(false);
              _applyGradient();
            });
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Secondary Color:',
          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        _buildPaletteSelector(
          selected: _color2,
          onSelect: (c) {
            setState(() {
              _color2 = c;
              _isRainbowMode = false;
              _controller.setIsRainbowMode(false);
              _applyGradient();
            });
          },
        ),
      ],
    );
  }

  Widget _buildGradientTypeChip(int index, String label) {
    final bool isSelected = _gradientTypeIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _gradientTypeIndex = index;
          _applyGradient();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.white12,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.cyanAccent : Colors.white70,
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ── Tab 5: Presets & Realtime Trigger ─────────────────────────────────────
  Widget _buildPresetsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Voice / Audio Pulse simulation button
        GestureDetector(
          onTap: _toggleVoiceSimulation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _isVoiceSimActive
                  ? Colors.redAccent.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isVoiceSimActive ? Colors.redAccent : Colors.white12,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isVoiceSimActive ? Icons.mic : Icons.mic_none_rounded,
                  color: _isVoiceSimActive ? Colors.redAccent : Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isVoiceSimActive ? 'ACTIVE AUDIO PULSE' : 'SIMULATE VOICE INPUT',
                        style: TextStyle(
                          color: _isVoiceSimActive ? Colors.redAccent : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Modulates dispersion & blobiness in real-time',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isVoiceSimActive ? Colors.redAccent : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isVoiceSimActive ? 'STOP' : 'START',
                    style: TextStyle(
                      color: _isVoiceSimActive ? Colors.white : Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),
        const Text(
          'Quick Theme & Shape Presets:',
          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPresetChip(
              name: 'CYBERPUNK',
              color: Colors.pinkAccent,
              onTap: () => _applyPreset(
                noiseType: BlobNoiseType.spiky,
                blobiness: 1.8,
                speed: 1.6,
                autoRot: 1.0,
                color1: Colors.cyanAccent,
                color2: Colors.pinkAccent,
              ),
            ),
            _buildPresetChip(
              name: 'NEON MATRIX',
              color: Colors.greenAccent,
              onTap: () => _applyPreset(
                noiseType: BlobNoiseType.simplex,
                blobiness: 1.2,
                speed: 1.2,
                autoRot: 0.8,
                color1: Colors.greenAccent,
                color2: Colors.tealAccent,
              ),
            ),
            _buildPresetChip(
              name: 'SOLAR FLARE',
              color: Colors.orangeAccent,
              onTap: () => _applyPreset(
                noiseType: BlobNoiseType.fractal,
                blobiness: 2.2,
                speed: 2.0,
                autoRot: -1.2,
                color1: Colors.orangeAccent,
                color2: Colors.deepOrangeAccent,
              ),
            ),
            _buildPresetChip(
              name: 'COSMIC VORTEX',
              color: Colors.purpleAccent,
              onTap: () => _applyPreset(
                noiseType: BlobNoiseType.vortex,
                blobiness: 1.6,
                speed: 1.5,
                autoRot: 1.5,
                color1: Colors.purpleAccent,
                color2: Colors.blueAccent,
              ),
            ),
            _buildPresetChip(
              name: 'CYMATICS',
              color: Colors.cyanAccent,
              onTap: () => _applyPreset(
                noiseType: BlobNoiseType.sphericalHarmonics,
                blobiness: 1.5,
                speed: 1.0,
                autoRot: 0.5,
                color1: Colors.cyanAccent,
                color2: Colors.indigoAccent,
              ),
            ),
            _buildPresetChip(
              name: 'RAINBOW LIQUID',
              color: Colors.amberAccent,
              onTap: () => _applyPreset(
                noiseType: BlobNoiseType.harmonic,
                blobiness: 1.0,
                speed: 1.2,
                autoRot: 0.7,
                color1: Colors.amberAccent,
                color2: Colors.purpleAccent,
                rainbow: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────
  Widget _buildPresetChip({
    required String name,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildPaletteSelector({
    required Color selected,
    required ValueChanged<Color> onSelect,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _palette.map((color) {
          final bool isSelected = selected == color;
          return GestureDetector(
            onTap: () => onSelect(color),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildToggle({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.cyanAccent,
            activeTrackColor: Colors.cyanAccent.withValues(alpha: 0.4),
            onChanged: onChanged,
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
    final double clampedVal = value.clamp(min, max);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                '${clampedVal.toStringAsFixed(clampedVal % 1 == 0 ? 0 : 2)}$displayUnit',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
              value: clampedVal,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
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
}

/// Modal dialog that presents the current 3D Blob configuration as simplified, copyable Dart code.
class _CodeExportModal extends StatefulWidget {
  final String simpleCode;
  final String controllerCode;

  const _CodeExportModal({
    required this.simpleCode,
    required this.controllerCode,
  });

  @override
  State<_CodeExportModal> createState() => _CodeExportModalState();
}

class _CodeExportModalState extends State<_CodeExportModal> {
  int _selectedMode = 0; // 0: Simple Widget, 1: With Controller
  bool _copied = false;

  String get _currentCode =>
      _selectedMode == 0 ? widget.simpleCode : widget.controllerCode;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _currentCode));
    setState(() => _copied = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.cyanAccent, size: 20),
            const SizedBox(width: 10),
            Text(
              _selectedMode == 0
                  ? 'Widget code copied to clipboard!'
                  : 'Controller code copied to clipboard!',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0B132B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.4)),
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 40,
        vertical: 24,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
            decoration: BoxDecoration(
              color: const Color(0xFF080C19).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.cyanAccent.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.cyanAccent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Icon(
                          Icons.code_rounded,
                          color: Colors.cyanAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Generated Flutter Code',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Copy & paste directly into your Flutter UI',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white10, height: 1),

                // Mode Selector Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildModeTab(
                          index: 0,
                          title: 'Simple Widget',
                          subtitle: 'BlobFlutter(...)',
                          icon: Icons.widgets_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildModeTab(
                          index: 1,
                          title: 'With Controller',
                          subtitle: 'BlobController + BlobFlutter',
                          icon: Icons.tune_rounded,
                        ),
                      ),
                    ],
                  ),
                ),

                // Code Display Area
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF030712),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.cyanAccent.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _CodeViewWithLineNumbers(
                                code: _currentCode,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                        // Quick floating copy badge
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: _copyToClipboard,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _copied
                                        ? Colors.greenAccent
                                        : Colors.white24,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _copied
                                          ? Icons.check_rounded
                                          : Icons.copy_rounded,
                                      color: _copied
                                          ? Colors.greenAccent
                                          : Colors.cyanAccent,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _copied ? 'Copied' : 'Copy',
                                      style: TextStyle(
                                        color: _copied
                                            ? Colors.greenAccent
                                            : Colors.cyanAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Footer
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Close'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _copied
                                ? Colors.greenAccent
                                : Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor: (_copied
                                    ? Colors.greenAccent
                                    : Colors.cyanAccent)
                                .withValues(alpha: 0.5),
                          ),
                          icon: Icon(
                            _copied
                                ? Icons.check_rounded
                                : Icons.copy_all_rounded,
                            size: 19,
                          ),
                          label: Text(
                            _copied ? 'Code Copied!' : 'Copy to Clipboard',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                          onPressed: _copyToClipboard,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSelected = _selectedMode == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = index;
          _copied = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.cyanAccent : Colors.white54,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.cyanAccent : Colors.white,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.cyanAccent.withValues(alpha: 0.8)
                          : Colors.white38,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}