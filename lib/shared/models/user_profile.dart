/// ============================================================
/// NeuroVision — User Profile Model
/// ============================================================
/// Represents a user profile stored in Supabase.
/// Member D (backend) will wire this to the database.
/// ============================================================

class UserProfile {
  final String id;
  final String displayName;
  final String preferredMode; // 'learning' or 'vision'
  final double fontScale;
  final bool vibrationEnabled;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.displayName,
    this.preferredMode = 'learning',
    this.fontScale = 1.0,
    this.vibrationEnabled = true,
    required this.createdAt,
  });

  /// Mock user for development
  factory UserProfile.mock() {
    return UserProfile(
      id: 'demo_user_001',
      displayName: 'Demo Learner',
      preferredMode: 'learning',
      fontScale: 1.0,
      vibrationEnabled: true,
      createdAt: DateTime.now(),
    );
  }

  /// Factory from Supabase JSON (for backend integration)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'User',
      preferredMode: json['preferred_mode'] as String? ?? 'learning',
      fontScale: (json['font_scale'] as num?)?.toDouble() ?? 1.0,
      vibrationEnabled: json['vibration_enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert to JSON for Supabase storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'preferred_mode': preferredMode,
      'font_scale': fontScale,
      'vibration_enabled': vibrationEnabled,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
