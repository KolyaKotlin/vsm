import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/scenario.dart';
import '../../widgets/common.dart';
import '../../widgets/dual_gauge.dart';
import '../../widgets/railway.dart';
import '../player/scenario_player_screen.dart';

/// Брифинг перед сценарием: обстановка, стартовые шкалы, напоминание о
/// ролевой модели. Проводник должен входить в ситуацию подготовленным — так же,
/// как перед реальной сменой.
class ScenarioBriefingScreen extends StatelessWidget {
  const ScenarioBriefingScreen({super.key, required this.scenario});

  final Scenario scenario;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CabinBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              VsmSpacing.screenPadding,
              4,
              VsmSpacing.screenPadding,
              24,
            ),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Перед выходом в салон',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Ситуация'),
                    Text(
                      scenario.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      scenario.summary,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: VsmColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Стартовые шкалы'),
                    DualGauge(
                      loyalty: scenario.initialLoyalty,
                      safety: scenario.initialSafety,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Обе шкалы двигаются независимо. Решение, которое нравится '
                      'пассажиру, может снижать безопасность — и наоборот.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: VsmColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _RoleModelCard(),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Тренируемые компетенции'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final competency in scenario.trainedCompetencies)
                          VsmChip(
                            label: competency.label,
                            icon: competency.icon,
                            color: VsmColors.textSecondary,
                            filled: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 13,
                          color: VsmColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            scenario.source,
                            style: const TextStyle(
                              fontSize: 11,
                              color: VsmColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (scenario.timedSceneCount > 0) ...[
                const SizedBox(height: 12),
                GlassCard(
                  accent: VsmColors.loyalty,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_rounded,
                        color: VsmColors.loyalty,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'В сценарии ${scenario.timedSceneCount} критических '
                          'решения на таймере. Если не успеть, ситуация развивается '
                          'сама — и не в вашу пользу.',
                          style: const TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ScenarioPlayerScreen(scenario: scenario),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Выйти в салон'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Напоминание о четырёх шагах ролевой модели.
class _RoleModelCard extends StatelessWidget {
  const _RoleModelCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Ролевая модель'),
          for (var i = 0; i < RoleStep.canonicalOrder.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == RoleStep.canonicalOrder.length - 1 ? 0 : 10,
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: VsmColors.brand.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: VsmColors.brand,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    RoleStep.canonicalOrder[i].label,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            'Порядок важен. Правило, озвученное до признания ситуации, '
            'воспринимается как выговор и снижает лояльность даже при '
            'дословно верной формулировке.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: VsmColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
