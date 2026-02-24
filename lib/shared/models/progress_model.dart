/// ============================================================
/// NeuroVision — Progress Model
/// ============================================================
/// Tracks user progress across both modules.
/// Stored locally and synced to Supabase by backend team.
/// ============================================================

class ProgressModel {
  /// Total blocks completed in Learning Mode
  final int blocksCompleted;

  /// Current focus streak (consecutive blocks without distraction)
  final int focusStreak;

  /// Longest streak ever achieved
  final int bestStreak;

  /// Total time spent learning (in seconds)
  final int totalLearningSeconds;

  /// Badges earned
  final List<String> badges;

  /// Objects detected in Vision Mode
  final int objectsDetected;

  const ProgressModel({
    this.blocksCompleted = 0,
    this.focusStreak = 0,
    this.bestStreak = 0,
    this.totalLearningSeconds = 0,
    this.badges = const [],
    this.objectsDetected = 0,
  });

  /// Creates a copy with overridden values
  ProgressModel copyWith({
    int? blocksCompleted,
    int? focusStreak,
    int? bestStreak,
    int? totalLearningSeconds,
    List<String>? badges,
    int? objectsDetected,
  }) {
    return ProgressModel(
      blocksCompleted: blocksCompleted ?? this.blocksCompleted,
      focusStreak: focusStreak ?? this.focusStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      totalLearningSeconds: totalLearningSeconds ?? this.totalLearningSeconds,
      badges: badges ?? this.badges,
      objectsDetected: objectsDetected ?? this.objectsDetected,
    );
  }

  /// Factory from Supabase JSON
  factory ProgressModel.fromJson(Map<String, dynamic> json) {
    return ProgressModel(
      blocksCompleted: json['blocks_completed'] as int? ?? 0,
      focusStreak: json['focus_streak'] as int? ?? 0,
      bestStreak: json['best_streak'] as int? ?? 0,
      totalLearningSeconds: json['total_learning_seconds'] as int? ?? 0,
      badges: List<String>.from(json['badges'] as List? ?? []),
      objectsDetected: json['objects_detected'] as int? ?? 0,
    );
  }

  /// Convert to JSON for Supabase storage
  Map<String, dynamic> toJson() {
    return {
      'blocks_completed': blocksCompleted,
      'focus_streak': focusStreak,
      'best_streak': bestStreak,
      'total_learning_seconds': totalLearningSeconds,
      'badges': badges,
      'objects_detected': objectsDetected,
    };
  }
}
