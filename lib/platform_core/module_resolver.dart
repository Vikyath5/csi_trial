/// ============================================================
/// NeuroVision — Module Resolver
/// ============================================================
/// Utility to resolve which module should be active based on
/// user accessibility settings retrieved from Supabase.
/// ============================================================

enum ModuleType { learning, vision }

class ModuleResolver {
  /// Resolves the active module based on user's preferred mode string.
  /// Called when loading user profile from Supabase.
  static ModuleType resolve(String preferredMode) {
    if (preferredMode == 'vision') {
      return ModuleType.vision;
    }
    return ModuleType.learning;
  }
}
