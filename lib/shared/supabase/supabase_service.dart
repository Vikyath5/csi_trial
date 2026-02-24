/// ============================================================
/// NeuroVision — Supabase Service
/// ============================================================
/// Placeholder for Supabase data operations.
/// Member D (Backend Lead) will implement actual Supabase
/// queries for user profiles, preferences, and progress data.
///
/// For now, all data is managed locally through
/// SessionController and mock data.
/// ============================================================

class SupabaseService {
  // ── User Profile Operations ──

  /// Fetches user profile from Supabase
  /// TODO: Implement with Supabase client
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    // Mock implementation
    return {
      'id': userId,
      'display_name': 'Demo Learner',
      'preferred_mode': 'learning',
      'font_scale': 1.0,
      'vibration_enabled': true,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // ── Progress Operations ──

  /// Saves user progress to Supabase
  /// TODO: Implement with Supabase client
  Future<void> saveProgress(String userId, Map<String, dynamic> progress) async {
    // Mock — will be replaced by Supabase insert/upsert
  }

  /// Fetches user progress from Supabase
  /// TODO: Implement with Supabase client
  Future<Map<String, dynamic>?> getProgress(String userId) async {
    // Mock implementation
    return {
      'blocks_completed': 0,
      'focus_streak': 0,
      'best_streak': 0,
      'total_learning_seconds': 0,
      'badges': <String>[],
      'objects_detected': 0,
    };
  }
}
