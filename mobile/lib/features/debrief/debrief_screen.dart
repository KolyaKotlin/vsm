import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/achievement.dart';
import '../../domain/competency.dart';
import '../../domain/scenario.dart';
import '../../engine/scenario_engine.dart';
import '../../widgets/cabin_window.dart';
import '../../widgets/common.dart';
import '../../widgets/dual_gauge.dart';
import '../../widgets/railway.dart';
import '../player/reaction_sheet.dart';

/// Разбор смены: что произошло, почему шкалы сдвинулись, как можно было лучше.
///
/// Это главный экран по критерию «обратная связь»: не «верно/неверно», а
/// пошаговый разбор с пунктами регламента и альтернативами.
class DebriefScreen extends StatelessWidget {
  const DebriefScreen({
    super.key,
    required this.result,
    required this.unlockedAchievements,
    this.awardedXp,
    this.challengeDoubled = false,
  });

  final ScenarioResult result;
  final List<Achievement> unlockedAchievements;
  final int? awardedXp;
  final bool challengeDoubled;

  Color get _toneColor => switch (result.ending.tone) {
    'success' => VsmColors.success,
    'failure' => VsmColors.danger,
    _ => VsmColors.loyalty,
  };

  IconData get _toneIcon => switch (result.ending.tone) {
    'success' => Icons.check_circle_rounded,
    'failure' => Icons.dangerous_rounded,
    _ => Icons.info_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CabinBackground(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  VsmSpacing.screenPadding,
                  12,
                  VsmSpacing.screenPadding,
                  28,
                ),
                children: [
                  _Hero(
                    result: result,
                    toneColor: _toneColor,
                    toneIcon: _toneIcon,
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Итоговые шкалы'),
                        DualGauge(
                          loyalty: result.loyalty,
                          safety: result.safety,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _StatTile(
                              label: 'Итог',
                              value: '${result.score}',
                              color: _toneColor,
                            ),
                            _StatTile(
                              label: challengeDoubled ? 'Опыт ×2' : 'Опыт',
                              value: '+${awardedXp ?? result.xp}',
                              color: VsmColors.brand,
                            ),
                            _StatTile(
                              label: 'Ошибки',
                              value: '${result.mistakeCount}',
                              color: result.mistakeCount == 0
                                  ? VsmColors.success
                                  : VsmColors.danger,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (unlockedAchievements.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _UnlockedAchievements(achievements: unlockedAchievements),
                  ],
                  const SizedBox(height: 12),
                  _RoleTrackCard(
                    track: result.roleTrack,
                    note: result.completionJudgement.note,
                  ),
                  if (result.competencyTotals.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _CompetencyDeltaCard(totals: result.competencyTotals),
                  ],
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Разбор решений'),
                  for (var i = 0; i < result.decisions.length; i++) ...[
                    _DecisionCard(index: i + 1, record: result.decisions[i]),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).popUntil((route) => route.isFirst),
                    child: const Text('Вернуться в депо'),
                  ),
                ],
              ),
            ),
          ),
          _AchievementAnnounce(achievements: unlockedAchievements),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.result,
    required this.toneColor,
    required this.toneIcon,
  });

  final ScenarioResult result;
  final Color toneColor;
  final IconData toneIcon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: toneColor,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: toneColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(toneIcon, color: toneColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  result.ending.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            result.ending.text,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: VsmColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            result.scenario.title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: VsmColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: VsmColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Окно сразу после смены: «вы получили такое-то достижение».
class _AchievementAnnounce extends StatefulWidget {
  const _AchievementAnnounce({required this.achievements});

  final List<Achievement> achievements;

  @override
  State<_AchievementAnnounce> createState() => _AchievementAnnounceState();
}

class _AchievementAnnounceState extends State<_AchievementAnnounce> {
  @override
  void initState() {
    super.initState();
    if (widget.achievements.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final many = widget.achievements.length > 1;
      showDialog<void>(
        context: context,
        barrierColor: cabinBarrier,
        builder: (context) {
          return CabinDialog(
            plate: 'Достижение',
            title: many ? 'Вы получили достижения' : 'Вы получили достижение',
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Хорошо'),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final achievement in widget.achievements)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(achievement.icon, color: VsmColors.loyalty),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '«${achievement.title}»',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                achievement.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: VsmColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _UnlockedAchievements extends StatelessWidget {
  const _UnlockedAchievements({required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: VsmColors.loyalty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: achievements.length == 1
                ? 'Вы получили достижение'
                : 'Вы получили достижения',
          ),
          for (final achievement in achievements)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(achievement.icon, color: VsmColors.loyalty, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '«${achievement.title}»',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          achievement.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: VsmColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RoleTrackCard extends StatelessWidget {
  const _RoleTrackCard({required this.track, this.note});

  final List<RoleStep> track;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Ролевая модель'),
          Row(
            children: [
              for (var i = 0; i < RoleStep.canonicalOrder.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(height: 1.5, color: VsmColors.stroke),
                  ),
                _StepDot(
                  step: RoleStep.canonicalOrder[i],
                  done: track.contains(RoleStep.canonicalOrder[i]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final step in RoleStep.canonicalOrder)
                Expanded(
                  child: Text(
                    step.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      color: track.contains(step)
                          ? VsmColors.textPrimary
                          : VsmColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 14),
            Text(
              note!,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: VsmColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.step, required this.done});

  final RoleStep step;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done
            ? VsmColors.success.withValues(alpha: 0.18)
            : VsmColors.surfaceHigh,
        shape: BoxShape.circle,
        border: Border.all(color: done ? VsmColors.success : VsmColors.stroke),
      ),
      child: Icon(
        done ? Icons.check_rounded : Icons.remove_rounded,
        size: 14,
        color: done ? VsmColors.success : VsmColors.textMuted,
      ),
    );
  }
}

class _CompetencyDeltaCard extends StatelessWidget {
  const _CompetencyDeltaCard({required this.totals});

  final Map<Competency, int> totals;

  @override
  Widget build(BuildContext context) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Компетенции за смену'),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    entry.key.icon,
                    size: 16,
                    color: VsmColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(entry.key.label)),
                  Text(
                    '${entry.value > 0 ? '+' : ''}${entry.value}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: entry.value >= 0
                          ? VsmColors.success
                          : VsmColors.danger,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.index, required this.record});

  final int index;
  final DecisionRecord record;

  @override
  Widget build(BuildContext context) {
    final color = verdictColor(record.feedback.verdict);

    return GlassCard(
      accent: color,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Решение $index',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: VsmColors.textMuted,
                ),
              ),
              const Spacer(),
              Icon(
                verdictIcon(record.feedback.verdict),
                size: 15,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                record.wasTimeout
                    ? 'Время вышло'
                    : record.feedback.verdict.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            record.speakerName,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: VsmColors.textSecondary,
            ),
          ),
          if (record.sceneLine.trim().isNotEmpty && record.sceneLine != '…')
            Text(
              '«${record.sceneLine}»',
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: VsmColors.textSecondary,
              ),
            ),
          const SizedBox(height: 10),
          Text(
            record.actionText,
            style: const TextStyle(fontSize: 13.5, height: 1.4),
          ),
          if (record.feedback.why.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              record.feedback.why,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: VsmColors.textSecondary,
              ),
            ),
          ],
          if (record.bestAlternative != null) ...[
            const SizedBox(height: 12),
            _Note(
              label: 'Как лучше',
              text: record.bestAlternative!,
              color: VsmColors.success,
              icon: Icons.lightbulb_rounded,
            ),
          ],
          if (record.roleModelNote != null) ...[
            const SizedBox(height: 10),
            _Note(
              label: 'Ролевая модель',
              text: record.roleModelNote!,
              color: VsmColors.brand,
              icon: Icons.account_tree_rounded,
            ),
          ],
          if (record.feedback.regulation != null) ...[
            const SizedBox(height: 10),
            Text(
              record.feedback.regulation!,
              style: const TextStyle(fontSize: 11, color: VsmColors.textMuted),
            ),
          ],
          if (record.loyaltyDelta != 0 || record.safetyDelta != 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (record.loyaltyDelta != 0)
                  _Delta(label: 'Лояльность', value: record.loyaltyDelta),
                if (record.loyaltyDelta != 0 && record.safetyDelta != 0)
                  const SizedBox(width: 12),
                if (record.safetyDelta != 0)
                  _Delta(label: 'Безопасность', value: record.safetyDelta),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.label,
    required this.text,
    required this.color,
    required this.icon,
  });

  final String label;
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(fontSize: 12.5, height: 1.4)),
        ],
      ),
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final color = value > 0 ? VsmColors.success : VsmColors.danger;
    return Text(
      '$label ${value > 0 ? '+' : '−'}${value.abs()}',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
    );
  }
}
