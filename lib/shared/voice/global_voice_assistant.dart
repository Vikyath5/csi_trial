import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'voice_command_service.dart';
import '../../platform_core/session_controller.dart';
import 'package:vibration/vibration.dart';

/// Global Assistant Wrapper
/// Handles ALL gestures centrally to avoid conflicts.
class GlobalVoiceAssistant extends StatefulWidget {
  final Widget child;
  const GlobalVoiceAssistant({super.key, required this.child});

  @override
  State<GlobalVoiceAssistant> createState() => _GlobalVoiceAssistantState();
}

class _GlobalVoiceAssistantState extends State<GlobalVoiceAssistant> {
  final VoiceCommandService _voice = VoiceCommandService();
  int _tapCount = 0;
  Timer? _tapTimer;
  Offset _lastDownPos = Offset.zero;

  void _handlePointerDown(PointerDownEvent event) {
     _lastDownPos = event.position;
  }

  void _handlePointerUp(PointerUpEvent event) {
    final distance = (event.position - _lastDownPos).distance;
    if (distance > 20) {
      _tapCount = 0;
      _tapTimer?.cancel();
      return;
    }

    _tapCount++;
    _tapTimer?.cancel();
    
    // 450ms is a good sweet spot for multi-tap detection
    _tapTimer = Timer(const Duration(milliseconds: 450), () {
      final session = Provider.of<SessionController>(context, listen: false);
      
      if (_tapCount == 1) {
        // Single Tap -> App Status / Navigation Info
        _handleSingleTap(session);
      } else if (_tapCount == 2) {
        // Double Tap -> Assistant
        _handleDoubleTap(session);
      } else if (_tapCount == 3) {
        // Triple Tap -> Continuous Toggle
        _handleTripleTap(session);
      }
      
      _tapCount = 0;
    });
  }

  void _handleSingleTap(SessionController session) {
    // We only provide status if we aren't busy with the assistant
    if (_voice.isListening) return;

    if (session.activeModule == ActiveModule.vision) {
       // Handled by VisionScreen to provide real-time count
    } else if (session.activeModule == ActiveModule.dashboard) {
       _voice.speak('Home Screen. Swipe left for Vision Mode. Swipe right for learning.');
    } else {
       _voice.speak('Learning Screen. Swipe right to go back.');
    }
  }

  Future<void> _handleDoubleTap(SessionController session) async {
    await _voice.stop();
    _voice.startListening(
      onCommand: (command) {
        _voice.resolveCommand(command, context, (action) {
          if (action == 'vision' || action == 'describe' || action == 'read') {
            _voice.speak('Opening Vision Mode');
            session.navigateTo(ActiveModule.vision);
            session.triggerCommand(GlobalCommand.describe);
          } else if (action == 'toggleNavigation') {
            // Make sure we're in vision mode first
            _voice.speak('Turning on navigation guidance.');
            session.navigateTo(ActiveModule.vision);
            session.triggerCommand(GlobalCommand.toggleNavigation);
          } else if (action == 'stop') {
            _voice.speak('Stopping guidance.');
            session.triggerCommand(GlobalCommand.toggleNavigation); // toggles off
          } else if (action == 'learning') {
            _voice.speak('Opening ADHD Learning Mode');
            session.navigateTo(ActiveModule.learning);
          } else if (action == 'home') {
            session.goToDashboard();
            _voice.speak('Opening Home Menu.');
          } else if (action.startsWith('map:')) {
            String dest = action.replaceFirst('map:', '');
            _voice.speak('Starting navigation to $dest');
            session.navigateTo(ActiveModule.vision);
            session.setNavigationDestination(dest);
            session.triggerCommand(GlobalCommand.openMap);
          }
        });
      },
      onStatusChange: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _handleTripleTap(SessionController session) {
    Vibration.vibrate(duration: 200);
    _voice.speak('Sensory Guidance Toggled');
    session.triggerCommand(GlobalCommand.toggleContinuous);
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {}, // We use Listener for the raw taps
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        child: widget.child,
      ),
    );
  }
}
