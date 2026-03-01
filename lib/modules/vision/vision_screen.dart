/// ============================================================
/// NeuroVision — Vision Screen
/// ============================================================
/// Module 2: Vision Mode (Blind / Visually Impaired Support)
/// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import '../../platform_core/session_controller.dart';
import '../../shared/accessibility/accessibility_theme.dart';
import 'vision_logic.dart';
import '../../shared/voice/voice_command_service.dart';

class VisionScreen extends StatefulWidget {
  const VisionScreen({super.key});

  @override
  State<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends State<VisionScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final VisionLogic _logic = VisionLogic();
  final VoiceCommandService _voice = VoiceCommandService();

  // ── State ──
  String? _lastDetectedLabel;
  double _lastConfidence = 0.0;
  bool _cameraAvailable = false;
  bool _cameraLoading = false;
  bool _detectionRunning = false;
  List<DetectedObject> _detections = [];
  bool _isSpeaking = false;
  bool _isMapMode = false;
  // ── Controls ──
  bool _ttsEnabled = true;
  bool _continuousMode = false;

  // ── Navigation Guidance ──
  Timer? _navigationTimer;
  bool _navGuidanceActive = false;
  NavGuidance? _currentGuidance;
  int _directionIndex = 0;
  final List<String> _directionPrompts = [
    'Continue straight for 50 meters.',
    'Slight left in 20 meters, carefully scan for obstacles.',
    'Turn right onto the main walkway.',
    'Destination is on your left in 10 meters.',
    'You have arrived at your destination.'
  ];

  // ── Scene info ──
  String _sceneDescription = 'System Ready. Tap Enable Camera.';
  String _sceneLabel = '📍 Idle';
  int _objectCount = 0; // Keeping it but I'll make sure it's used or commented

  // ── Detection history ──
  final List<_DetectionEvent> _detectionHistory = [];

  // ── Debug overlay ──
  bool _showDebug = true; // ON by default so we can verify
  String _debugInfo = 'Waiting for detections...';

  // ── Animation ──
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize Animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize System
    _initSystem();

    // Register Session Listener
    context.read<SessionController>().addListener(_onSessionUpdate);

    // Announce entry for screen readers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logic.speak('Vision Mode. Double tap for Voice Assistant. Triple tap to toggle Talking Guide.');
    });

    // Check for pending commands immediately (fixes the race condition)
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSessionUpdate());

    // Setup Callbacks
    _logic.onDetectionUpdate = (detections) {
      if (!mounted) return;

      // ── Build debug info string ──
      final labels = detections.map((d) {
        final box = d.boundingBox != Rect.zero ? '[BOX]' : '[LABEL]';
        return '$box ${d.displayLabel} ${(d.confidence * 100).toStringAsFixed(0)}%';
      }).join('\n');
      final debugStr = detections.isEmpty
          ? 'NO DETECTIONS'
          : labels;

      final session = context.read<SessionController>();
      if (session.navigationDestination != null && !_isMapMode) {
        _startNavigation(session.navigationDestination!);
      }

      setState(() {
        _debugInfo = debugStr;
        _objectCount = detections.length;
        _detections = detections;
        if (detections.isNotEmpty) {
          final best = detections.reduce(
              (a, b) => a.confidence > b.confidence ? a : b);
          _lastDetectedLabel = best.displayLabel;
          _lastConfidence = best.confidence;

          if (_detectionHistory.isEmpty ||
              _detectionHistory.first.shape != best.displayLabel ||
              DateTime.now().difference(_detectionHistory.first.time).inSeconds > 1) {
            _detectionHistory.insert(0, _DetectionEvent(
              shape: best.displayLabel,
              confidence: best.confidence,
              time: DateTime.now(),
            ));
            if (_detectionHistory.length > 30) _detectionHistory.removeLast();
            context.read<SessionController>().recordDetection();
          }
        }
      });
    };

    // Navigation guidance callback ─ updates directional overlay
    _logic.onNavigationGuidance = (guidance) {
      if (!mounted) return;
      setState(() => _currentGuidance = guidance);
    };

    // Track speech state for visual feedback
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isSpeaking != _logic.isSpeaking) {
        setState(() => _isSpeaking = _logic.isSpeaking);
      }
    });

    _logic.onSceneUpdate = (description) {
      if (!mounted) return;
      setState(() {
        _sceneDescription = description;
        _sceneLabel = VisionLogic.getSceneLabel(_logic.currentScene);
      });
    };

    // Auto-start Vision system
    _initCamera().then((_) {
      _startDetection();
      // Check if we arrived here because of a navigation command
      final session = context.read<SessionController>();
      if (session.navigationDestination != null) {
        _startNavigation(session.navigationDestination!);
      }
    });
  }

  Future<void> _initSystem() async {
    try {
      await _logic.initializeTTS();
    } catch (e) {
      debugPrint('TTS Init Error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      context.read<SessionController>().removeListener(_onSessionUpdate);
    } catch (_) {}
    _navigationTimer?.cancel();
    _logic.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onSessionUpdate() {
    if (!mounted) return;
    final session = context.read<SessionController>();
    if (session.pendingCommand != null) {
      final cmd = session.pendingCommand!;
      // We use a microtask to clear and execute to avoid build-time listener conflicts
      Future.microtask(() {
        if (!mounted) return;
        session.clearCommand();
        switch (cmd) {
          case GlobalCommand.describe:
            _logic.describeScene();
            break;
          case GlobalCommand.toggleContinuous:
            _toggleContinuousMode();
            break;
          case GlobalCommand.openMap:
            if (session.navigationDestination != null) {
              _launchMap(session.navigationDestination!);
            }
            break;
          case GlobalCommand.toggleNavigation:
            _toggleNavGuidance();
            break;
        }
      });
    }
  }

  void _startNavigation(String destination) {
    setState(() {
      _isMapMode = true;
      _directionIndex = 0;
    });
    
    _logic.speak('Navigation started to $destination. I will guide you with directions and safety alerts.');
    
    _navigationTimer?.cancel();
    _navigationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_directionIndex < _directionPrompts.length) {
        _logic.speak(_directionPrompts[_directionIndex]);
        _directionIndex++;
      } else {
        _stopNavigation();
      }
    });
  }

  void _stopNavigation() {
    _navigationTimer?.cancel();
    _navigationTimer = null;
    setState(() {
      _isMapMode = false;
    });
    context.read<SessionController>().setNavigationDestination(null);
    _logic.speak('You have reached the end of the guided path.');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _stopDetection();
    }
  }

  Future<void> _initCamera() async {
    setState(() => _cameraLoading = true);
    try {
      final available = await _logic.initializeCamera();
      if (mounted) {
        setState(() {
          _cameraAvailable = available;
          _cameraLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraAvailable = false;
          _cameraLoading = false;
        });
      }
    }
  }

  Future<void> _startDetection() async {
    try {
      await _logic.initializeEngine();
      await _logic.startDetection();
      if (mounted) setState(() => _detectionRunning = true);
    } catch (e) {
      if (mounted) setState(() => _detectionRunning = false);
    }
  }

  Future<void> _stopDetection() async {
    try {
      await _logic.stopDetection();
    } catch (_) {}
    if (mounted) setState(() => _detectionRunning = false);
  }

  void _toggleDetection() {
    if (_detectionRunning) {
      _stopDetection();
    } else {
      _startDetection();
    }
  }

  void _toggleContinuousMode() {
    _logic.toggleContinuousMode();
    setState(() => _continuousMode = _logic.isContinuousMode);
  }

  void _toggleNavGuidance() {
    final newState = !_navGuidanceActive;
    _logic.setNavigationGuidance(newState);
    setState(() {
      _navGuidanceActive = newState;
      if (!newState) _currentGuidance = null;
    });
  }

  void _simulateDetection(String label) async {
    final session = context.read<SessionController>();
    setState(() {
      _lastDetectedLabel = label;
      _lastConfidence = 0.95;
      _detectionHistory.insert(0, _DetectionEvent(shape: label, confidence: 0.95, time: DateTime.now()));
    });
    await _logic.processDetection(shape: label, confidence: 0.95, ttsEnabled: _ttsEnabled, vibrationEnabled: session.prefs.vibrationEnabled);
    session.recordDetection();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black, // Ensure pure black for blind users
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () async {
            _logic.speak('Describing surroundings.');
            await Vibration.vibrate(duration: 100);
            // If nav guidance is active, describe navigation direction
            if (_navGuidanceActive) {
              _logic.describeNavigation();
            } else {
              _logic.describeScene();
            }
          },
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              // Right Swipe (Progress backward) -> Dashboard per user request
              if (details.primaryVelocity! > 100) {
                _logic.speak('Returning to main menu');
                session.goToDashboard();
                Vibration.vibrate(duration: 200);
              } else if (details.primaryVelocity! < -100) {
                // Left Swipe -> Mode internal toggle if needed, or ignore
                _logic.speak('Mode locked. Swipe right to go back.');
              }
            }
          },
          child: Column(
            children: [
              _buildLinearStatusBanner(theme),
              Expanded(flex: 3, child: _buildCameraArea(theme)),
              if (_navGuidanceActive && _currentGuidance != null)
                _buildDirectionBanner(_currentGuidance!),
              // ── LIVE DEBUG PANEL ──
              if (_showDebug) _buildDebugPanel(),
              _buildToggles(theme, session),
              const SizedBox(height: NVDimensions.spacingM),
            ],
          ),

        ),
      ),
    );
  }



  Future<void> _launchMap(String destination) async {
    final query = Uri.encodeComponent(destination);
    
    // 1. Try Native Google Maps Navigation
    final navUri = Uri.parse('google.navigation:q=$query&mode=d');
    // 2. Try Generic Google Maps DIR (works on iOS and mobile browsers)
    final dirUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$query&travelmode=walking');
    
    try {
      if (await canLaunchUrl(navUri)) {
        debugPrint('Launching Native Navigation');
        await launchUrl(navUri, mode: LaunchMode.externalNonBrowserApplication);
      } else if (await canLaunchUrl(dirUri)) {
        debugPrint('Launching Web/Generic Directions');
        await launchUrl(dirUri, mode: LaunchMode.externalApplication);
      } else {
        _logic.speak('Could not launch maps. Please check your internet connection.');
      }
    } catch (e) {
      debugPrint('Map Launch Error: $e');
      // Final fallback
       await launchUrl(dirUri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildLinearStatusBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(NVDimensions.spacingM),
      padding: const EdgeInsets.all(NVDimensions.spacingM),
      decoration: BoxDecoration(
        color: _isMapMode ? NVColors.primaryBlue.withOpacity(0.1) : NVColors.surfaceElevated,
        borderRadius: BorderRadius.circular(NVDimensions.radiusM),
        border: Border.all(color: _isMapMode ? NVColors.primaryBlue : NVColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(
            _isMapMode ? Icons.map_rounded : Icons.explore_rounded, 
            color: _isMapMode ? NVColors.primaryBlue : NVColors.visionAccent
          ),
          const SizedBox(width: NVDimensions.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isMapMode ? 'MAP MODE' : _sceneLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isMapMode ? NVColors.primaryBlue : NVColors.visionAccent
                  )
                ),
                Text(
                  _isMapMode || _logic.isNavigationGuidanceActive ? 'Navigating route' : '$_sceneDescription ($_objectCount items)',
                  style: theme.textTheme.bodySmall?.copyWith(color: NVColors.textSecondary)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraArea(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: NVDimensions.spacingM),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(NVDimensions.radiusL),
        border: Border.all(
          color: _isMapMode ? NVColors.primaryBlue : NVColors.cardBorder,
          width: 2.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraContent(theme),
          if (_detections.isNotEmpty)
            CustomPaint(
              painter: ObjectPainter(
                detections: _detections,
                previewSize: const Size(300, 400), // Approximate aspect ratio
              ),
            ),
          // Visual Speaking indicator for judge
          if (_isSpeaking)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: NVColors.primaryPurple.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.record_voice_over, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text('SPEAKING...', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ────────────────────────────────
  // Live Debug Panel
  // ────────────────────────────────
  Widget _buildDebugPanel() {
    return GestureDetector(
      onTap: () => setState(() => _showDebug = false),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.greenAccent, size: 14),
                const SizedBox(width: 6),
                const Text('ML KIT OUTPUT  (tap here to hide)',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_detections.length} items',
                    style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
            const Divider(color: Colors.white24, height: 8),
            // Raw detection list
            Text(
              _debugInfo,
              style: const TextStyle(
                color: Colors.white, fontSize: 11,
                fontFamily: 'monospace', height: 1.6,
              ),
            ),
            // Current guidance
            if (_currentGuidance != null) ...[
              const Divider(color: Colors.white24, height: 8),
              Text(
                '🗣 ${_currentGuidance!.voice}',
                style: const TextStyle(color: Colors.yellowAccent,
                    fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
            const Divider(color: Colors.white24, height: 8),
            // ── TEST SCENARIO BUTTONS ──
            const Text('TAP TO TEST NAVIGATION:',
                style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _testBtn('🧱 Wall',        'wall',         Colors.orange),
                _testBtn('🚶 Left',        'person_left',  Colors.blue),
                _testBtn('🚶 Right',       'person_right', Colors.blue),
                _testBtn('� Ahead',       'person_ahead', Colors.blue),
                _testBtn('�🚗 Car Ahead',   'car_ahead',    Colors.red),
                _testBtn('🌳 Tree Side',   'tree_side',    Colors.green),
                _testBtn('🪴 Plant Ahead',  'plant_ahead',  Colors.green),
                _testBtn('� Cloth Side',  'cloth_side',   Colors.purple),
                _testBtn('🚧 Blocked',     'blocked',      Colors.purple),
                _testBtn('✅ Clear',       'clear',        Colors.tealAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _testBtn(String label, String scenario, Color color) {
    return GestureDetector(
      onTap: () {
        _logic.testNavScenario(scenario);
        // Force show guidance state update
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showDebug = true);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 1),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildCameraContent(ThemeData theme) {
    if (_cameraLoading) return const Center(child: CircularProgressIndicator(color: NVColors.visionAccent));
    if (_cameraAvailable && _logic.cameraController != null && _logic.cameraController!.value.isInitialized) {
      return CameraPreview(_logic.cameraController!);
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off_rounded, size: 64, color: NVColors.textMuted),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _initCamera,
            icon: const Icon(Icons.videocam_rounded),
            label: const Text('Enable Camera'),
            style: ElevatedButton.styleFrom(backgroundColor: NVColors.visionAccent, foregroundColor: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text('Tap to start camera system', style: TextStyle(color: NVColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  // ────────────────────────────────
  // Direction Banner (Nav Guidance UI)
  // ────────────────────────────────

  Widget _buildDirectionBanner(NavGuidance guidance) {
    final isDanger = guidance.isDanger;
    final Color baseColor = isDanger ? Colors.red : _zoneColor(guidance.zone);
    final IconData arrowIcon = _zoneArrow(guidance.zone);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(isDanger ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: baseColor, width: isDanger ? 2.5 : 1.5),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: isDanger ? 2 : 0,
          )
        ],
      ),
      child: Row(
        children: [
          // Zone indicator – three zone slots
          _buildZoneIndicator(guidance.zone, isDanger),
          const SizedBox(width: 12),
          // Arrow icon
          Icon(arrowIcon, color: baseColor, size: 36),
          const SizedBox(width: 12),
          // Guidance text
          Expanded(
            child: Text(
              guidance.voice,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: isDanger ? FontWeight.bold : FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneIndicator(ObjectZone zone, bool isDanger) {
    Color active = isDanger ? Colors.red : Colors.greenAccent;
    Color inactive = Colors.white12;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _zoneBox(zone == ObjectZone.left ? active : inactive),
        const SizedBox(width: 3),
        _zoneBox(zone == ObjectZone.center ? active : inactive, tall: true),
        const SizedBox(width: 3),
        _zoneBox(zone == ObjectZone.right ? active : inactive),
      ],
    );
  }

  Widget _zoneBox(Color color, {bool tall = false}) =>
      Container(
        width: 10,
        height: tall ? 32 : 24,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      );

  Color _zoneColor(ObjectZone zone) {
    switch (zone) {
      case ObjectZone.left:    return Colors.orange;
      case ObjectZone.right:   return Colors.blue;
      case ObjectZone.center:  return Colors.amber;
      case ObjectZone.unknown: return Colors.tealAccent;
    }
  }

  IconData _zoneArrow(ObjectZone zone) {
    switch (zone) {
      case ObjectZone.left:    return Icons.arrow_back_rounded;
      case ObjectZone.right:   return Icons.arrow_forward_rounded;
      case ObjectZone.center:  return Icons.arrow_upward_rounded;
      case ObjectZone.unknown: return Icons.explore_rounded;
    }
  }

  Widget _buildDetectionBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: NVDimensions.spacingM, vertical: 4),
      padding: const EdgeInsets.all(NVDimensions.spacingM),
      decoration: BoxDecoration(
        color: NVColors.visionAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(NVDimensions.radiusS),
      ),
      child: Text(
        'Detected: ${_lastDetectedLabel?.toUpperCase()} - ${(_lastConfidence * 100).round()}%',
        style: const TextStyle(color: NVColors.visionAccent, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMainControls(ThemeData theme, SessionController session) {
    return Padding(
      padding: const EdgeInsets.all(NVDimensions.spacingM),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Describe surroundings. Analyzes the current camera view and speaks what I see.',
              child: ElevatedButton.icon(
                onPressed: () => _logic.describeScene(), 
                icon: const Icon(Icons.spatial_audio_off),
                label: const Text('Describe Surroundings'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoButtons(ThemeData theme) {
    return Column(
      children: [
        const Text('Demo Objects', style: TextStyle(color: NVColors.textMuted, fontSize: 11)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: NVDimensions.spacingM, vertical: 8),
          child: Row(
            children: ['Person', 'Car', 'Chair', 'Table', 'Dog', 'Bottle'].map((label) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(label), 
                onPressed: () => _simulateDetection(label),
                backgroundColor: NVColors.surfaceElevated,
                labelStyle: const TextStyle(color: NVColors.textSecondary),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildToggles(ThemeData theme, SessionController session) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NVDimensions.spacingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToggle(
            icon: _ttsEnabled ? Icons.volume_up : Icons.volume_off,
            label: 'Audio',
            isActive: _ttsEnabled,
            onTap: () => setState(() => _ttsEnabled = !_ttsEnabled),
          ),
          _buildToggle(
            icon: session.prefs.vibrationEnabled ? Icons.vibration : Icons.smartphone,
            label: 'Haptic',
            isActive: session.prefs.vibrationEnabled,
            onTap: () => session.toggleVibration(),
          ),
          _buildToggle(
            icon: _continuousMode ? Icons.record_voice_over : Icons.voice_over_off,
            label: 'Guide',
            isActive: _continuousMode,
            onTap: _toggleContinuousMode,
          ),
          _buildToggle(
            icon: _navGuidanceActive ? Icons.navigation : Icons.navigation_outlined,
            label: 'Navigate',
            isActive: _navGuidanceActive,
            onTap: _toggleNavGuidance,
          ),
        ],
      ),
    );
  }

  Widget _buildToggle({required IconData icon, required String label, required bool isActive, required VoidCallback onTap}) {
    final color = isActive ? NVColors.visionAccent : NVColors.textMuted;
    final stateLabel = isActive ? 'Enabled' : 'Disabled';
    
    return Semantics(
      button: true,
      label: '$label toggle. Currently $stateLabel. Double tap to change.',
      child: Column(
        children: [
          IconButton(icon: Icon(icon, color: color), onPressed: onTap),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildHistory(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(NVDimensions.spacingM),
      decoration: BoxDecoration(
        color: NVColors.surface,
        borderRadius: BorderRadius.circular(NVDimensions.radiusM),
        border: Border.all(color: NVColors.cardBorder),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _detectionHistory.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) => ListTile(
          dense: true,
          title: Text(_detectionHistory[index].shape, style: const TextStyle(color: NVColors.textPrimary)),
          trailing: Text('${(_detectionHistory[index].confidence * 100).round()}%', style: const TextStyle(color: NVColors.visionAccent)),
        ),
      ),
    );
  }
}

class _DetectionEvent {
  final String shape;
  final double confidence;
  final DateTime time;
  _DetectionEvent({required this.shape, required this.confidence, required this.time});
}

/// A high-contrast painter to draw AI bounding boxes for judges
class ObjectPainter extends CustomPainter {
  final List<DetectedObject> detections;
  final Size previewSize;

  ObjectPainter({required this.detections, required this.previewSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = NVColors.visionAccent;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final obj in detections) {
      if (obj.boundingBox == Rect.zero) continue;

      // Scale coordinates to fitting size
      // Real coordinates come from camera res, we scale to UI widget size
      final rect = Rect.fromLTWH(
        obj.boundingBox.left * (size.width / previewSize.width),
        obj.boundingBox.top * (size.height / previewSize.height),
        obj.boundingBox.width * (size.width / previewSize.width),
        obj.boundingBox.height * (size.height / previewSize.height),
      );

      // Draw modern corner-style bounding box
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        paint,
      );

      // Draw label background
      final bgPaint = Paint()..color = NVColors.visionAccent.withOpacity(0.8);
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          rect.left,
          rect.top - 25,
          rect.left + 80,
          rect.top,
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        bgPaint,
      );

      // Draw text
      textPainter.text = TextSpan(
        text: obj.displayLabel,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(rect.left + 5, rect.top - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
