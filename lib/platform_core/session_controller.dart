/// ============================================================
/// NeuroVision — Session Controller
/// ============================================================
/// Central state management for the platform.
/// Manages active module, user preferences, and progress.
/// ============================================================

import 'package:flutter/material.dart';
import '../shared/accessibility/accessibility_prefs.dart';
import '../shared/models/progress_model.dart';

/// Which module the user is currently using
enum ActiveModule { dashboard, learning, vision }

/// Global signals for voice assistant and gestures
enum GlobalCommand { describe, toggleContinuous, openMap }

class SessionController extends ChangeNotifier {
  // ── Pending Command Signaling ──
  GlobalCommand? _pendingCommand;
  GlobalCommand? get pendingCommand => _pendingCommand;

  void triggerCommand(GlobalCommand cmd) {
    _pendingCommand = cmd;
    notifyListeners();
  }

  void clearCommand() {
    _pendingCommand = null;
    notifyListeners();
  }
  // ── User Info ──
  String? userId;
  String displayName = 'Learner';

  // ── Active Module ──
  ActiveModule _activeModule = ActiveModule.dashboard;
  ActiveModule get activeModule => _activeModule;

  // ── Accessibility Preferences ──
  AccessibilityPrefs _prefs = const AccessibilityPrefs();
  AccessibilityPrefs get prefs => _prefs;

  // ── Progress Tracking ──
  ProgressModel _progress = const ProgressModel();
  ProgressModel get progress => _progress;

  // ── Navigation Guidance State ──
  String? _navigationDestination;
  String? get navigationDestination => _navigationDestination;

  void setNavigationDestination(String? dest) {
    _navigationDestination = dest;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────

  /// Navigate to a specific module
  void navigateTo(ActiveModule module) {
    _activeModule = module;
    notifyListeners();
  }

  /// Go back to the dashboard
  void goToDashboard() {
    _activeModule = ActiveModule.dashboard;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Accessibility
  // ─────────────────────────────────────────────

  /// Update font scale
  void setFontScale(double scale) {
    _prefs = _prefs.copyWith(fontScale: scale);
    notifyListeners();
  }

  /// Toggle vibration feedback
  void toggleVibration() {
    _prefs = _prefs.copyWith(vibrationEnabled: !_prefs.vibrationEnabled);
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Progress
  // ─────────────────────────────────────────────

  /// Record a completed learning block
  void completeBlock() {
    final newStreak = _progress.focusStreak + 1;
    final newBest =
        newStreak > _progress.bestStreak ? newStreak : _progress.bestStreak;

    // Award badges at milestones
    final badges = List<String>.from(_progress.badges);
    if (_progress.blocksCompleted + 1 == 5 && !badges.contains('first_five')) {
      badges.add('first_five');
    }
    if (_progress.blocksCompleted + 1 == 25 &&
        !badges.contains('quarter_century')) {
      badges.add('quarter_century');
    }
    if (newStreak >= 10 && !badges.contains('streak_master')) {
      badges.add('streak_master');
    }

    _progress = _progress.copyWith(
      blocksCompleted: _progress.blocksCompleted + 1,
      focusStreak: newStreak,
      bestStreak: newBest,
      badges: badges,
    );
    notifyListeners();
  }

  /// Break the focus streak (user was distracted / left)
  void breakStreak() {
    _progress = _progress.copyWith(focusStreak: 0);
    notifyListeners();
  }

  /// Record object detection in vision mode
  void recordDetection() {
    _progress = _progress.copyWith(
      objectsDetected: _progress.objectsDetected + 1,
    );
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Mock session (for local dev)
  // ─────────────────────────────────────────────

  /// Loads a mock session for development
  void loadMockSession() {
    userId = 'demo_user_001';
    displayName = 'Demo Learner';
    _prefs = const AccessibilityPrefs(
      fontScale: 1.0,
      vibrationEnabled: true,
      highContrast: true,
    );
    _progress = const ProgressModel();
    _activeModule = ActiveModule.dashboard;
    notifyListeners();
  }
}
