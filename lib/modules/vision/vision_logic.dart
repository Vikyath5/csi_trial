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
}

/// Scene context based on detected objects
enum SceneContext {
  home,
  road,
  outdoor,
  indoor,
  unknown,
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

  // ── YOLO Object Detection ──
  final FlutterVision _vision = FlutterVision();
  bool _yoloLoaded = false;

  // ── TTS ──
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  bool _isSpeaking = false;
  DateTime _lastAnnouncement = DateTime.now();
  DateTime _lastDangerAnnouncement = DateTime.now();

  bool _continuousMode = false;
  Timer? _narrationTimer;
  static const Duration _narrationInterval = Duration(seconds: 4);

  // ── Navigation Mode ──
  bool _navigationMode = false;
  String _navInstruction = 'Path clear. Walk straight.';

  // ── Detection state ──
  List<DetectedObject> _currentDetections = [];
  SceneContext _currentScene = SceneContext.unknown;
  String _sceneDescription = 'Initializing...';

  // ── Callbacks ──
  void Function(List<DetectedObject>)? onDetectionUpdate;
  void Function(String)? onSceneUpdate;

  // ── Getters ──
  bool get isCameraReady => _cameraInitialized;
  bool get isDetectionActive => _detectionActive;
  bool get isContinuousMode => _continuousMode;
  bool get isNavigationMode => _navigationMode;
  bool get isSpeaking => _isSpeaking;
  bool get useYOLO => _useYOLO;
  bool get yoloLoaded => _yoloLoaded;
  List<DetectedObject> get currentDetections => _currentDetections;
  SceneContext get currentScene => _currentScene;
  String get sceneDescription => _sceneDescription;
  String get navInstruction => _navInstruction;

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

      // Initialize camera controller — medium for good ML Kit accuracy
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
      final options = ImageLabelerOptions(confidenceThreshold: 0.5);
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
    // Throttle: process every 4th frame — balance speed vs accuracy
    _frameCount++;
    if (_frameCount % 4 != 0) return;

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
              if (label.confidence >= 0.6) {
                detections.add(DetectedObject(
                  label: label.text,
                  confidence: label.confidence,
                  boundingBox: obj.boundingBox,
                ));
              }
            }
          }
        }

        // 2. Run Image Labeler ONLY if NOT in navigation mode
        // (labeler is slow and has no bounding boxes — useless for directions)
        if (_imageLabeler != null && !_navigationMode) {
          final labels = await _imageLabeler!.processImage(inputImage);
          for (final label in labels) {
            if (label.confidence >= 0.5) {
              if (!detections.any((d) => d.label.toLowerCase() == label.label.toLowerCase())) {
                detections.add(DetectedObject(
                  label: label.label,
                  confidence: label.confidence,
                  boundingBox: Rect.zero,
                ));
              }
            }
          }
        }
      }

      // Update state
      _currentDetections = detections;
      _analyzeScene(detections, image.width.toDouble(), image.height.toDouble());
      _calculateNavigation(detections, image.width.toDouble());
      onDetectionUpdate?.call(detections);

      // 1. URGENT SAFETY: Only warn about NEARBY danger objects (within ~8-10m)
      final double frameArea = image.width * image.height.toDouble();
      const double dangerMinArea = 0.05; // 5% of frame = within ~8-10m

      final dangerObjects = detections.where((d) {
        if (!['car', 'truck', 'bus', 'motorcycle', 'bicycle'].contains(d.label.toLowerCase())) return false;
        if (d.boundingBox == Rect.zero) return false;
        final boxArea = d.boundingBox.width * d.boundingBox.height;
        return (boxArea / frameArea) >= dangerMinArea;
      }).toList();

      final now = DateTime.now();
      if (dangerObjects.isNotEmpty && now.difference(_lastDangerAnnouncement) > const Duration(seconds: 2)) {
        _lastDangerAnnouncement = now;
        final box = dangerObjects.first.boundingBox;
        final name = dangerObjects.first.displayLabel;
        final cx = box.center.dx;
        final mid = image.width / 2.0;
        String dir = 'ahead';
        if (cx < mid - (image.width * 0.15)) dir = 'on your left';
        else if (cx > mid + (image.width * 0.15)) dir = 'on your right';

        if (_navigationMode) {
          speak('Caution! Moving obstacle $dir. Stop or change direction.');
        } else {
          speak('Caution! $name $dir.');
        }
        Vibration.vibrate(duration: 500);
      }

      // 2. Continuous mode narration
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
  // Scene Analysis & Awareness
  // ──────────────────────────────────

  /// Analyzes detected objects to determine scene context
  /// Only considers NEARBY objects (big bounding box) for accurate speech
  void _analyzeScene(List<DetectedObject> detections, double imgW, double imgH) {
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

    final roadObjects = {
      'car', 'truck', 'bus', 'motorcycle', 'bicycle', 'traffic light',
      'stop sign', 'parking meter', 'fire hydrant', 'bench',
      'dog', 'cat', 'bird', 'horse',
    };

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

    // Filter to only nearby objects for speech (big bounding boxes)
    final double frameArea = imgW * imgH;
    const double minArea = 0.02; // 2% of frame = within ~10m

    final nearbyDetections = detections.where((d) {
      if (d.boundingBox == Rect.zero) return true; // labeler results have no box, keep them
      return (d.boundingBox.width * d.boundingBox.height) / frameArea >= minArea;
    }).toList();

    // Build description using only nearby objects with direction
    if (nearbyDetections.isEmpty) {
      description = 'No nearby objects detected.';
    } else {
      final objectParts = <String>[];
      final seen = <String>{};
      for (final d in nearbyDetections) {
        final name = d.displayLabel;
        if (seen.contains(name.toLowerCase())) continue;
        seen.add(name.toLowerCase());
        if (d.boundingBox != Rect.zero) {
          objectParts.add('$name ${_getPosition(d.boundingBox, imgW)}');
        } else {
          objectParts.add(name);
        }
        if (objectParts.length >= 4) break; // Max 4 objects for clarity
      }
      final objectList = objectParts.join(', ');

      switch (scene) {
        case SceneContext.home:
          description = 'At home. $objectList.';
          break;
        case SceneContext.road:
          description = 'Near road. $objectList. Be careful!';
          break;
        case SceneContext.outdoor:
          description = 'Outdoors. $objectList.';
          break;
        case SceneContext.indoor:
          description = 'Indoors. $objectList.';
          break;
        case SceneContext.unknown:
          description = '$objectList.';
          break;
      }
    }

    _currentScene = scene;
    _sceneDescription = description;
    
    if (!_navigationMode) {
      onSceneUpdate?.call(description);
    }
  }

  /// Returns position string for an object based on its bounding box center
  String _getPosition(Rect box, double imageWidth) {
    final cx = box.center.dx;
    if (cx < imageWidth * 0.33) {
      return 'on your left';
    } else if (cx > imageWidth * 0.66) {
      return 'on your right';
    } else {
      return 'ahead';
    }
  }

  /// Advanced navigation: only considers NEARBY obstacles (approx 5-10m)
  /// Uses bounding box area as a proxy for distance:
  ///   Big box = close object → relevant for navigation
  ///   Small box = far object → ignore it
  void _calculateNavigation(List<DetectedObject> detections, double imageWidth) {
    if (detections.isEmpty) {
      _navInstruction = 'Path clear. Walk straight.';
      if (_navigationMode) onSceneUpdate?.call(_navInstruction);
      return;
    }

    // Only keep objects with bounding boxes
    final withBoxes = detections.where((d) => d.boundingBox != Rect.zero).toList();
    if (withBoxes.isEmpty) {
      _navInstruction = 'Path clear. Walk straight.';
      if (_navigationMode) onSceneUpdate?.call(_navInstruction);
      return;
    }

    // ── DISTANCE FILTER ──
    // Only consider objects within ~8-10 meters
    // Bounding box area >= 5% of frame means the object is close enough to matter
    final double frameArea = imageWidth * imageWidth;
    const double minAreaRatio = 0.05;

    final nearbyObstacles = withBoxes.where((obs) {
      final boxArea = obs.boundingBox.width * obs.boundingBox.height;
      return (boxArea / frameArea) >= minAreaRatio;
    }).toList();

    if (nearbyObstacles.isEmpty) {
      _navInstruction = 'Path clear. Walk straight.';
      if (_navigationMode) onSceneUpdate?.call(_navInstruction);
      return;
    }

    // ── ZONE CLASSIFICATION ──
    // Divide frame into 3 vertical zones: left / center / right
    final double leftBound = imageWidth * 0.33;
    final double rightBound = imageWidth * 0.66;

    bool leftBlocked = false;
    bool centerBlocked = false;
    bool rightBlocked = false;
    double closestArea = 0; // Tracks how close the nearest center obstacle is

    for (final obs in nearbyObstacles) {
      final cx = obs.boundingBox.center.dx;
      final areaRatio = (obs.boundingBox.width * obs.boundingBox.height) / frameArea;

      if (cx < leftBound) {
        leftBlocked = true;
      } else if (cx > rightBound) {
        rightBlocked = true;
      } else {
        centerBlocked = true;
        if (areaRatio > closestArea) closestArea = areaRatio;
      }
    }

    // ── BUILD DIRECTION ──
    if (!centerBlocked) {
      if (leftBlocked && rightBlocked) {
        _navInstruction = 'Obstacles on both sides. Walk straight carefully.';
      } else if (leftBlocked) {
        _navInstruction = 'Obstacle on your left. Keep right and walk straight.';
      } else if (rightBlocked) {
        _navInstruction = 'Obstacle on your right. Keep left and walk straight.';
      } else {
        _navInstruction = 'Path clear. Walk straight.';
      }
    } else {
      // Center is blocked — need to turn
      // closestArea > 0.10 means very close (within ~2-3m), else ~5-10m
      final String proximity = closestArea > 0.10 ? 'Very close' : 'Ahead';
      if (!leftBlocked && !rightBlocked) {
        _navInstruction = '$proximity obstacle ahead. Turn left or right.';
      } else if (!leftBlocked) {
        _navInstruction = '$proximity obstacle ahead and right. Turn left now.';
      } else if (!rightBlocked) {
        _navInstruction = '$proximity obstacle ahead and left. Turn right now.';
      } else {
        _navInstruction = 'Blocked in all directions. Stop. Turn around.';
      }
    }

    if (_navigationMode) onSceneUpdate?.call(_navInstruction);
  }

  // ──────────────────────────────────
  // TTS (Text-to-Speech)
  // ──────────────────────────────────

  /// Initializes TTS with accessible settings
  Future<void> initializeTTS() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.55); // Faster speech for quicker guidance
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

  /// Announces detected objects via TTS — speaks each object with its position
  Future<void> _announceDetections(List<DetectedObject> detections) async {
    if (!_ttsReady) return;

    // Stop any ongoing speech so we always announce latest info
    await _tts.stop();
    _isSpeaking = false;

    String message = '';

    if (_navigationMode) {
      // In nav mode just speak the direction
      message = _navInstruction;
    } else {
      // In normal mode, speak objects with positions
      // Use the already-built scene description which now has positions
      message = _sceneDescription;
    }

    if (message.trim().isEmpty) return;

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
      // Start periodic narration
      _narrationTimer = Timer.periodic(_narrationInterval, (_) {
        if (_currentDetections.isNotEmpty) {
          _announceDetections(_currentDetections);
        }
      });
      // Announce that continuous mode is on
      speak('Continuous mode activated. I will describe your surroundings.');
    } else {
      _narrationTimer?.cancel();
      _narrationTimer = null;
      speak('Continuous mode deactivated.');
    }
  }

  /// Toggle navigation mode for blind users
  void toggleNavigationMode() {
    _navigationMode = !_navigationMode;
    if (_navigationMode) {
      speak('Navigation mode activated. Providing directional guidance.');
      onSceneUpdate?.call(_navInstruction);
    } else {
      speak('Navigation mode deactivated.');
      onSceneUpdate?.call(_sceneDescription);
    }
  }

  /// Manually trigger scene description
  Future<void> describeScene() async {
    // Immediate haptic feedback
    Vibration.vibrate(duration: 100);
    
    if (_navigationMode) {
      await speak(_navInstruction);
      return;
    }

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
    _navigationMode = false;
  }
}
