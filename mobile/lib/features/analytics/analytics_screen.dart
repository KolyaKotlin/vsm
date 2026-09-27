import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/insights.dart';
import '../../domain/profile.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/railway.dart';

/// Аналитика смен: тренд, компетенции, типы ситуаций и следующий шаг.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile;
    final report = TrainingReport.build(profile, scenarios: state.scenarios);

    return Scaffold(
      appBar: AppBar(title: const Text('Аналитика смены')),
      body: CabinBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            VsmSpacing.screenPadding,
            8,
            VsmSpacing.screenPadding,
            28,
          ),
          children: [
            GlassCard(
              accent: VsmColors.brass,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.headline,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.summary,
                    style: const TextStyle(
                      height: 1.45,
                      color: VsmColors.textSecondary,
                    ),
                  ),
                  if (profile.runs.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _Stat(
                          label: 'Средний',
                          value: '${report.averageScore}',
                        ),
                        _Stat(
                          label: 'Последний',
                          value: '${report.latestScore}',
                        ),
                        _Stat(label: 'Лучший', value: '${report.bestScore}'),
                        _Stat(label: 'Тренд', value: report.trendLabel),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (report.nextStep != null) ...[
              const SizedBox(height: 12),
              GlassCard(
                accent: VsmColors.brand,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Что делать дальше'),
                    Text(
                      report.nextStep!,
                      style: const TextStyle(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
            if (report.competencies.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SectionHeader(title: 'Компетенции'),
              GlassCard(
                child: Column(
                  children: [
                    for (final read in report.competencies) ...[
                      _CompetencyLine(
                        read: read,
                        ceiling: state.competencyCeiling,
                      ),
                      if (read != report.competencies.last)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ],
            if (report.categories.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SectionHeader(title: 'По типу ситуации'),
              GlassCard(
                child: Column(
                  children: [
                    for (final read in report.categories) ...[
                      _CategoryLine(read: read),
                      if (read != report.categories.last)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1),
                        ),
                    ],
                  ],
                ),
              ),
            ],
            if (report.findings.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SectionHeader(title: 'Что видно по сменам'),
              for (final finding in report.findings) ...[
                _FindingCard(finding: finding),
                const SizedBox(height: 8),
              ],
            ],
            if (profile.runs.isNotEmpty) ...[
              const SizedBox(height: 8),
              const SectionHeader(title: 'По сменам'),
              for (final run in profile.runs.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RunLine(run: run),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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

class _CompetencyLine extends StatelessWidget {
  const _CompetencyLine({required this.read, required this.ceiling});

  final CompetencyRead read;
  final int ceiling;

  @override
  Widget build(BuildContext context) {
    final tone = switch (read.standing) {
      CompetencyStanding.strong => VsmColors.success,
      CompetencyStanding.weak => VsmColors.danger,
      CompetencyStanding.quiet => VsmColors.textMuted,
      CompetencyStanding.steady => VsmColors.loyalty,
    };
    final standing = switch (read.standing) {
      CompetencyStanding.strong => 'держится',
      CompetencyStanding.weak => 'проседает',
      CompetencyStanding.quiet => 'нет данных',
      CompetencyStanding.steady => 'ровно',
    };
    final fraction = ceiling == 0
        ? 0.0
        : (read.points / ceiling).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(read.competency.icon, size: 16, color: tone),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                read.competency.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(standing, style: TextStyle(fontSize: 12, color: tone)),
            const SizedBox(width: 8),
            Text(
              '${read.points}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 4,
            backgroundColor: VsmColors.stroke,
            color: tone,
          ),
        ),
      ],
    );
  }
}

class _CategoryLine extends StatelessWidget {
  const _CategoryLine({required this.read});

  final CategoryRead read;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                read.category.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${read.attempts} ${_attempts(read.attempts)} · лучший ${read.best}',
                style: const TextStyle(
                  fontSize: 12,
                  color: VsmColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${read.average}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  static String _attempts(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'попытка';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'попытки';
    }
    return 'попыток';
  }
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final color = switch (finding.tone) {
      FindingTone.good => VsmColors.success,
      FindingTone.attention => VsmColors.brand,
      FindingTone.note => VsmColors.brass,
    };
    return GlassCard(
      accent: color,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            finding.title,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 4),
          Text(finding.text, style: const TextStyle(height: 1.4)),
        ],
      ),
    );
  }
}

class _RunLine extends StatelessWidget {
  const _RunLine({required this.run});

  final RunSummary run;

  @override
  Widget build(BuildContext context) {
    final ratingNote = run.confirmed ? 'в рейтинге' : 'ждут подтверждения';
    final cycle = run.roleCycleClosed ? 'цикл закрыт' : 'цикл не закрыт';
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            run.scenarioTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Итог ${run.score} · лояльность ${run.loyalty} · '
            'безопасность ${run.safety}',
            style: const TextStyle(
              fontSize: 12,
              color: VsmColors.textSecondary,
            ),
          ),
          Text(
            '+${run.xp} XP · $ratingNote · $cycle',
            style: const TextStyle(fontSize: 12, color: VsmColors.textMuted),
          ),
        ],
      ),
    );
  }
}
