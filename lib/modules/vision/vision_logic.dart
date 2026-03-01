/// ============================================================
/// NeuroVision — Vision Logic
/// ============================================================
/// Handles camera, real-time object detection, scene awareness,
/// and blind navigation assistance.
///
/// Features:
///   • Real ML Kit object detection (on Android/iOS)
///   • Scene description & context awareness
///   • Continuous TTS narration for blind users
///   • Vibration feedback patterns
///   • Environment detection (home, road, outdoor, etc.)
///
/// Platform Support:
///   • Android/iOS: Real camera + ML Kit object detection
///   • Windows/Desktop: Camera preview + demo detection
///   • Web/Emulator: Demo mode only
/// ============================================================

import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:flutter/services.dart';

/// Detected object with its label, confidence, and bounding box
class DetectedObject {
  final String label;
  final double confidence;
  final Rect boundingBox;
  final DateTime timestamp;

  DetectedObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get displayLabel => label.isNotEmpty
      ? '${label[0].toUpperCase()}${label.substring(1)}'
      : 'Unknown';

  /// Estimated relative area of object in frame (0.0–1.0)
  /// Used to estimate distance: larger area = closer object
  double areaRatio(double frameW, double frameH) {
    if (boundingBox == Rect.zero || frameW <= 0 || frameH <= 0) return 0;
    return (boundingBox.width * boundingBox.height) / (frameW * frameH);
  }
}

/// Scene context based on detected objects
enum SceneContext {
  home,
  road,
  outdoor,
  indoor,
  unknown,
}

/// Spatial zone of screen (for navigation guidance)
enum ObjectZone { left, center, right, unknown }

/// How close an object is — estimated from bounding box size
enum ProximityZone {
  safe,     // >2.5m — silent, don't interrupt
  warning,  // ~2m   — mention once
  danger,   // ~1.5m — give direction
  critical, // <1m   — STOP command
}

/// Navigation guidance instruction
class NavGuidance {
  final String voice;          // Spoken direction
  final ObjectZone zone;       // Where the object is
  final bool isDanger;         // Is it a dangerous object?
  final String objectName;     // What was detected
  final ProximityZone proximity; // How close

  const NavGuidance({
    required this.voice,
    required this.zone,
    required this.isDanger,
    required this.objectName,
    this.proximity = ProximityZone.warning,
  });
}

class VisionLogic {
  // ── Camera ──
  CameraController? cameraController;
  List<CameraDescription> _cameras = [];
  bool _cameraInitialized = false;

  // ── Engine Selection ──
  bool _useYOLO = false; // Set to false to use ML Kit by default for reliability

  // ── ML Kit Object Detection & Labeling ──
  ObjectDetector? _objectDetector;
  ImageLabeler? _imageLabeler;
  bool _isDetecting = false;
  bool _detectionActive = false;

  // ── Stability filter: tracks consecutive hits per label ──
  final Map<String, int> _labelHitCount = {};
  static const int _stabilityFrames = 3; // Must appear N frames before announcing
  static const double _mlKitConfidence = 0.65; // Raised threshold
  static const double _labelerConfidence = 0.70;

  // ── YOLO Object Detection ──
  final FlutterVision _vision = FlutterVision();
  bool _yoloLoaded = false;

  // ── TTS ──
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  bool _isSpeaking = false;
  DateTime _lastAnnouncement = DateTime.now();
  DateTime _lastDangerAnnouncement = DateTime.now();
  DateTime _lastNavAnnouncement = DateTime.now();

  // ── Continuous narration mode ──
  bool _continuousMode = false;
  Timer? _narrationTimer;
  static const Duration _narrationInterval = Duration(seconds: 3);
  static const Duration _navInterval = Duration(seconds: 3);

  // ── Navigation mode ──
  bool _navigationGuidanceActive = false;
  NavGuidance? _lastGuidance;

  // ── Structural obstacle proximity tracking ──
  // Counts consecutive frames each structural label has been detected.
  // More frames = user is walking closer → escalates proximity zone.
  final Map<String, int> _structuralFrameCounts = {};
  static const int _structuralWarningFrames  = 4;  // ~2m: warn once
  static const int _structuralDangerFrames   = 10; // ~1.5m: give direction
  static const int _structuralCriticalFrames = 18; // <1m: STOP!

  // ── Detection state ──
  List<DetectedObject> _currentDetections = [];
  SceneContext _currentScene = SceneContext.unknown;
  String _sceneDescription = 'Initializing...';

  // ── Callbacks ──
  void Function(List<DetectedObject>)? onDetectionUpdate;
  void Function(String)? onSceneUpdate;
  void Function(NavGuidance)? onNavigationGuidance;

  // ── Getters ──
  bool get isCameraReady => _cameraInitialized;
  bool get isDetectionActive => _detectionActive;
  bool get isContinuousMode => _continuousMode;
  bool get isSpeaking => _isSpeaking;
  bool get useYOLO => _useYOLO;
  bool get yoloLoaded => _yoloLoaded;
  bool get isNavigationGuidanceActive => _navigationGuidanceActive;
  List<DetectedObject> get currentDetections => _currentDetections;
  SceneContext get currentScene => _currentScene;
  String get sceneDescription => _sceneDescription;
  NavGuidance? get lastGuidance => _lastGuidance;

  // ──────────────────────────────────
  // Camera Initialization
  // ──────────────────────────────────

  /// Tries to initialize the device camera.
  /// Returns true if camera is available and ready.
  Future<bool> initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        debugPrint('[VisionLogic] No cameras found on this device');
        return false;
      }

      // Prefer back camera on mobile
      CameraDescription selectedCamera = _cameras.first;
      for (final cam in _cameras) {
        if (cam.lensDirection == CameraLensDirection.back) {
          selectedCamera = cam;
          break;
        }
      }

      // Initialize camera controller
      cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await cameraController!.initialize();
      _cameraInitialized = true;

      debugPrint('[VisionLogic] Camera initialized: ${selectedCamera.name}');
      return true;
    } catch (e) {
      debugPrint('[VisionLogic] Camera init failed: $e');
      _cameraInitialized = false;
      return false;
    }
  }

  // ──────────────────────────────────
  // Detection Engine Initialization
  // ──────────────────────────────────

  /// Initializes the selected detection engine (YOLO or ML Kit)
  Future<void> initializeEngine() async {
    if (_useYOLO) {
      await initializeYOLO();
    } else {
      await initializeObjectDetector();
      await initializeImageLabeler();
    }
  }

  /// Initializes YOLO object detector
  Future<void> initializeYOLO() async {
    if (_yoloLoaded) return;
    try {
      // Note: User must place yolov8n.tflite in assets/models/
      // and labels.txt in assets/labels/
      await _vision.loadYoloModel(
        modelPath: 'assets/models/yolov8n.tflite',
        labels: 'assets/labels/labels.txt',
        modelVersion: "yolov8",
        numThreads: 2,
        useGpu: true,
      );
      _yoloLoaded = true;
      debugPrint('[VisionLogic] YOLO v8 Engine initialized');
    } catch (e) {
      debugPrint('[VisionLogic] YOLO init failed (fallback to ML Kit): $e');
      _useYOLO = false;
      await initializeObjectDetector();
    }
  }

  /// Initializes ML Kit object detector
  Future<void> initializeObjectDetector() async {
    try {
      final options = ObjectDetectorOptions(
        mode: DetectionMode.stream,
        classifyObjects: true,
        multipleObjects: true,
      );
      _objectDetector = ObjectDetector(options: options);
      debugPrint('[VisionLogic] ML Kit Object Detector initialized');
    } catch (e) {
      debugPrint('[VisionLogic] ML Kit init failed: $e');
      _objectDetector = null;
    }
  }

  /// Initializes ML Kit image labeler (for comprehensive object list)
  Future<void> initializeImageLabeler() async {
    try {
      final options = ImageLabelerOptions(confidenceThreshold: _labelerConfidence);
      _imageLabeler = ImageLabeler(options: options);
      debugPrint('[VisionLogic] ML Kit Image Labeler initialized');
    } catch (e) {
      debugPrint('[VisionLogic] Image Labeler init failed: $e');
      _imageLabeler = null;
    }
  }

  /// Starts real-time object detection from camera stream
  Future<void> startDetection() async {
    if (!_cameraInitialized || cameraController == null) {
      debugPrint('[VisionLogic] Cannot start detection: camera not ready');
      return;
    }

    if (_detectionActive) return;
    _detectionActive = true;

    // Initialize engine if needed
    await initializeEngine();

    try {
      await cameraController!.startImageStream(_processImage);
      debugPrint('[VisionLogic] Image stream started for detection');
    } catch (e) {
      debugPrint('[VisionLogic] Failed to start image stream: $e');
      _detectionActive = false;
    }
  }

  /// Stops real-time object detection
  Future<void> stopDetection() async {
    _detectionActive = false;
    try {
      if (cameraController?.value.isStreamingImages ?? false) {
        await cameraController?.stopImageStream();
      }
    } catch (e) {
      debugPrint('[VisionLogic] Failed to stop image stream: $e');
    }
  }

  int _frameCount = 0;

  /// Process a single camera frame for object detection
  Future<void> _processImage(CameraImage image) async {
    // Throttle: only process every 5th frame to reduce load
    _frameCount++;
    if (_frameCount % 5 != 0) return;

    if (_isDetecting || !_detectionActive) return;
    if (!_useYOLO && _objectDetector == null && _imageLabeler == null) return;
    _isDetecting = true;

    try {
      final detections = <DetectedObject>[];

      if (_useYOLO && _yoloLoaded) {
        // --- YOLO Inference path ---
        final result = await _vision.yoloOnFrame(
          bytesList: image.planes.map((p) => p.bytes).toList(),
          imageHeight: image.height,
          imageWidth: image.width,
          iouThreshold: 0.4,
          confThreshold: 0.4,
          classThreshold: 0.4,
        );

        for (final item in result) {
          detections.add(DetectedObject(
            label: item['tag'] ?? 'unknown',
            confidence: (item['box'][4] as num).toDouble(),
            boundingBox: Rect.fromLTWH(
              (item['box'][0] as num).toDouble(),
              (item['box'][1] as num).toDouble(),
              (item['box'][2] as num).toDouble() - (item['box'][0] as num).toDouble(),
              (item['box'][3] as num).toDouble() - (item['box'][1] as num).toDouble(),
            ),
          ));
        }
      } else if (_objectDetector != null || _imageLabeler != null) {
        // --- ML Kit Inference path ---
        final inputImage = _convertCameraImage(image);
        if (inputImage == null) {
          _isDetecting = false;
          return;
        }

        // 1. Run Object Detector (for boxes)
        if (_objectDetector != null) {
          final objects = await _objectDetector!.processImage(inputImage);
          for (final obj in objects) {
            for (final label in obj.labels) {
              // ── Higher confidence threshold to reduce false positives ──
              if (label.confidence >= _mlKitConfidence) {
                final key = label.text.toLowerCase();
                _labelHitCount[key] = (_labelHitCount[key] ?? 0) + 1;
                // ── Stability filter: only report after N consecutive frames ──
                if ((_labelHitCount[key] ?? 0) >= _stabilityFrames) {
                  detections.add(DetectedObject(
                    label: label.text,
                    confidence: label.confidence,
                    boundingBox: obj.boundingBox,
                  ));
                }
              }
            }
          }
        }

        // 2. Image Labeler — scene context ONLY, never for navigation
        // We deliberately exclude body parts, colors, textures — they are not obstacles
        const _navBlocklist = {
          'skin', 'face', 'hand', 'arm', 'leg', 'finger', 'thumb', 'nose',
          'eye', 'hair', 'neck', 'shoulder', 'ear', 'mouth', 'lip', 'cheek',
          'head', 'forehead', 'eyebrow', 'chin', 'palm', 'wrist', 'elbow',
          'blue', 'red', 'green', 'yellow', 'black', 'white', 'color', 'texture',
          'pattern', 'wood', 'metal', 'plastic', 'fabric', 'material', 'surface',
          'light', 'shadow', 'darkness', 'blur', 'close-up', 'macro',
          'organ', 'joint', 'limb', 'trunk', 'torso',
        };
        if (_imageLabeler != null) {
          final labels = await _imageLabeler!.processImage(inputImage);
          for (final label in labels) {
            final lowerLabel = label.label.toLowerCase();
            // Skip body parts, colors, textures — they're not navigation obstacles
            if (_navBlocklist.contains(lowerLabel)) continue;
            if (label.confidence >= _labelerConfidence) {
              if (!detections.any((d) => d.label.toLowerCase() == lowerLabel)) {
                detections.add(DetectedObject(
                  label: label.label,
                  confidence: label.confidence,
                  boundingBox: Rect.zero, // No spatial info from labeler
                ));
              }
            }
          }
        }

        // Decay hit counts for labels NOT seen this frame
        final seenKeys = detections.map((d) => d.label.toLowerCase()).toSet();
        final toDecay = _labelHitCount.keys
            .where((k) => !seenKeys.contains(k))
            .toList();
        for (final k in toDecay) {
          _labelHitCount[k] = (_labelHitCount[k]! - 1).clamp(0, _stabilityFrames + 1);
          if (_labelHitCount[k] == 0) _labelHitCount.remove(k);
        }
      }

      // Update state
      _currentDetections = detections;
      _analyzeScene(detections);
      onDetectionUpdate?.call(detections);

      final now = DateTime.now();

      // ── 1. SPATIAL NAVIGATION GUIDANCE ──
      if (_navigationGuidanceActive) {
        if (now.difference(_lastNavAnnouncement) > _navInterval) {
          _lastNavAnnouncement = now;

          // Step 1: Real objects from ObjectDetector (have bounding boxes)
          var navObjects = detections
              .where((d) => d.boundingBox != Rect.zero)
              .toList();

          // Step 2: If no bounding-box objects found, check ImageLabeler output.
          // Only synthesize obstacles for concrete structural things that block paths.
          if (navObjects.isEmpty) {
            final labelerHits = detections
                .where((d) => d.boundingBox == Rect.zero)
                .toList();

            if (labelerHits.isNotEmpty) {
              // Only REAL physical obstacles — absolutely NO roads, floors, or safe ground
              const blockingLabels = {
                'wall', 'door', 'stairs', 'staircase', 'step', 'steps',
                'fence', 'gate', 'pillar', 'column', 'pole', 'post',
                'glass', 'window', 'barrier', 'building',
                'tree', 'plant', 'bush', 'shrub', 'branch',
                'furniture', 'vehicle', 'person', 'people', 'human',
                'car', 'truck', 'bus', 'animal', 'dog', 'cat',
              };

              DetectedObject? obstacle;
              for (final d in labelerHits) {
                if (blockingLabels.contains(d.label.toLowerCase())) {
                  obstacle = d;
                  break;
                }
              }

              if (obstacle != null) {
                final fw = image.width.toDouble();
                final fh = image.height.toDouble();
                // Synthesize a large center bounding box
                navObjects = [
                  DetectedObject(
                    label: obstacle.label,
                    confidence: obstacle.confidence,
                    boundingBox: Rect.fromCenter(
                      center: Offset(fw / 2, fh / 2),
                      width: fw * 0.55,
                      height: fh * 0.45,
                    ),
                  ),
                ];
              }
            }
          }

          if (navObjects.isNotEmpty) {
            final guidance = _computeNavigationGuidance(
                navObjects, image.width.toDouble(), image.height.toDouble());
            if (guidance != null) {
              _lastGuidance = guidance;
              onNavigationGuidance?.call(guidance);
              speak(guidance.voice);
              _vibrateForZone(guidance.zone, guidance.isDanger);
            }
          } else {
            // Absolutely nothing detected — path is genuinely clear
            if (_lastSpokenGuidance != 'Path clear. Go straight.') {
              _lastSpokenGuidance = 'Path clear. Go straight.';
              speak('Path clear. Go straight.');
              onNavigationGuidance?.call(const NavGuidance(
                voice: 'Path clear. Go straight.',
                zone: ObjectZone.center,
                isDanger: false,
                objectName: '',
              ));
            }
          }
        }
      }


      // ── 2. URGENT SAFETY: danger objects always speak even without nav mode ──
      final dangerObjects = detections.where((d) =>
        ['car', 'truck', 'bus', 'motorcycle', 'bicycle']
            .contains(d.label.toLowerCase())
      ).toList();

      if (dangerObjects.isNotEmpty &&
          now.difference(_lastDangerAnnouncement) > const Duration(seconds: 4)) {
        _lastDangerAnnouncement = now;
        final name = dangerObjects.first.displayLabel;
        final zone = _getZone(dangerObjects.first, image.width.toDouble());
        final zoneWord = _zoneToWord(zone);
        if (!_navigationGuidanceActive) {
          // Only speak safety alert if nav guidance hasn't already spoken
          speak('Caution! $name on your $zoneWord.');
        }
        Vibration.vibrate(duration: 600);
      }

      // ── 3. Continuous mode narration (scene description) ──
      if (_continuousMode && detections.isNotEmpty && !_isSpeaking) {
        if (now.difference(_lastAnnouncement) > _narrationInterval) {
          _lastAnnouncement = now;
          _announceDetections(detections);
        }
      }
    } catch (e) {
      debugPrint('[VisionLogic] Detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  /// Manually dispose YOLO
  void _disposeYolo() {
    try {
      _vision.closeYoloModel();
    } catch (_) {}
  }

  /// Convert CameraImage to InputImage for ML Kit
  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final camera = cameraController!.description;

      final inputImageFormat = InputImageFormatValue.fromRawValue(
        image.format.raw as int,
      );
      if (inputImageFormat == null) return null;

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final imageRotation = _rotationFromSensorOrientation(camera);
      final bytesPerRow = image.planes.first.bytesPerRow;

      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: image.planes.first.bytes,
        metadata: metadata,
      );
    } catch (e) {
      debugPrint('[VisionLogic] Image conversion error: $e');
      return null;
    }
  }

  /// Maps camera sensor orientation to InputImageRotation
  InputImageRotation _rotationFromSensorOrientation(
      CameraDescription camera) {
    switch (camera.sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  // ──────────────────────────────────
  // Spatial Navigation Guidance
  // ──────────────────────────────────

  // Last spoken guidance text (to avoid repeating same sentence)
  String _lastSpokenGuidance = '';

  /// Enables or disables real-time spatial navigation guidance
  void setNavigationGuidance(bool enabled) {
    _navigationGuidanceActive = enabled;
    if (enabled) {
      _lastSpokenGuidance = '';
      speak('Navigation guidance on. I will tell you where to go.');
    } else {
      speak('Navigation guidance off.');
    }
  }

  /// Determines spatial zone of an object based on its bounding box center X
  ObjectZone _getZone(DetectedObject obj, double frameWidth) {
    if (obj.boundingBox == Rect.zero || frameWidth <= 0) return ObjectZone.unknown;
    final centerX = obj.boundingBox.left + obj.boundingBox.width / 2;
    final ratio = centerX / frameWidth;
    if (ratio < 0.35) return ObjectZone.left;
    if (ratio > 0.65) return ObjectZone.right;
    return ObjectZone.center;
  }

  /// Human-readable zone word
  String _zoneToWord(ObjectZone zone) {
    switch (zone) {
      case ObjectZone.left:    return 'left';
      case ObjectZone.right:   return 'right';
      case ObjectZone.center:  return 'center';
      case ObjectZone.unknown: return 'ahead';
    }
  }

  /// Vibration patterns per zone
  Future<void> _vibrateForZone(ObjectZone zone, bool isDanger) async {
    try {
      if (isDanger) {
        // Strong danger pulse
        await Vibration.vibrate(pattern: [0, 300, 100, 300, 100, 300]);
        return;
      }
      switch (zone) {
        case ObjectZone.left:
          // Single short left-side buzz
          await Vibration.vibrate(pattern: [0, 200, 80, 100]);
          break;
        case ObjectZone.right:
          // Double short right-side buzz
          await Vibration.vibrate(pattern: [0, 100, 80, 200]);
          break;
        case ObjectZone.center:
          // Long center warning
          await Vibration.vibrate(duration: 400);
          break;
        case ObjectZone.unknown:
          await Vibration.vibrate(duration: 150);
          break;
      }
    } catch (_) {}
  }

  /// Computes navigation guidance — simple, always speaks, no silent zones
  NavGuidance? _computeNavigationGuidance(
      List<DetectedObject> detections, double frameWidth, [double frameHeight = 640]) {
    final realObjects = detections.where((d) => d.boundingBox != Rect.zero).toList();
    if (realObjects.isEmpty) return null;

    final dangerLabels = {'car', 'truck', 'bus', 'motorcycle', 'bicycle', 'vehicle'};

    // Sort by confidence, prioritise danger objects
    final sorted = List<DetectedObject>.from(realObjects)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    DetectedObject? primary;
    bool isDanger = false;
    for (final obj in sorted) {
      if (dangerLabels.contains(obj.label.toLowerCase())) {
        primary = obj;
        isDanger = true;
        break;
      }
    }
    primary ??= sorted.first;
    isDanger = dangerLabels.contains(primary.label.toLowerCase());

    final zone  = _getZone(primary, frameWidth);
    final name  = primary.displayLabel;
    final area  = primary.areaRatio(frameWidth, frameHeight);

    // Is the user's direct walking path (CENTER zone) clear?
    final centerClear = !realObjects
        .map((d) => _getZone(d, frameWidth))
        .contains(ObjectZone.center);

    String voice;

    // ── STOP: object fills >25% of frame (very close, any zone) ──
    if (area > 0.25 || (isDanger && area > 0.10)) {
      voice = _pick(
          isDanger
            ? ['Stop! $name right in front!', 'Danger! Stop, $name is very close!']
            : zone == ObjectZone.left
                ? ['Stop! $name on your left, very close. Move right.']
                : zone == ObjectZone.right
                    ? ['Stop! $name on your right, very close. Move left.']
                    : ['Stop! $name right in front. Move aside.']);

    } else if (isDanger) {
      // ── DANGER object — always warn regardless of zone ──
      switch (zone) {
        case ObjectZone.left:
          voice = _pick(['Go right. $name on the left.', '$name on your left — move right.']);
          break;
        case ObjectZone.right:
          voice = _pick(['Go left. $name on the right.', '$name on your right — move left.']);
          break;
        case ObjectZone.center:
          final lc = !realObjects.map((d) => _getZone(d,frameWidth)).contains(ObjectZone.left);
          final rc = !realObjects.map((d) => _getZone(d,frameWidth)).contains(ObjectZone.right);
          voice = _pick(
              lc  ? ['Go left. $name is straight ahead.', 'Turn left, $name ahead.']
            : rc  ? ['Go right. $name is straight ahead.', 'Turn right, $name ahead.']
            : ['Stop. $name ahead. Back up slowly.']);
          break;
        default:
          voice = _pick(['$name nearby. Slow down.']);
      }

    } else if (zone == ObjectZone.center) {
      // ── Non-danger CENTER object — always block, give direction ──
      final lc = !realObjects.map((d) => _getZone(d,frameWidth)).contains(ObjectZone.left);
      final rc = !realObjects.map((d) => _getZone(d,frameWidth)).contains(ObjectZone.right);
      voice = _pick(
          (lc && rc) ? ['$name ahead. Go left or right.', 'Something in the way — pick a side.']
        : lc  ? ['Go left. $name is ahead.', '$name ahead — go left.']
        : rc  ? ['Go right. $name is ahead.', '$name ahead — go right.']
        : ['$name ahead. Path blocked. Slow down.']);

    } else {
      // ── Non-danger SIDE object (left or right) — CENTER path is clear ──
      // Don't redirect the user — just warn and let them continue forward.
      if (centerClear) {
        // Path ahead is free — just inform, don't reroute
        voice = _pick(
            zone == ObjectZone.left
              ? ['Path ahead is clear. $name on your left — keep going straight.', '$name on the left. Center path is free, go straight.']
              : ['Path ahead is clear. $name on your right — keep going straight.', '$name on the right. Center path is free, go straight.']);
      } else {
        // Center is also blocked
        voice = _pick(
            zone == ObjectZone.left
              ? ['$name on your left. Watch out.']
              : ['$name on your right. Watch out.']);
      }
    }

    // Don't repeat the exact same sentence twice in a row
    if (voice == _lastSpokenGuidance) return null;
    _lastSpokenGuidance = voice;

    return NavGuidance(
      voice: voice,
      zone: zone,
      isDanger: isDanger,
      objectName: name,
    );
  }

  /// Picks a random phrase from a list for natural-sounding speech
  String _pick(List<String> options) {
    if (options.length == 1) return options.first;
    return options[(DateTime.now().millisecondsSinceEpoch % options.length).toInt()];
  }

  // ──────────────────────────────────────────────────────
  // Navigation Test Scenarios (for verifying behaviour)
  // ──────────────────────────────────────────────────────

  /// Call this from the debug panel to test a specific nav scenario.
  /// [scenario]: 'wall', 'person_left', 'person_right', 'car_ahead',
  ///             'car_left', 'car_right', 'clear', 'blocked'
  void testNavScenario(String scenario) {
    // Frame dimensions used for synthetic bounding boxes
    const double fw = 640, fh = 480;

    List<DetectedObject> fakeObjects = [];

    switch (scenario) {
      case 'wall':
        // Large surface filling center — synthetic labeler hit as "Surface"
        fakeObjects = [
          DetectedObject(
            label: 'Surface',
            confidence: 0.95,
            boundingBox: Rect.fromCenter(
              center: const Offset(fw / 2, fh / 2),
              width: fw * 0.55, height: fh * 0.45,
            ),
          ),
        ];
        break;

      case 'person_left':
        fakeObjects = [
          DetectedObject(
            label: 'Person',
            confidence: 0.88,
            boundingBox: const Rect.fromLTWH(20, 80, 160, 300),  // left zone
          ),
        ];
        break;

      case 'person_right':
        fakeObjects = [
          DetectedObject(
            label: 'Person',
            confidence: 0.88,
            boundingBox: const Rect.fromLTWH(460, 80, 160, 300), // right zone
          ),
        ];
        break;

      case 'car_ahead':
        fakeObjects = [
          DetectedObject(
            label: 'Car',
            confidence: 0.92,
            boundingBox: const Rect.fromLTWH(200, 150, 240, 180), // center
          ),
        ];
        break;

      case 'car_left':
        fakeObjects = [
          DetectedObject(
            label: 'Car',
            confidence: 0.90,
            boundingBox: const Rect.fromLTWH(10, 100, 200, 200), // left
          ),
        ];
        break;

      case 'car_right':
        fakeObjects = [
          DetectedObject(
            label: 'Car',
            confidence: 0.90,
            boundingBox: const Rect.fromLTWH(430, 100, 200, 200), // right
          ),
        ];
        break;

      case 'blocked':
        // Objects on left, center, right — all blocked
        fakeObjects = [
          DetectedObject(label: 'Chair', confidence: 0.85,
              boundingBox: const Rect.fromLTWH(20, 100, 150, 200)),
          DetectedObject(label: 'Person', confidence: 0.88,
              boundingBox: const Rect.fromLTWH(220, 100, 200, 300)),
          DetectedObject(label: 'Table', confidence: 0.80,
              boundingBox: const Rect.fromLTWH(480, 100, 150, 200)),
        ];
        break;

      case 'tree_side':
        // Tree on LEFT side — path ahead (center) is CLEAR → should NOT say go right
        fakeObjects = [
          DetectedObject(label: 'Tree', confidence: 0.85,
              boundingBox: const Rect.fromLTWH(10, 60, 180, 300)), // left zone
        ];
        break;

      case 'cloth_side':
        // Cloth hanging on RIGHT — path ahead is CLEAR → should say "path clear, cloth on right"
        fakeObjects = [
          DetectedObject(label: 'Cloth', confidence: 0.80,
              boundingBox: const Rect.fromLTWH(460, 80, 160, 250)), // right zone
        ];
        break;

      case 'plant_ahead':
        // Plant in CENTER — SHOULD warn and give direction
        fakeObjects = [
          DetectedObject(label: 'Plant', confidence: 0.82,
              boundingBox: const Rect.fromLTWH(220, 120, 200, 250)), // center
        ];
        break;

      case 'person_ahead':
        // Person directly in CENTER path
        fakeObjects = [
          DetectedObject(label: 'Person', confidence: 0.91,
              boundingBox: const Rect.fromLTWH(200, 80, 240, 360)), // center
        ];
        break;

      case 'clear':
      default:
        fakeObjects = [];
        break;
    }


    _lastSpokenGuidance = ''; // reset so it always speaks during test

    if (fakeObjects.isEmpty) {
      speak('Path clear. Go straight.');
      onNavigationGuidance?.call(const NavGuidance(
        voice: 'Path clear. Go straight.',
        zone: ObjectZone.center,
        isDanger: false,
        objectName: '',
      ));
      return;
    }

    final guidance = _computeNavigationGuidance(fakeObjects, fw, fh);
    if (guidance != null) {
      onNavigationGuidance?.call(guidance);
      speak(guidance.voice);
      _vibrateForZone(guidance.zone, guidance.isDanger);
    }
  }

  // ──────────────────────────────────
  // Scene Analysis & Awareness
  // ──────────────────────────────────


  /// Analyzes detected objects to determine scene context
  void _analyzeScene(List<DetectedObject> detections) {
    final labels = detections.map((d) => d.label.toLowerCase()).toSet();

    // Determine scene based on detected objects
    SceneContext scene = SceneContext.unknown;
    String description = '';

    // Home indicators
    final homeObjects = {
      'couch', 'sofa', 'chair', 'table', 'television', 'tv', 'laptop',
      'remote', 'bed', 'refrigerator', 'microwave', 'oven', 'sink',
      'book', 'clock', 'vase', 'cup', 'bottle', 'bowl', 'fork',
      'knife', 'spoon', 'plate', 'glass', 'dining table', 'toaster',
      'potted plant', 'teddy bear', 'pillow',
    };

    // Road/outdoor indicators
    final roadObjects = {
      'car', 'truck', 'bus', 'motorcycle', 'bicycle', 'traffic light',
      'stop sign', 'parking meter', 'fire hydrant', 'bench',
      'dog', 'cat', 'bird', 'horse',
    };

    // Outdoor indicators
    final outdoorObjects = {
      'tree', 'person', 'bird', 'bench', 'dog', 'cat', 'umbrella',
      'kite', 'sports ball', 'frisbee', 'skateboard', 'surfboard',
    };

    int homeScore = labels.intersection(homeObjects).length;
    int roadScore = labels.intersection(roadObjects).length;
    int outdoorScore = labels.intersection(outdoorObjects).length;

    if (homeScore > roadScore && homeScore > outdoorScore) {
      scene = SceneContext.home;
    } else if (roadScore > homeScore && roadScore > outdoorScore) {
      scene = SceneContext.road;
    } else if (outdoorScore > 0) {
      scene = SceneContext.outdoor;
    } else if (detections.isNotEmpty) {
      scene = SceneContext.indoor;
    }

    // Build description
    if (detections.isEmpty) {
      description = 'No objects detected. Point the camera at your surroundings.';
    } else {
      final objectNames = detections
          .map((d) => d.displayLabel)
          .toSet()
          .take(5)
          .join(', ');

      switch (scene) {
        case SceneContext.home:
          description = 'You appear to be at home. I can see: $objectNames.';
          break;
        case SceneContext.road:
          description = 'You appear to be near a road. I can see: $objectNames. Please be careful!';
          break;
        case SceneContext.outdoor:
          description = 'You appear to be outdoors. I can see: $objectNames.';
          break;
        case SceneContext.indoor:
          description = 'You appear to be indoors. I can see: $objectNames.';
          break;
        case SceneContext.unknown:
          description = 'I can see: $objectNames.';
          break;
      }
    }

    _currentScene = scene;
    _sceneDescription = description;
    onSceneUpdate?.call(description);
  }

  // ──────────────────────────────────
  // TTS (Text-to-Speech)
  // ──────────────────────────────────

  /// Initializes TTS with accessible settings
  Future<void> initializeTTS() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.4);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _ttsReady = true;
      debugPrint('[VisionLogic] TTS initialized');
    } catch (e) {
      debugPrint('[VisionLogic] TTS init failed: $e');
      _ttsReady = false;
    }
  }

  /// Announces detected objects via TTS
  Future<void> _announceDetections(List<DetectedObject> detections) async {
    if (!_ttsReady) return;

    // Filter detections for safety
    final dangerObjects = detections.where((d) => 
      ['car', 'truck', 'bus', 'motorcycle', 'bicycle'].contains(d.label.toLowerCase())
    ).toList();

    String message = '';
    if (dangerObjects.isNotEmpty) {
      final name = dangerObjects.first.displayLabel;
      message = 'Caution! $name nearby. ';
    } else {
      // Don't interrupt if already speaking normal scene info
      if (_isSpeaking) return;
    }

    message += _sceneDescription;

    try {
      _isSpeaking = true;
      await _tts.speak(message);
    } catch (e) {
      debugPrint('[VisionLogic] TTS speak error: $e');
      _isSpeaking = false;
    }
  }

  /// Speaks specific text
  Future<void> speak(String text) async {
    if (!_ttsReady) return;
    try {
      await _tts.stop();
      _isSpeaking = true;
      // Safety timeout to reset _isSpeaking in case handler fails
      Timer(const Duration(seconds: 10), () => _isSpeaking = false);
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[VisionLogic] TTS speak error: $e');
      _isSpeaking = false;
    }
  }

  /// Stops TTS
  Future<void> stopSpeaking() async {
    if (!_ttsReady) return;
    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint('[VisionLogic] TTS stop error: $e');
    }
  }

  /// Announces a detected shape via TTS
  Future<void> announceShape(String shape) async {
    if (!_ttsReady) return;
    try {
      await _tts.speak('$shape detected');
    } catch (e) {
      debugPrint('[VisionLogic] TTS speak error: $e');
    }
  }

  // ──────────────────────────────────
  // Continuous Mode (Blind Assistance)
  // ──────────────────────────────────

  /// Toggle continuous narration mode for blind users
  void toggleContinuousMode() {
    _continuousMode = !_continuousMode;
    if (_continuousMode) {
      _narrationTimer = Timer.periodic(_narrationInterval, (_) {
        if (_currentDetections.isNotEmpty) {
          _announceDetections(_currentDetections);
        }
      });
      speak('Continuous mode activated. I will describe your surroundings.');
    } else {
      _narrationTimer?.cancel();
      _narrationTimer = null;
      speak('Continuous mode deactivated.');
    }
  }

  /// Describe current path with spatial directions
  Future<void> describeNavigation() async {
    if (_currentDetections.isEmpty) {
      await speak('Path looks clear. No objects detected ahead.');
      return;
    }
    // Use last known frame width approximation (640 typical)
    final guidance = _computeNavigationGuidance(_currentDetections, 640);
    if (guidance != null) {
      await speak(guidance.voice);
    } else {
      await speak('Unable to determine path. Please scan your surroundings.');
    }
  }

  /// Manually trigger scene description
  Future<void> describeScene() async {
    // Immediate haptic feedback
    Vibration.vibrate(duration: 100);
    
    if (_currentDetections.isEmpty) {
      if (_sceneDescription.isNotEmpty && _sceneDescription != 'No objects detected. Point the camera at your surroundings.') {
         await speak('Wait. Previously I saw: $_sceneDescription');
      } else {
         await speak('Nothing detected yet. Please pan the camera around.');
      }
    } else {
      await speak('I see: $_sceneDescription');
    }
  }

  // ──────────────────────────────────
  // Vibration Patterns
  // ──────────────────────────────────

  /// Triggers the vibration pattern for the given shape
  Future<void> triggerVibrationPattern(String shape) async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) return;

      switch (shape.toLowerCase()) {
        case 'circle':
          await Vibration.vibrate(pattern: [0, 150, 100, 150]);
          break;
        case 'square':
          await Vibration.vibrate(duration: 500);
          break;
        case 'triangle':
          await Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 100]);
          break;
        case 'person':
          await Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 200]);
          break;
        case 'car':
        case 'truck':
        case 'bus':
          // Danger pattern — long continuous vibration
          await Vibration.vibrate(duration: 1000);
          break;
        default:
          await Vibration.vibrate(duration: 200);
      }
    } catch (e) {
      debugPrint('[VisionLogic] Vibration error: $e');
    }
  }

  // ──────────────────────────────────
  // Detection Processing
  // ──────────────────────────────────

  static const double confidenceThreshold = 0.50;

  /// Processes a detection result
  Future<bool> processDetection({
    required String shape,
    required double confidence,
    required bool ttsEnabled,
    required bool vibrationEnabled,
  }) async {
    if (confidence < confidenceThreshold) return false;

    if (vibrationEnabled) {
      await triggerVibrationPattern(shape);
    }

    if (ttsEnabled) {
      await announceShape(shape);
    }

    return true;
  }

  /// Returns a human-readable description of the vibration pattern
  static String getPatternDescription(String shape) {
    switch (shape.toLowerCase()) {
      case 'circle':
        return '2 short pulses';
      case 'square':
        return '1 long vibration';
      case 'triangle':
        return '3 rapid bursts';
      case 'person':
        return '3 medium pulses';
      case 'car':
      case 'truck':
      case 'bus':
        return 'danger alert';
      default:
        return 'single buzz';
    }
  }

  /// Get scene context label
  static String getSceneLabel(SceneContext scene) {
    switch (scene) {
      case SceneContext.home:
        return '🏠 At Home';
      case SceneContext.road:
        return '🛣️ Near Road';
      case SceneContext.outdoor:
        return '🌳 Outdoor';
      case SceneContext.indoor:
        return '🏢 Indoor';
      case SceneContext.unknown:
        return '📍 Scanning...';
    }
  }

  // ──────────────────────────────────
  // Cleanup
  // ──────────────────────────────────

  void dispose() {
    stopDetection();
    _narrationTimer?.cancel();
    _objectDetector?.close();
    _imageLabeler?.close();
    _disposeYolo();
    cameraController?.dispose();
    _tts.stop();
    _cameraInitialized = false;
    _isSpeaking = false;
    _continuousMode = false;
    _navigationGuidanceActive = false;
  }
}
