import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/profile.dart';
import '../../domain/scenario.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/railway.dart';
import '../notifications/notifications_screen.dart';
import 'scenario_briefing_screen.dart';

/// Главный экран: смена проводника, прогресс уровня и список сценариев.
class ScenarioListScreen extends StatelessWidget {
  const ScenarioListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                VsmSpacing.screenPadding,
                8,
                VsmSpacing.screenPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(unreadCount: state.unreadNotificationCount),
                  const SizedBox(height: 16),
                  DestinationBoard(
                    subtitle: '${profile.rank} · ${profile.brigade}',
                  ),
                  const SizedBox(height: 14),
                  _ShiftCard(profile: profile),
                  const SizedBox(height: 22),
                  SectionHeader(
                    title: 'Ситуации на борту',
                    trailing: Text(
                      '${profile.completedScenarioIds.length} из '
                      '${state.scenarios.length} пройдено',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: VsmColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              VsmSpacing.screenPadding,
              0,
              VsmSpacing.screenPadding,
              28,
            ),
            sliver: SliverList.separated(
              itemCount: state.scenarios.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final scenario = state.scenarios[index];
                return _ScenarioCard(
                  scenario: scenario,
                  bestScore: _bestScore(profile, scenario.id),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ScenarioBriefingScreen(scenario: scenario),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Лучший результат по сценарию, если он уже проходился.
  int? _bestScore(ConductorProfile profile, String scenarioId) {
    final scores = profile.runs
        .where((run) => run.scenarioId == scenarioId)
        .map((run) => run.score);
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a > b ? a : b);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/logo_mark.png',
          height: 36,
          fit: BoxFit.contain,
        ),
        const Spacer(),
        _NotificationButton(unreadCount: unreadCount),
      ],
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          icon: const Icon(Icons.notifications_none_rounded),
          style: IconButton.styleFrom(
            backgroundColor: VsmColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: const BorderSide(color: VsmColors.stroke),
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: VsmColors.brand,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: VsmColors.background, width: 1.5),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Карточка смены: уровень, звание, прогресс до следующего уровня и сводка.
class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.profile});

  final ConductorProfile profile;

  @override
  Widget build(BuildContext context) {
    return TicketCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlateMark(label: '${profile.level}'),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.rank,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.brigade} · ${profile.depot}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: VsmColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                '${profile.totalXp} XP',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: VsmColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'до ${profile.level + 1} уровня '
                '${ConductorProfile.xpPerLevel - profile.xpIntoLevel} XP',
                style: const TextStyle(
                  fontSize: 11,
                  color: VsmColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: profile.levelProgress),
              duration: const Duration(milliseconds: 750),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: VsmColors.stroke,
                valueColor: const AlwaysStoppedAnimation(VsmColors.brand),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _MiniStat(
                label: 'Сценариев',
                value: '${profile.completedCount}',
                icon: Icons.play_arrow_rounded,
              ),
              _MiniStat(
                label: 'Средний итог',
                value: profile.completedCount == 0
                    ? '—'
                    : '${profile.averageScore}',
                icon: Icons.insights_rounded,
              ),
              _MiniStat(
                label: 'Ачивок',
                value: '${profile.unlockedAchievements.length}',
                icon: Icons.emoji_events_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: VsmColors.textMuted),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: VsmColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.bestScore,
    required this.onTap,
  });

  final Scenario scenario;
  final int? bestScore;
  final VoidCallback onTap;

  Color get _categoryColor => switch (scenario.category) {
    ScenarioCategory.medical => VsmColors.danger,
    ScenarioCategory.safety => VsmColors.safety,
    ScenarioCategory.conflict => VsmColors.brand,
    ScenarioCategory.boarding => VsmColors.loyalty,
    ScenarioCategory.service => VsmColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    return TicketCard(
      onTap: onTap,
      accent: _categoryColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VsmChip(
                label: scenario.category.label,
                color: _categoryColor,
                filled: true,
              ),
              const SizedBox(width: 8),
              DifficultyDots(difficulty: scenario.difficulty),
              const Spacer(),
              if (bestScore != null)
                VsmChip(
                  label: 'Лучший $bestScore',
                  icon: Icons.check_circle_rounded,
                  color: VsmColors.success,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(scenario.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(scenario.summary, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.train_rounded, size: 13, color: VsmColors.textMuted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${scenario.context.carClassLabel} · ${scenario.context.phase}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: VsmColors.textMuted,
                  ),
                ),
              ),
              if (scenario.timedSceneCount > 0)
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: VsmColors.loyalty,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${scenario.timedSceneCount} на таймере',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: VsmColors.loyalty,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
