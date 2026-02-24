/// ============================================================
/// NeuroVision — Accessibility Preferences
/// ============================================================
/// Stores the user's accessibility configuration.
/// Persisted locally (and synced to Supabase by backend team).
/// ============================================================

class AccessibilityPrefs {
  /// Font scale factor (1.0 = default, 1.5 = 50% larger, etc.)
  final double fontScale;

  /// Whether haptic/vibration feedback is turned on
  final bool vibrationEnabled;

  /// Whether high-contrast mode is active
  final bool highContrast;

  /// Extra word spacing for dyslexia support (in logical pixels)
  final double wordSpacing;

  /// Extra letter spacing for dyslexia support
  final double letterSpacing;

  const AccessibilityPrefs({
    this.fontScale = 1.0,
    this.vibrationEnabled = true,
    this.highContrast = true,
    this.wordSpacing = 2.0,
    this.letterSpacing = 0.3,
  });

  /// Creates a copy with overridden values
  AccessibilityPrefs copyWith({
    double? fontScale,
    bool? vibrationEnabled,
    bool? highContrast,
    double? wordSpacing,
    double? letterSpacing,
  }) {
    return AccessibilityPrefs(
      fontScale: fontScale ?? this.fontScale,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      highContrast: highContrast ?? this.highContrast,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      letterSpacing: letterSpacing ?? this.letterSpacing,
    );
  }
}
