import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/scenario.dart';
import '../../engine/scenario_engine.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/dual_gauge.dart';
import '../../widgets/timer_ring.dart';
import '../../widgets/cabin_window.dart';
import '../../widgets/railway.dart';
import '../debrief/debrief_screen.dart';
import 'reaction_sheet.dart';

/// Экран прохождения сценария.
///
/// Вся логика ветвления и подсчёта живёт в [ScenarioEngine]; этот экран только
/// рисует его состояние и ведёт обратный отсчёт. Разделение сделано специально:
/// движок можно тестировать без виджетов, а таймеру нужен `Ticker`, которого у
/// движка нет.
class ScenarioPlayerScreen extends StatefulWidget {
  const ScenarioPlayerScreen({super.key, required this.scenario});

  final Scenario scenario;

  @override
  State<ScenarioPlayerScreen> createState() => _ScenarioPlayerScreenState();
}

class _ScenarioPlayerScreenState extends State<ScenarioPlayerScreen> {
  late final ScenarioEngine _engine = ScenarioEngine(scenario: widget.scenario);

  Timer? _ticker;
  int _secondsLeft = 0;

  /// Пока показывается реакция на предыдущий выбор, варианты заблокированы.
  DecisionRecord? _pendingReaction;

  @override
  void initState() {
    super.initState();
    _engine.addListener(_onEngineChanged);
    _startTimerIfNeeded();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    super.dispose();
  }

  void _onEngineChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// Запускает обратный отсчёт, если текущая сцена — критическое решение.
  void _startTimerIfNeeded() {
    _ticker?.cancel();
    final scene = _engine.currentScene;
    if (!scene.hasTimer || _engine.isFinished) {
      _secondsLeft = 0;
      return;
    }

    _secondsLeft = scene.timerSeconds!;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _ticker?.cancel();
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    _engine.registerTimeout();
    _showReactionForLastDecision();
  }

  void _handleChoice(Choice choice) {
    if (_pendingReaction != null) return;
    _ticker?.cancel();
    _engine.choose(choice, secondsLeft: _secondsLeft);
    _showReactionForLastDecision();
  }

  void _showReactionForLastDecision() {
    final decisions = _engine.decisions;
    if (decisions.isEmpty) return;
    setState(() => _pendingReaction = decisions.last);
  }

  /// Закрывает карточку реакции и переходит к следующей сцене либо к разбору.
  void _continueAfterReaction() {
    setState(() => _pendingReaction = null);

    final result = _engine.result;
    if (result != null) {
      _finish(result);
      return;
    }
    _startTimerIfNeeded();
  }

  Future<void> _finish(ScenarioResult result) async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    final outcome = await state.commitResult(result);
    if (!mounted) return;

    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => DebriefScreen(
          result: result,
          unlockedAchievements: outcome.unlocked,
          awardedXp: outcome.awardedXp,
          challengeDoubled: outcome.challengeDoubled,
        ),
      ),
    );
  }

  Future<bool> _confirmExit() async {
    if (_engine.decisions.isEmpty) return true;

    final leave = await showDialog<bool>(
      context: context,
      barrierColor: cabinBarrier,
      builder: (context) => CabinDialog(
        plate: 'Смена',
        title: 'Прервать сценарий?',
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VsmColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Прервать'),
          ),
        ],
        child: const Text(
          'Прогресс по этой ситуации не сохранится — очки начисляются только '
          'за завершённый сценарий.',
          style: TextStyle(height: 1.4, color: VsmColors.textSecondary),
        ),
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final scene = _engine.currentScene;
    final reaction = _pendingReaction;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmExit() && mounted) navigator.pop();
      },
      child: Scaffold(
        body: CabinBackground(
          child: SafeArea(
            child: Column(
              children: [
                _PlayerHeader(
                  scenario: widget.scenario,
                  engine: _engine,
                  lastRecord: reaction,
                  onExit: () async {
                    final navigator = Navigator.of(context);
                    if (await _confirmExit() && mounted) navigator.pop();
                  },
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      VsmSpacing.screenPadding,
                      4,
                      VsmSpacing.screenPadding,
                      24,
                    ),
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.04),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(scene.id),
                          child: _SceneCard(
                            scene: scene,
                            secondsLeft: _secondsLeft,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (reaction == null)
                        _ChoiceList(
                          choices: _engine.availableChoices,
                          onSelected: _handleChoice,
                        ),
                    ],
                  ),
                ),
                if (reaction != null)
                  ReactionSheet(
                    record: reaction,
                    isFinal: _engine.isFinished,
                    onContinue: _continueAfterReaction,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Шапка: выход, прогресс, обе шкалы.
class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({
    required this.scenario,
    required this.engine,
    required this.lastRecord,
    required this.onExit,
  });

  final Scenario scenario;
  final ScenarioEngine engine;
  final DecisionRecord? lastRecord;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: VsmColors.surface,
        border: Border(bottom: BorderSide(color: VsmColors.stroke)),
      ),
      child: Column(
        children: [
          Container(height: 4, color: VsmColors.brand),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              6,
              VsmSpacing.screenPadding,
              14,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: onExit,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scenario.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${scenario.context.train} · ${scenario.context.carClassLabel}'
                            ' · вагон, решение ${engine.stepNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: VsmColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DualGauge(
                  loyalty: engine.loyalty,
                  safety: engine.safety,
                  loyaltyDelta: lastRecord?.loyaltyDelta,
                  safetyDelta: lastRecord?.safetyDelta,
                  compact: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка сцены: ремарка, говорящий, реплика и таймер.
class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.scene, required this.secondsLeft});

  final Scene scene;
  final int secondsLeft;

  Color get _moodColor => switch (scene.speaker.mood) {
    'angry' => VsmColors.danger,
    'tense' => VsmColors.loyalty,
    'weak' => VsmColors.brand,
    'calm' => VsmColors.safety,
    _ => VsmColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (scene.narration != null) ...[
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  size: 15,
                  color: VsmColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    scene.narration!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      fontStyle: FontStyle.italic,
                      color: VsmColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        GlassCard(
          accent: _moodColor,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _moodColor.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _moodColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: 19,
                      color: _moodColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scene.speaker.name,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (scene.speaker.note != null)
                          Text(
                            scene.speaker.note!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: VsmColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (scene.hasTimer)
                    TimerRing(
                      secondsLeft: secondsLeft,
                      totalSeconds: scene.timerSeconds!,
                      size: 58,
                    ),
                ],
              ),
              if (scene.line.trim().isNotEmpty && scene.line != '…') ...[
                const SizedBox(height: 16),
                Text(
                  '«${scene.line}»',
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (scene.hasTimer) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                size: 14,
                color: VsmColors.loyalty,
              ),
              const SizedBox(width: 6),
              Text(
                'Критическое решение. Промедление меняет исход.',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: VsmColors.loyalty.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChoiceList extends StatelessWidget {
  const _ChoiceList({required this.choices, required this.onSelected});

  final List<Choice> choices;
  final ValueChanged<Choice> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Ваше действие'),
        for (var i = 0; i < choices.length; i++) ...[
          _ChoiceCard(
            index: i + 1,
            choice: choices[i],
            onTap: () => onSelected(choices[i]),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.index,
    required this.choice,
    required this.onTap,
  });

  final int index;
  final Choice choice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: VsmColors.surfaceHigh,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: VsmColors.stroke),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: VsmColors.brand,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                choice.text,
                style: const TextStyle(fontSize: 15, height: 1.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
