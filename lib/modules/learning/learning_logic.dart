/// ============================================================
/// NeuroVision — Learning Logic
/// ============================================================
/// Handles content processing for the ADHD & Dyslexia module:
///   • Splits lessons into micro-learning blocks (≤30 words)
///   • Tracks engagement through time-on-task
///   • Adjusts pacing based on reading speed
///   • Text-to-Speech for reading content aloud
///   • Quiz scoring and results
/// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// A single micro-learning block shown to the user
class LearningBlock {
  final int index;
  final String text;
  final int wordCount;
  final Duration estimatedTime;

  const LearningBlock({
    required this.index,
    required this.text,
    required this.wordCount,
    required this.estimatedTime,
  });
}

/// How the user is pacing through content
enum PacingStatus { tooFast, normal, tooSlow }

/// Snapshot of user engagement for a single block
class EngagementSnapshot {
  final Duration timeSpent;
  final Duration expectedTime;

  const EngagementSnapshot({
    required this.timeSpent,
    required this.expectedTime,
  });

  /// Ratio of actual time to expected time
  double get ratio =>
      expectedTime.inSeconds > 0
          ? timeSpent.inSeconds / expectedTime.inSeconds
          : 1.0;
}

/// Result of a quiz attempt
class QuizResult {
  final int totalQuestions;
  final int correctAnswers;
  final List<bool> answerResults;

  const QuizResult({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.answerResults,
  });

  double get percentage =>
      totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0;

  bool get passed => percentage >= 60;

  String get grade {
    if (percentage >= 90) return 'Excellent! ⭐';
    if (percentage >= 80) return 'Great Job! 🎉';
    if (percentage >= 60) return 'Good Work! 👍';
    if (percentage >= 40) return 'Keep Trying! 💪';
    return 'Let\'s Learn Again! 📚';
  }
}

class LearningLogic {
  // ── Configurable thresholds ──

  /// Maximum words per micro-learning block
  static const int maxWordsPerBlock = 30;

  /// Assumed reading speed (words per minute)
  /// Lower than average to accommodate ADHD/Dyslexia users
  static const int wordsPerMinute = 120;

  /// If user reads faster than 50% of expected time → too fast
  static const double tooFastThreshold = 0.5;

  /// If user takes longer than 200% of expected time → too slow
  static const double tooSlowThreshold = 2.0;

  // ── TTS ──
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;
  bool get ttsReady => _ttsReady;

  // ──────────────────────────────────
  // TTS Initialization
  // ──────────────────────────────────

  /// Initializes Text-to-Speech engine
  Future<void> initializeTTS() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.4); // Slow for ADHD/kids
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.1); // Slightly higher pitch for clarity

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((msg) {
        debugPrint('[LearningLogic] TTS error: $msg');
        _isSpeaking = false;
      });

      _ttsReady = true;
      debugPrint('[LearningLogic] TTS initialized');
    } catch (e) {
      debugPrint('[LearningLogic] TTS init failed: $e');
      _ttsReady = false;
    }
  }

  /// Reads the given text aloud using TTS
  Future<void> speakText(String text) async {
    if (!_ttsReady) return;

    try {
      await _tts.stop(); // Stop any ongoing speech
      _isSpeaking = true;
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[LearningLogic] TTS speak error: $e');
      _isSpeaking = false;
    }
  }

  /// Stops TTS playback
  Future<void> stopSpeaking() async {
    if (!_ttsReady) return;
    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint('[LearningLogic] TTS stop error: $e');
    }
  }

  /// Set TTS speech rate
  Future<void> setSpeechRate(double rate) async {
    if (!_ttsReady) return;
    await _tts.setSpeechRate(rate.clamp(0.1, 1.0));
  }

  // ──────────────────────────────────
  // Content Chunking
  // ──────────────────────────────────

  /// Splits a lesson string into micro-learning blocks.
  /// Groups complete sentences, staying under [maxWordsPerBlock].
  List<LearningBlock> chunkContent(String content) {
    if (content.trim().isEmpty) return [];

    // Split into sentences
    final sentences = _splitSentences(content);
    final blocks = <LearningBlock>[];
    var currentText = '';
    var currentWordCount = 0;

    for (final sentence in sentences) {
      final sentenceWords = sentence.trim().split(RegExp(r'\s+')).length;

      // If adding this sentence would exceed the limit, save current block
      if (currentWordCount + sentenceWords > maxWordsPerBlock &&
          currentText.isNotEmpty) {
        blocks.add(_createBlock(blocks.length, currentText, currentWordCount));
        currentText = '';
        currentWordCount = 0;
      }

      // Add sentence to current block
      if (currentText.isNotEmpty) currentText += ' ';
      currentText += sentence.trim();
      currentWordCount += sentenceWords;
    }

    // Don't forget the last block
    if (currentText.isNotEmpty) {
      blocks.add(_createBlock(blocks.length, currentText, currentWordCount));
    }

    return blocks;
  }

  /// Splits a list of lessons into blocks (one topic = many lessons = many blocks)
  List<LearningBlock> chunkLessons(List<String> lessons) {
    final allBlocks = <LearningBlock>[];
    for (final lesson in lessons) {
      final blocks = chunkContent(lesson);
      // Re-index blocks globally
      for (final block in blocks) {
        allBlocks.add(LearningBlock(
          index: allBlocks.length,
          text: block.text,
          wordCount: block.wordCount,
          estimatedTime: block.estimatedTime,
        ));
      }
    }
    return allBlocks;
  }

  LearningBlock _createBlock(int index, String text, int wordCount) {
    final seconds = (wordCount / wordsPerMinute * 60).ceil();
    return LearningBlock(
      index: index,
      text: text,
      wordCount: wordCount,
      estimatedTime: Duration(seconds: seconds.clamp(3, 30)),
    );
  }

  /// Splits text into sentences by splitting on '. ', '! ', '? '
  List<String> _splitSentences(String text) {
    final sentences = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);

      // Check for sentence boundary
      if ((text[i] == '.' || text[i] == '!' || text[i] == '?') &&
          (i + 1 >= text.length || text[i + 1] == ' ')) {
        final sentence = buffer.toString().trim();
        if (sentence.isNotEmpty) sentences.add(sentence);
        buffer.clear();
      }
    }

    // Remaining text
    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) sentences.add(remaining);

    return sentences;
  }

  // ──────────────────────────────────
  // Pacing Evaluation
  // ──────────────────────────────────

  /// Evaluates the user's reading pace and returns a status
  PacingStatus adjustPacing(EngagementSnapshot snapshot) {
    if (snapshot.ratio < tooFastThreshold) return PacingStatus.tooFast;
    if (snapshot.ratio > tooSlowThreshold) return PacingStatus.tooSlow;
    return PacingStatus.normal;
  }

  // ──────────────────────────────────
  // Cleanup
  // ──────────────────────────────────

  void dispose() {
    _tts.stop();
    _isSpeaking = false;
  }
}
