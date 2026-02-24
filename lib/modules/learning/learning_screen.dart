/// ============================================================
/// NeuroVision — Learning Screen
/// ============================================================
/// ADHD & Dyslexia Learning Module with progressive difficulty.
///
/// Flow:
///   1. User picks a difficulty level (Basic → Advanced)
///   2. User picks a topic within that level
///   3. Content is chunked into micro-learning blocks
///   4. Each block is auto-read via TTS + manual "Read Aloud" btn
///   5. After all blocks, take a quiz to test knowledge
///   6. Completion dialog with score, streak, and badge rewards
/// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../platform_core/session_controller.dart';
import '../../shared/accessibility/accessibility_theme.dart';
import 'learning_logic.dart';
import 'content_repository.dart';
import '../../shared/voice/voice_command_service.dart';
import 'package:url_launcher/url_launcher.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen>
    with TickerProviderStateMixin {
  final LearningLogic _logic = LearningLogic();
  final VoiceCommandService _voice = VoiceCommandService();

  // ── Navigation State ──
  DifficultyLevel? _selectedDifficulty;
  LearningTopic? _selectedTopic;
  List<LearningBlock> _blocks = [];
  int _currentIndex = 0;

  // ── Time tracking ──
  Timer? _tickTimer;
  int _elapsedSeconds = 0;

  // ── Pacing ──
  PacingStatus? _pacingStatus;
  bool _showPacingPrompt = false;

  // ── TTS ──
  bool _autoReadEnabled = true;
  bool _isSpeaking = false;
  double _speechRate = 0.4;

  // ── Quiz State ──
  bool _inQuizMode = false;
  int _quizIndex = 0;
  List<int?> _quizAnswers = [];
  QuizResult? _quizResult;

  // ── Animation ──
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _logic.initializeTTS();
    _voice.init(); // CRITICAL: Initialize voice assistant service

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _logic.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Select difficulty level ──
  void _selectDifficulty(DifficultyLevel level) {
    _animateTransition(() {
      setState(() {
        _selectedDifficulty = level;
        _selectedTopic = null;
        _inQuizMode = false;
        _quizResult = null;
      });
    });
  }

  // ── Select a topic and start learning ──
  void _selectTopic(LearningTopic topic) {
    _animateTransition(() {
      setState(() {
        _selectedTopic = topic;
        _blocks = _logic.chunkLessons(topic.lessons);
        _currentIndex = 0;
        _inQuizMode = false;
        _quizResult = null;
      });
      _startBlockTimer();
      if (_autoReadEnabled && _blocks.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _readCurrentBlock();
        });
      }
    });
  }

  // ── Go back ──
  void _goBack() {
    _logic.stopSpeaking();
    _tickTimer?.cancel();

    _animateTransition(() {
      if (_inQuizMode) {
        setState(() {
          _inQuizMode = false;
          _quizResult = null;
          _quizIndex = 0;
          _quizAnswers = [];
        });
      } else if (_selectedTopic != null) {
        setState(() {
          _selectedTopic = null;
          _blocks = [];
          _currentIndex = 0;
        });
      } else if (_selectedDifficulty != null) {
        setState(() => _selectedDifficulty = null);
      } else {
        context.read<SessionController>().goToDashboard();
      }
    });
  }

  void _animateTransition(VoidCallback action) {
    _fadeController.reverse().then((_) {
      action();
      _fadeController.forward();
    });
  }

  // ── Timer ──
  void _startBlockTimer() {
    _elapsedSeconds = 0;
    _pacingStatus = null;
    _showPacingPrompt = false;

    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        _checkPacing();
      });
    });
  }

  void _checkPacing() {
    if (_currentIndex >= _blocks.length) return;

    final block = _blocks[_currentIndex];
    final snapshot = EngagementSnapshot(
      timeSpent: Duration(seconds: _elapsedSeconds),
      expectedTime: block.estimatedTime,
    );

    final status = _logic.adjustPacing(snapshot);
    if (status != PacingStatus.normal && !_showPacingPrompt) {
      setState(() {
        _pacingStatus = status;
        _showPacingPrompt = true;
      });
    }
  }

  // ── TTS ──
  void _readCurrentBlock() {
    if (_currentIndex < _blocks.length) {
      final text = _blocks[_currentIndex].text;
      _logic.speakText(text);
      setState(() => _isSpeaking = true);
    }
  }

  void _stopReading() {
    _logic.stopSpeaking();
    setState(() => _isSpeaking = false);
  }

  void _toggleAutoRead() {
    setState(() => _autoReadEnabled = !_autoReadEnabled);
  }

  void _changeSpeechRate(double rate) {
    _speechRate = rate;
    _logic.setSpeechRate(rate);
  }

  // ── Navigation ──
  void _nextBlock() {
    _logic.stopSpeaking();
    final session = context.read<SessionController>();
    session.completeBlock();

    if (_currentIndex < _blocks.length - 1) {
      setState(() {
        _currentIndex++;
        _startBlockTimer();
        _isSpeaking = false;
      });
      if (_autoReadEnabled) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _readCurrentBlock();
        });
      }
    } else {
      _tickTimer?.cancel();
      // If topic has quiz, start quiz. Otherwise show completion.
      if (_selectedTopic != null && _selectedTopic!.quiz.isNotEmpty) {
        _startQuiz();
      } else {
        _showCompletionDialog(null);
      }
    }
  }

  void _previousBlock() {
    _logic.stopSpeaking();
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _startBlockTimer();
        _isSpeaking = false;
      });
      if (_autoReadEnabled) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _readCurrentBlock();
        });
      }
    }
  }

  void _dismissPacingPrompt() {
    setState(() => _showPacingPrompt = false);
  }

  // ── Quiz ──
  void _startQuiz() {
    _animateTransition(() {
      setState(() {
        _inQuizMode = true;
        _quizIndex = 0;
        _quizAnswers = List.filled(_selectedTopic!.quiz.length, null);
        _quizResult = null;
      });
    });

    // Read the first question aloud
    if (_autoReadEnabled && _selectedTopic!.quiz.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          final q = _selectedTopic!.quiz[0];
          _logic.speakText(
            '${q.question}. Option 1: ${q.options[0]}. Option 2: ${q.options[1]}. Option 3: ${q.options[2]}. ${q.options.length > 3 ? 'Option 4: ${q.options[3]}.' : ''}',
          );
        }
      });
    }
  }

  void _selectQuizAnswer(int answerIndex) {
    _logic.stopSpeaking();
    setState(() {
      _quizAnswers[_quizIndex] = answerIndex;
    });

    // Auto-advance after a short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_quizIndex < _selectedTopic!.quiz.length - 1) {
        setState(() => _quizIndex++);

        // Read next question
        if (_autoReadEnabled) {
          final q = _selectedTopic!.quiz[_quizIndex];
          _logic.speakText(
            '${q.question}. Option 1: ${q.options[0]}. Option 2: ${q.options[1]}. Option 3: ${q.options[2]}. ${q.options.length > 3 ? 'Option 4: ${q.options[3]}.' : ''}',
          );
        }
      } else {
        _finishQuiz();
      }
    });
  }

  void _finishQuiz() {
    final quiz = _selectedTopic!.quiz;
    int correct = 0;
    final results = <bool>[];

    for (int i = 0; i < quiz.length; i++) {
      final isCorrect = _quizAnswers[i] == quiz[i].correctIndex;
      results.add(isCorrect);
      if (isCorrect) correct++;
    }

    final result = QuizResult(
      totalQuestions: quiz.length,
      correctAnswers: correct,
      answerResults: results,
    );

    setState(() => _quizResult = result);

    // Announce result
    if (_autoReadEnabled) {
      _logic.speakText(
        'Quiz complete! You got $correct out of ${quiz.length} correct. ${result.grade}',
      );
    }

    _showCompletionDialog(result);
  }

  // ── Completion Dialog ──
  void _showCompletionDialog(QuizResult? quizResult) {
    final session = context.read<SessionController>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: NVColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NVDimensions.radiusL),
          side: const BorderSide(color: NVColors.primaryGreen, width: 2),
        ),
        title: Row(
          children: [
            const Icon(Icons.celebration_rounded,
                color: NVColors.streakGold, size: 32),
            const SizedBox(width: NVDimensions.spacingS),
            Expanded(
              child: Text(
                quizResult != null ? quizResult.grade : 'Well Done!',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: NVColors.streakGold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You finished "${_selectedTopic?.title}" — all ${_blocks.length} blocks!',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (quizResult != null) ...[
              const SizedBox(height: NVDimensions.spacingM),
              Container(
                padding: const EdgeInsets.all(NVDimensions.spacingM),
                decoration: BoxDecoration(
                  color: quizResult.passed
                      ? NVColors.primaryGreen.withValues(alpha: 0.1)
                      : NVColors.warningAmber.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(NVDimensions.radiusM),
                  border: Border.all(
                    color: quizResult.passed
                        ? NVColors.primaryGreen.withValues(alpha: 0.4)
                        : NVColors.warningAmber.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '📝 Quiz Score',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: NVDimensions.spacingS),
                    Text(
                      '${quizResult.correctAnswers} / ${quizResult.totalQuestions}',
                      style: Theme.of(context)
                          .textTheme
                          .displayLarge
                          ?.copyWith(
                            color: quizResult.passed
                                ? NVColors.primaryGreen
                                : NVColors.warningAmber,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      '${quizResult.percentage.round()}%',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: NVDimensions.spacingM),
            _StatRow(
              icon: Icons.check_circle_rounded,
              label: 'Blocks completed',
              value: '${session.progress.blocksCompleted}',
              color: NVColors.primaryGreen,
            ),
            const SizedBox(height: NVDimensions.spacingS),
            _StatRow(
              icon: Icons.local_fire_department_rounded,
              label: 'Current streak',
              value: '${session.progress.focusStreak}',
              color: NVColors.streakGold,
            ),
            const SizedBox(height: NVDimensions.spacingS),
            _StatRow(
              icon: Icons.emoji_events_rounded,
              label: 'Best streak',
              value: '${session.progress.bestStreak}',
              color: NVColors.primaryOrange,
            ),
            if (session.progress.badges.isNotEmpty) ...[
              const SizedBox(height: NVDimensions.spacingM),
              Text('🏅 Badges:',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: NVDimensions.spacingXS),
              Wrap(
                spacing: 8,
                children: session.progress.badges.map((b) {
                  return Chip(
                    label: Text(b.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontSize: 12)),
                    backgroundColor:
                        NVColors.streakGold.withValues(alpha: 0.2),
                    side: const BorderSide(color: NVColors.streakGold),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _goBack();
            },
            child: const Text('Pick Another Topic',
                style:
                    TextStyle(color: NVColors.primaryBlue, fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<SessionController>().goToDashboard();
            },
            child: const Text('Dashboard'),
          ),
        ],
      ),
    );
  }

  // ========================================
  //  BUILD
  // ========================================

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final theme = Theme.of(context);

    String title = 'Learning Mode';
    if (_selectedTopic != null) {
      title = _inQuizMode ? '📝 Quiz' : _selectedTopic!.title;
    } else if (_selectedDifficulty != null) {
      title = _difficultyTitle(_selectedDifficulty!);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
          onPressed: _goBack,
          tooltip: 'Back',
        ),
        title: Text(title),
        actions: [
          // Focus streak badge
          Padding(
            padding: const EdgeInsets.only(right: NVDimensions.spacingM),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    color: NVColors.streakGold, size: 22),
                const SizedBox(width: 4),
                Text(
                  '${session.progress.focusStreak}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: NVColors.streakGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < -150) {
                // Swipe Left -> Back
                _goBack();
              }
            }
          },
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildBody(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_inQuizMode) {
      return _quizResult != null
          ? const SizedBox.shrink() // Dialog handles this
          : _buildQuizView(theme);
    }
    if (_selectedTopic != null) return _buildLessonView(theme);
    if (_selectedDifficulty != null) return _buildTopicPicker(theme);
    return _buildDifficultyPicker(theme);
  }

  // ========================================
  //  DIFFICULTY PICKER (Step 0)
  // ========================================

  Widget _buildDifficultyPicker(ThemeData theme) {
    final counts = ContentRepository.getDifficultyCounts();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(NVDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Difficulty Level',
              style: theme.textTheme.headlineMedium),
          const SizedBox(height: NVDimensions.spacingXS),
          Text(
            'Start from Basic and progress to Advanced at your own pace!',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: NVColors.textSecondary),
          ),
          const SizedBox(height: NVDimensions.spacingXL),

          // Basic Level
          _DifficultyCard(
            level: DifficultyLevel.basic,
            title: '🔤  Basic',
            subtitle: 'Alphabets, Numbers 0-9',
            description: 'Start here! Perfect for beginners.',
            color: NVColors.primaryGreen,
            topicCount: counts[DifficultyLevel.basic] ?? 0,
            onTap: () => _selectDifficulty(DifficultyLevel.basic),
          ),
          const SizedBox(height: NVDimensions.spacingM),

          // Beginner Level
          _DifficultyCard(
            level: DifficultyLevel.beginner,
            title: '🌟  Beginner',
            subtitle: 'Numbers 10-100, Colors, Shapes',
            description: 'Build your knowledge step by step!',
            color: NVColors.primaryBlue,
            topicCount: counts[DifficultyLevel.beginner] ?? 0,
            onTap: () => _selectDifficulty(DifficultyLevel.beginner),
          ),
          const SizedBox(height: NVDimensions.spacingM),

          // Intermediate Level
          _DifficultyCard(
            level: DifficultyLevel.intermediate,
            title: '🧠  Intermediate',
            subtitle: 'Science, Body, Space, Nature',
            description: 'Explore the world around you!',
            color: NVColors.primaryOrange,
            topicCount: counts[DifficultyLevel.intermediate] ?? 0,
            onTap: () =>
                _selectDifficulty(DifficultyLevel.intermediate),
          ),
          const SizedBox(height: NVDimensions.spacingM),

          // Advanced Level
          _DifficultyCard(
            level: DifficultyLevel.advanced,
            title: '🚀  Advanced',
            subtitle: 'Math, Multiplication, Reading',
            description: 'Challenge yourself with harder topics!',
            color: NVColors.primaryPurple,
            topicCount: counts[DifficultyLevel.advanced] ?? 0,
            onTap: () => _selectDifficulty(DifficultyLevel.advanced),
          ),
        ],
      ),
    );
  }

  String _difficultyTitle(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.basic:
        return '🔤 Basic Level';
      case DifficultyLevel.beginner:
        return '🌟 Beginner Level';
      case DifficultyLevel.intermediate:
        return '🧠 Intermediate Level';
      case DifficultyLevel.advanced:
        return '🚀 Advanced Level';
    }
  }

  // ========================================
  //  TOPIC PICKER (Step 1)
  // ========================================

  Widget _buildTopicPicker(ThemeData theme) {
    final topics =
        ContentRepository.getTopicsByDifficulty(_selectedDifficulty!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(NVDimensions.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose a Topic',
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: NVDimensions.spacingXS),
              Text(
                'Each topic has short, focused lessons with a quiz at the end.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: NVColors.textSecondary),
              ),
            ],
          ),
        ),

        // Topic List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: NVDimensions.spacingL,
            ),
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final topic = topics[index];
              return _TopicCard(
                topic: topic,
                onTap: () => _selectTopic(topic),
              );
            },
          ),
        ),
      ],
    );
  }

  // ========================================
  //  LESSON VIEW (Step 2)
  // ========================================

  Widget _buildLessonView(ThemeData theme) {
    final block = _blocks[_currentIndex];
    final progress = (_currentIndex + 1) / _blocks.length;

    return Column(
      children: [
        // ── Progress Bar ──
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NVDimensions.spacingL,
            vertical: NVDimensions.spacingS,
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(NVDimensions.radiusS),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: NVColors.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0
                        ? NVColors.primaryGreen
                        : NVColors.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: NVDimensions.spacingXS),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Block ${_currentIndex + 1} of ${_blocks.length}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: NVColors.textSecondary),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: NVColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── TTS Controls ──
        _buildTTSControls(theme),

        // ── Main Content ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: NVDimensions.spacingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pacing prompt
                if (_showPacingPrompt) _buildPacingPrompt(theme),

                const SizedBox(height: NVDimensions.spacingS),

                // Content card
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(NVDimensions.spacingXL),
                  decoration: BoxDecoration(
                    color: NVColors.surface,
                    borderRadius:
                        BorderRadius.circular(NVDimensions.radiusL),
                    border: Border.all(
                      color: NVColors.learningAccent
                          .withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Block badge + timer
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: NVDimensions.spacingS,
                              vertical: NVDimensions.spacingXS,
                            ),
                            decoration: BoxDecoration(
                              color: NVColors.learningAccent
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                  NVDimensions.radiusS),
                            ),
                            child: Text(
                              'BLOCK ${block.index + 1}',
                              style:
                                  theme.textTheme.labelLarge?.copyWith(
                                color: NVColors.learningAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.timer_outlined,
                                  size: 16,
                                  color: NVColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                '${_elapsedSeconds}s',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(
                                        color: NVColors.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: NVDimensions.spacingL),

                      // The actual content — dyslexia-friendly
                      Text(
                        block.text,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 2.0,
                          wordSpacing: 3.0,
                          letterSpacing: 0.5,
                          fontSize: 20,
                        ),
                      ),

                      const SizedBox(height: NVDimensions.spacingM),

                      // Word count + estimated time
                      Text(
                        '${block.wordCount} words • ~${block.estimatedTime.inSeconds}s read time',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: NVColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Navigation Buttons ──
        _buildNavigationBar(theme),
      ],
    );
  }

  // ── TTS Controls bar ──
  Widget _buildTTSControls(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: NVDimensions.spacingL,
        vertical: NVDimensions.spacingXS,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: NVDimensions.spacingM,
        vertical: NVDimensions.spacingS,
      ),
      decoration: BoxDecoration(
        color: NVColors.surface,
        borderRadius: BorderRadius.circular(NVDimensions.radiusM),
        border: Border.all(color: NVColors.cardBorder),
      ),
      child: Row(
        children: [
          // Read Aloud Button
          Expanded(
            child: GestureDetector(
              onTap: _isSpeaking ? _stopReading : _readCurrentBlock,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NVDimensions.spacingS,
                  vertical: NVDimensions.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: _isSpeaking
                      ? NVColors.primaryOrange.withValues(alpha: 0.15)
                      : NVColors.primaryBlue.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(NVDimensions.radiusS),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isSpeaking
                          ? Icons.stop_rounded
                          : Icons.volume_up_rounded,
                      color: _isSpeaking
                          ? NVColors.primaryOrange
                          : NVColors.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isSpeaking ? 'Stop' : 'Read Aloud',
                      style: TextStyle(
                        color: _isSpeaking
                            ? NVColors.primaryOrange
                            : NVColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: NVDimensions.spacingS),

          // Auto-read toggle
          GestureDetector(
            onTap: _toggleAutoRead,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: NVDimensions.spacingS,
                vertical: NVDimensions.spacingXS,
              ),
              decoration: BoxDecoration(
                color: _autoReadEnabled
                    ? NVColors.primaryGreen.withValues(alpha: 0.15)
                    : NVColors.surfaceElevated,
                borderRadius:
                    BorderRadius.circular(NVDimensions.radiusS),
              ),
              child: Row(
                children: [
                  Icon(
                    _autoReadEnabled
                        ? Icons.auto_awesome
                        : Icons.auto_awesome_outlined,
                    color: _autoReadEnabled
                        ? NVColors.primaryGreen
                        : NVColors.textMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Auto',
                    style: TextStyle(
                      color: _autoReadEnabled
                          ? NVColors.primaryGreen
                          : NVColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: NVDimensions.spacingS),

          // Speed control
          PopupMenuButton<double>(
            onSelected: _changeSpeechRate,
            initialValue: _speechRate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: NVDimensions.spacingS,
                vertical: NVDimensions.spacingXS,
              ),
              decoration: BoxDecoration(
                color: NVColors.surfaceElevated,
                borderRadius:
                    BorderRadius.circular(NVDimensions.radiusS),
              ),
              child: Row(
                children: [
                  const Icon(Icons.speed, size: 18,
                      color: NVColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${(_speechRate * 2.5).toStringAsFixed(1)}x',
                    style: const TextStyle(
                      color: NVColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0.2,
                  child: Text('🐢 Very Slow (0.5x)')),
              const PopupMenuItem(value: 0.35,
                  child: Text('Slow (0.9x)')),
              const PopupMenuItem(value: 0.4,
                  child: Text('Normal (1.0x)')),
              const PopupMenuItem(value: 0.5,
                  child: Text('Fast (1.3x)')),
              const PopupMenuItem(value: 0.6,
                  child: Text('🐇 Very Fast (1.5x)')),
            ],
          ),
        ],
      ),
    );
  }

  // ── Pacing Prompt ──
  Widget _buildPacingPrompt(ThemeData theme) {
    final isTooSlow = _pacingStatus == PacingStatus.tooSlow;

    return Container(
      margin: const EdgeInsets.only(bottom: NVDimensions.spacingM),
      padding: const EdgeInsets.all(NVDimensions.spacingM),
      decoration: BoxDecoration(
        color: NVColors.warningAmber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(NVDimensions.radiusM),
        border: Border.all(
          color: NVColors.warningAmber.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isTooSlow
                ? Icons.hourglass_bottom_rounded
                : Icons.speed_rounded,
            color: NVColors.warningAmber,
            size: 28,
          ),
          const SizedBox(width: NVDimensions.spacingS),
          Expanded(
            child: Text(
              isTooSlow
                  ? 'Taking your time? No rush — read at your own pace!'
                  : 'Moving quickly! Make sure you understand before moving on.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: NVColors.warningAmber,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: _dismissPacingPrompt,
            icon: const Icon(Icons.close_rounded,
                color: NVColors.warningAmber, size: 20),
          ),
        ],
      ),
    );
  }

  // ── Nav bar ──
  Widget _buildNavigationBar(ThemeData theme) {
    final isFirst = _currentIndex == 0;
    final isLast = _currentIndex == _blocks.length - 1;
    final hasQuiz =
        _selectedTopic != null && _selectedTopic!.quiz.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(NVDimensions.spacingL),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: NVDimensions.buttonHeight,
              child: OutlinedButton.icon(
                onPressed: isFirst ? null : _previousBlock,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NVColors.textSecondary,
                  side: BorderSide(
                    color: isFirst
                        ? NVColors.cardBorder
                        : NVColors.textSecondary
                            .withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(NVDimensions.radiusM),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: NVDimensions.spacingM),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: NVDimensions.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: _nextBlock,
                icon: Icon(isLast
                    ? (hasQuiz
                        ? Icons.quiz_rounded
                        : Icons.check_circle_rounded)
                    : Icons.arrow_forward_rounded),
                label: Text(isLast
                    ? (hasQuiz ? 'Take Quiz!' : 'Complete!')
                    : 'Next Block'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLast
                      ? (hasQuiz
                          ? NVColors.primaryPurple
                          : NVColors.primaryGreen)
                      : NVColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(NVDimensions.radiusM),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  //  QUIZ VIEW
  // ========================================

  Widget _buildQuizView(ThemeData theme) {
    if (_selectedTopic == null || _selectedTopic!.quiz.isEmpty) {
      return const Center(child: Text('No quiz available'));
    }

    final quiz = _selectedTopic!.quiz;
    final question = quiz[_quizIndex];
    final progress = (_quizIndex + 1) / quiz.length;
    final selectedAnswer = _quizAnswers[_quizIndex];

    return Column(
      children: [
        // Progress
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NVDimensions.spacingL,
            vertical: NVDimensions.spacingS,
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(NVDimensions.radiusS),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: NVColors.surfaceElevated,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      NVColors.primaryPurple),
                ),
              ),
              const SizedBox(height: NVDimensions.spacingXS),
              Text(
                'Question ${_quizIndex + 1} of ${quiz.length}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: NVColors.textSecondary),
              ),
            ],
          ),
        ),

        // Question
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(NVDimensions.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question card
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(NVDimensions.spacingXL),
                  decoration: BoxDecoration(
                    color: NVColors.surface,
                    borderRadius:
                        BorderRadius.circular(NVDimensions.radiusL),
                    border: Border.all(
                      color: NVColors.primaryPurple
                          .withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: NVDimensions.spacingS,
                          vertical: NVDimensions.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color: NVColors.primaryPurple
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                              NVDimensions.radiusS),
                        ),
                        child: Text(
                          'QUESTION ${_quizIndex + 1}',
                          style: TextStyle(
                            color: NVColors.primaryPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: NVDimensions.spacingL),
                      Text(
                        question.question,
                        style: theme.textTheme.titleLarge?.copyWith(
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: NVDimensions.spacingL),

                // Options
                ...question.options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final isSelected = selectedAnswer == index;
                  final isCorrect =
                      index == question.correctIndex;
                  final showResult = selectedAnswer != null;

                  Color borderColor = NVColors.cardBorder;
                  Color bgColor = NVColors.surface;
                  Color textColor = NVColors.textPrimary;
                  IconData? trailingIcon;

                  if (showResult && isSelected) {
                    if (isCorrect) {
                      borderColor = NVColors.primaryGreen;
                      bgColor = NVColors.primaryGreen
                          .withValues(alpha: 0.1);
                      textColor = NVColors.primaryGreen;
                      trailingIcon = Icons.check_circle_rounded;
                    } else {
                      borderColor = NVColors.primaryRed;
                      bgColor =
                          NVColors.primaryRed.withValues(alpha: 0.1);
                      textColor = NVColors.primaryRed;
                      trailingIcon = Icons.cancel_rounded;
                    }
                  } else if (showResult && isCorrect) {
                    borderColor = NVColors.primaryGreen;
                    bgColor = NVColors.primaryGreen
                        .withValues(alpha: 0.1);
                    textColor = NVColors.primaryGreen;
                    trailingIcon = Icons.check_circle_rounded;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(
                        bottom: NVDimensions.spacingS),
                    child: Material(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(
                          NVDimensions.radiusM),
                      child: InkWell(
                        onTap: selectedAnswer == null
                            ? () => _selectQuizAnswer(index)
                            : null,
                        borderRadius: BorderRadius.circular(
                            NVDimensions.radiusM),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(
                              NVDimensions.spacingM),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                NVDimensions.radiusM),
                            border:
                                Border.all(color: borderColor, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? borderColor
                                          .withValues(alpha: 0.2)
                                      : NVColors.surfaceElevated,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  String.fromCharCode(65 + index),
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                  width: NVDimensions.spacingM),
                              Expanded(
                                child: Text(
                                  option,
                                  style: theme.textTheme.bodyLarge
                                      ?.copyWith(
                                    color: textColor,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (trailingIcon != null)
                                Icon(trailingIcon,
                                    color: borderColor, size: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Read question aloud button
                const SizedBox(height: NVDimensions.spacingM),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      _logic.speakText(
                        '${question.question}. ${question.options.asMap().entries.map((e) => 'Option ${String.fromCharCode(65 + e.key)}: ${e.value}').join('. ')}',
                      );
                    },
                    icon: const Icon(Icons.volume_up_rounded,
                        color: NVColors.primaryBlue),
                    label: const Text('Read Question Aloud',
                        style:
                            TextStyle(color: NVColors.primaryBlue)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleVoiceCommand(String command, SessionController session) {
    debugPrint('Learning Page Voice Command Received: $command');
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
    if (await canLaunchUrl(navUri)) {
      await launchUrl(navUri);
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Private Widgets
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Card for difficulty level selection
class _DifficultyCard extends StatelessWidget {
  final DifficultyLevel level;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final int topicCount;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.level,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.topicCount,
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
          splashColor: color.withValues(alpha: 0.1),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(NVDimensions.spacingL),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(NVDimensions.radiusL),
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: NVColors.textSecondary,
                          )),
                      const SizedBox(height: 4),
                      Text(description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: NVColors.textMuted,
                            fontSize: 13,
                          )),
                      const SizedBox(height: 6),
                      Text('$topicCount topics',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: color, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card for topic selection
class _TopicCard extends StatelessWidget {
  final LearningTopic topic;
  final VoidCallback onTap;

  const _TopicCard({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Learn about ${topic.title}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: NVDimensions.spacingM),
        child: Material(
          color: NVColors.surface,
          borderRadius:
              BorderRadius.circular(NVDimensions.radiusL),
          child: InkWell(
            onTap: onTap,
            borderRadius:
                BorderRadius.circular(NVDimensions.radiusL),
            splashColor:
                NVColors.learningAccent.withValues(alpha: 0.1),
            child: Container(
              padding:
                  const EdgeInsets.all(NVDimensions.spacingL),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(NVDimensions.radiusL),
                border:
                    Border.all(color: NVColors.cardBorder),
              ),
              child: Row(
                children: [
                  // Emoji icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: NVColors.learningAccent
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                          NVDimensions.radiusM),
                    ),
                    alignment: Alignment.center,
                    child: Text(topic.emoji,
                        style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: NVDimensions.spacingM),

                  // Title and description
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(topic.title,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(
                                    fontWeight:
                                        FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(topic.description,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(
                                    color: NVColors
                                        .textSecondary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                                '${topic.lessons.length} lessons',
                                style: theme
                                    .textTheme.bodySmall
                                    ?.copyWith(
                                        color: NVColors
                                            .textMuted)),
                            if (topic.quiz.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: NVColors.primaryPurple
                                      .withValues(
                                          alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(
                                          4),
                                ),
                                child: Text(
                                  '${topic.quiz.length} quiz',
                                  style: const TextStyle(
                                    color:
                                        NVColors.primaryPurple,
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Arrow
                  const Icon(Icons.chevron_right_rounded,
                      color: NVColors.learningAccent,
                      size: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stat row for completion dialog
class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium)),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
                  color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
