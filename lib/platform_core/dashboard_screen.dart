/// ============================================================
/// NeuroVision — Dashboard Screen
/// ============================================================
/// The main landing screen. High-contrast, low-distraction
/// design with two large, accessible buttons:
///   • Learning Mode (ADHD & Dyslexia support)
///   • Vision Mode (Blind / Tactile support)
///
/// Also displays a quick stats summary and accessibility
/// controls.
/// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'session_controller.dart';
import '../shared/accessibility/accessibility_theme.dart';
import '../shared/voice/voice_command_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final VoiceCommandService _voice = VoiceCommandService();

  @override
  void initState() {
    super.initState();
    // Immediate welcome announcement
    _voice.init().then((_) {
      _voice.speak('Welcome to Neuro Vision. Double tap for Voice Assistant. Swipe right for A D H D Learning. Swipe left for Vision Mode.');
    });
  }

  void _handleVoiceCommand(String command, SessionController session) {
    debugPrint('Dashboard Voice Command Received: $command');
    _voice.resolveCommand(command, context, (action) {
      debugPrint('Resolved Action: $action');
      if (action == 'vision' || action == 'describe' || action == 'read') {
        _voice.speak('Opening Vision Mode');
        // Small delay to allow speech to start
        Future.delayed(const Duration(milliseconds: 500), () => session.navigateTo(ActiveModule.vision));
      } else if (action == 'learning') {
        _voice.speak('Opening Learning Mode');
        Future.delayed(const Duration(milliseconds: 500), () => session.navigateTo(ActiveModule.learning));
      } else if (action.startsWith('map:')) {
        String dest = action.replaceFirst('map:', '');
        _voice.speak('Navigating to $dest');
        _launchMap(dest);
      }
    });
  }

  Future<void> _launchMap(String destination) async {
    final query = Uri.encodeComponent(destination);
    final navUri = Uri.parse('google.navigation:q=$query&mode=d');
    final searchUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    
    try {
      if (await canLaunchUrl(navUri)) {
        await launchUrl(navUri);
      } else {
        await launchUrl(searchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Map Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              // Extremely responsive threshold (150)
              if (details.primaryVelocity! < -150) {
                // Swipe Left -> Vision Mode
                _voice.speak('Opening Vision Mode');
                session.navigateTo(ActiveModule.vision);
              } else if (details.primaryVelocity! > 150) {
                // Swipe Right -> ADHD Mode
                _voice.speak('Opening ADHD Learning Mode');
                session.navigateTo(ActiveModule.learning);
              }
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: NVDimensions.spacingL,
              vertical: NVDimensions.spacingXL,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Screen Reader Welcome ──
                Semantics(
                  label: 'Welcome to NeuroVision. Swipe right for ADHD Learning. Swipe left for Vision Mode. Double tap here to start Vision Mode immediately.',
                  onTap: () => session.navigateTo(ActiveModule.vision),
                  child: const SizedBox(height: 1),
                ),

              const SizedBox(height: NVDimensions.spacingM),

              // ── App Identity ──
              _buildAppHeader(theme),

              const SizedBox(height: NVDimensions.spacingXXL),

              // ── Quick Stats ──
              _buildStatsRow(context, session),

              const SizedBox(height: NVDimensions.spacingXL),

              // ── Mode Selection ──
              Text(
                'Choose Your Mode',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: NVColors.textSecondary,
                ),
              ),

              const SizedBox(height: NVDimensions.spacingL),

              // ── Learning Mode Button ──
              _ModeCard(
                icon: Icons.auto_stories_rounded,
                title: 'Learning Mode',
                subtitle: 'ADHD & Dyslexia Support',
                description: 'Micro-learning blocks with focus tracking',
                accentColor: NVColors.learningAccent,
                onTap: () => session.navigateTo(ActiveModule.learning),
              ),

              const SizedBox(height: NVDimensions.spacingM),

              // ── Vision Mode Button ──
              _ModeCard(
                icon: Icons.visibility_rounded,
                title: 'Vision Mode',
                subtitle: 'Tactile & Audio Feedback',
                description: 'Shape detection with vibration patterns',
                accentColor: NVColors.visionAccent,
                onTap: () => session.navigateTo(ActiveModule.vision),
              ),

              const SizedBox(height: NVDimensions.spacingXXL),

              // ── External Assistive Tools ──
              _buildExternalTools(theme),

              const SizedBox(height: NVDimensions.spacingXXL),

              // ── Accessibility Controls ──
              _buildAccessibilityControls(context, session, theme),

              const SizedBox(height: NVDimensions.spacingXL),
            ],
          ),
        ),
      ),
    ),
   );
  }

  // ────────────────────────────────────────────
  // App Header with icon and name
  // ────────────────────────────────────────────
  Widget _buildAppHeader(ThemeData theme) {
    return Column(
      children: [
        // Brain icon with glow effect
        ExcludeSemantics(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [NVColors.primaryBlue, NVColors.primaryPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: NVColors.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: NVDimensions.spacingM),
        Text(
          'NeuroVision',
          style: theme.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: NVDimensions.spacingXS),
        Text(
          'Assistive Learning Platform',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: NVColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────
  // Quick Stats Row
  // ────────────────────────────────────────────
  Widget _buildStatsRow(BuildContext context, SessionController session) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            icon: Icons.check_circle_outline_rounded,
            value: '${session.progress.blocksCompleted}',
            label: 'Completed',
            color: NVColors.primaryGreen,
          ),
        ),
        const SizedBox(width: NVDimensions.spacingS),
        Expanded(
          child: _StatChip(
            icon: Icons.local_fire_department_rounded,
            value: '${session.progress.focusStreak}',
            label: 'Streak',
            color: NVColors.streakGold,
          ),
        ),
        const SizedBox(width: NVDimensions.spacingS),
        Expanded(
          child: _StatChip(
            icon: Icons.emoji_events_rounded,
            value: '${session.progress.badges.length}',
            label: 'Badges',
            color: NVColors.primaryOrange,
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────
  // External Assistive Tools
  // ────────────────────────────────────────────
  Widget _buildExternalTools(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.extension_rounded,
              color: NVColors.primaryOrange,
              size: 24,
            ),
            const SizedBox(width: NVDimensions.spacingS),
            Text(
              'Assistive Toolbox',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: NVDimensions.spacingL),
        Row(
          children: [
            // Google Maps
            Expanded(
              child: _ToolTile(
                icon: Icons.map_rounded,
                label: 'Google Maps\nDirections',
                color: const Color(0xFF4285F4),
                onTap: () => _launchURL('https://www.google.com/maps/dir/?api=1'),
              ),
            ),
            const SizedBox(width: NVDimensions.spacingM),
            // Seeing AI
            Expanded(
              child: _ToolTile(
                icon: Icons.remove_red_eye_rounded,
                label: 'Seeing AI\nDetection',
                color: const Color(0xFF0078D4),
                onTap: () => _launchURL('seeingai://'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback or error message if app not installed
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Error launching $url: $e');
    }
  }

  // ────────────────────────────────────────────
  // Accessibility Controls
  // ────────────────────────────────────────────
  Widget _buildAccessibilityControls(
    BuildContext context,
    SessionController session,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(NVDimensions.spacingL),
      decoration: BoxDecoration(
        color: NVColors.surface,
        borderRadius: BorderRadius.circular(NVDimensions.radiusL),
        border: Border.all(color: NVColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.accessibility_new_rounded,
                color: NVColors.primaryPurple,
                size: 24,
              ),
              const SizedBox(width: NVDimensions.spacingS),
              Text(
                'Accessibility',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),

          const SizedBox(height: NVDimensions.spacingL),

          // Font size slider
          Text(
            'Text Size',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: NVDimensions.spacingS),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: NVColors.primaryBlue,
              inactiveTrackColor: NVColors.surfaceElevated,
              thumbColor: NVColors.primaryBlue,
              overlayColor: NVColors.primaryBlue.withValues(alpha: 0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 12,
              ),
            ),
            child: Slider(
              value: session.prefs.fontScale,
              min: 0.8,
              max: 2.0,
              divisions: 12,
              label: '${(session.prefs.fontScale * 100).round()}%',
              onChanged: (value) => session.setFontScale(value),
            ),
          ),
          Center(
            child: Text(
              'Current: ${(session.prefs.fontScale * 100).round()}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: NVColors.textMuted,
              ),
            ),
          ),

          const SizedBox(height: NVDimensions.spacingM),

          // Vibration toggle
          SwitchListTile(
            value: session.prefs.vibrationEnabled,
            onChanged: (_) => session.toggleVibration(),
            title: Text(
              'Haptic Feedback',
              style: theme.textTheme.bodyLarge,
            ),
            subtitle: Text(
              'Vibration patterns for Vision Mode',
              style: theme.textTheme.bodyMedium,
            ),
            activeColor: NVColors.primaryGreen,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Private Widgets
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// A large, accessible card button for selecting a mode.
class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final Color accentColor;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: '$title — $subtitle. $description',
      child: Material(
        color: NVColors.surface,
        borderRadius: BorderRadius.circular(NVDimensions.radiusL),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NVDimensions.radiusL),
          splashColor: accentColor.withValues(alpha: 0.15),
          highlightColor: accentColor.withValues(alpha: 0.08),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(NVDimensions.spacingL),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NVDimensions.radiusL),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Icon circle
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.15),
                  ),
                  child: Icon(icon, size: 32, color: accentColor),
                ),

                const SizedBox(width: NVDimensions.spacingM),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: NVColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: NVColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: accentColor.withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small stat chip for the dashboard header
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NVDimensions.spacingM,
        vertical: NVDimensions.spacingM,
      ),
      decoration: BoxDecoration(
        color: NVColors.surface,
        borderRadius: BorderRadius.circular(NVDimensions.radiusM),
        border: Border.all(color: NVColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: NVDimensions.spacingXS),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: NVColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// A smaller tile for external tool links.
class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ToolTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: NVColors.surface,
        borderRadius: BorderRadius.circular(NVDimensions.radiusM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NVDimensions.radiusM),
          splashColor: color.withAlpha(25),
          child: Container(
            height: 100, // Fixed height for consistency in row
            padding: const EdgeInsets.all(NVDimensions.spacingM),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NVDimensions.radiusM),
              border: Border.all(
                color: NVColors.cardBorder,
                width: 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: NVDimensions.spacingS),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: NVColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
