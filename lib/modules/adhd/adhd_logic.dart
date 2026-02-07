/// ADHD Learning Support Logic
/// Member A – Vinethraj
/// Issue #2: Content Chunking & Engagement Tracking

enum PacingStatus { tooFast, normal, tooSlow }

class LearningBlock {
  final int index;
  final String text;
  final Duration estimatedTime;

  LearningBlock({
    required this.index,
    required this.text,
    required this.estimatedTime,
  });
}

class EngagementSnapshot {
  final Duration timeSpent;
  final Duration expectedTime;

  EngagementSnapshot({
    required this.timeSpent,
    required this.expectedTime,
  });
}

class ADHDLogic {
  /// Splits dense text into short micro-learning blocks
  /// Optimized for reduced cognitive load
  List<LearningBlock> chunkContent(String content) {
    final sentences = content.split('.');
    final List<LearningBlock> blocks = [];

    int blockIndex = 0;

    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isEmpty) continue;

      final wordCount = trimmed.split(' ').length;

      // Simple estimation: ~200 words/minute reading speed
      final estimatedSeconds = (wordCount / 200 * 60).ceil();

      blocks.add(
        LearningBlock(
          index: blockIndex,
          text: trimmed,
          estimatedTime: Duration(seconds: estimatedSeconds),
        ),
      );

      blockIndex++;
    }

    return blocks;
  }

  /// Evaluates user engagement speed and adjusts pacing
  PacingStatus adjustPacing(EngagementSnapshot snapshot) {
    if (snapshot.timeSpent < snapshot.expectedTime * 0.5) {
      return PacingStatus.tooFast;
    }

    if (snapshot.timeSpent > snapshot.expectedTime * 1.5) {
      return PacingStatus.tooSlow;
    }

    return PacingStatus.normal;
  }
}
