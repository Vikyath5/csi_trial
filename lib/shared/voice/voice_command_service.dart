import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

/// Central service for the "Double-Tap Voice Assistant"
/// Completely rewritten for maximum reliability.
class VoiceCommandService {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  bool _isInitialized = false;
  bool _isListening = false;
  
  bool get isListening => _isListening;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _speech.initialize(
        onStatus: (status) => debugPrint('Speech Status: $status'),
        onError: (error) => debugPrint('Speech Error: $error'),
      );
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);  // Slightly faster = more natural
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Voice Service Init Failed: $e');
    }
  }

  Future<void> speak(String text) async {
    debugPrint('TTS Speaking: $text');
    await _tts.stop(); // Stop any current speech
    await _tts.speak(text);
  }

  /// Start listening for a command
  Future<void> startListening({
    required Function(String command) onCommand,
    required VoidCallback onStatusChange,
  }) async {
    if (!_isInitialized) await init();

    // Kill any existing listening
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }

    // Give haptic and audio confirmation that we're listening
    Vibration.vibrate(duration: 200);
    await speak('I am listening.');
    
    // Brief delay to ensure the prompt doesn't trigger the listener
    await Future.delayed(const Duration(milliseconds: 1000)); 

    _isListening = true;
    onStatusChange();

    await _speech.listen(
      onResult: (result) {
        debugPrint('Partial result: ${result.recognizedWords}');
        if (result.finalResult) {
          _isListening = false;
          onStatusChange();
          String cmd = result.recognizedWords.toLowerCase().trim();
          debugPrint('Final Command: $cmd');
          onCommand(cmd);
        }
      },
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  Future<void> stop() async {
    await _speech.stop();
    _isListening = false;
  }

  /// Improved command resolution with fuzzy matching
  void resolveCommand(String text, BuildContext context, Function(String action) onAction) {
    if (text.isEmpty) return;

    // 1. Navigation Commands (module switching)
    if (text.contains('vision') || text.contains('see') || text.contains('camera')) {
       onAction('vision');
    }
    else if (text.contains('learning') || text.contains('adhd') || text.contains('study')) {
       onAction('learning');
    }
    // 2. Navigation Guidance (direct / guide me)
    else if (text.contains('direct') || text.contains('guide me') ||
             text.contains('guide') || text.contains('navigate me') ||
             text.contains('avoid') || text.contains('help me walk') ||
             text.contains('path') || text.contains('direction')) {
       onAction('toggleNavigation');
    }
    // 3. Vision Interaction
    else if (text.contains('describe') || text.contains('what') ||
             text.contains('surroundings') || text.contains('around me') ||
             text.contains('tell me') || text.contains('what do you see')) {
       onAction('describe');
    }
    else if (text.contains('read') || text.contains('text') ||
             text.contains('book') || text.contains('paper')) {
       onAction('read');
    }
    // 4. Map/Place Navigation
    else if (text.contains('map') || text.contains('navigate') ||
             text.contains('take me to') || text.contains('go to') ||
             text.contains('where is')) {
      String destination = text;
      final triggers = ['take me to', 'navigate to', 'map to', 'destination', 'go to', 'map', 'where is'];
      for (var trigger in triggers) {
        if (destination.contains(trigger)) {
          final parts = destination.split(trigger);
          if (parts.length > 1) {
            destination = parts.sublist(1).join(trigger).trim();
            break;
          }
        }
      }
      if (destination.length > 2) {
        onAction('map:$destination');
      } else {
        speak('Where would you like to go?');
      }
    }
    // 5. Stop / cancel
    else if (text.contains('stop') || text.contains('cancel') || text.contains('off')) {
      onAction('stop');
    }
    // 6. Home
    else if (text.contains('home') || text.contains('dashboard') || text.contains('menu')) {
      onAction('home');
    }
    else {
      speak('I heard: $text. Try saying "guide me", "describe", or "go to" followed by a place.');
    }
  }
}
