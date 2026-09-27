import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/achievement.dart';
import '../../domain/profile.dart';
import '../../state/app_state.dart';
import '../analytics/analytics_screen.dart';
import '../../widgets/cabin_window.dart';
import '../../widgets/common.dart';
import '../../widgets/railway.dart';
import '../../widgets/competency_radar.dart';
import '../../widgets/dual_gauge.dart';

/// Профиль проводника: уровень, компетенции, ачивки и история смен.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile;
    final weakest = state.weakestCompetency;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          VsmSpacing.screenPadding,
          12,
          VsmSpacing.screenPadding,
          28,
        ),
        children: [
          const SectionHeader(title: 'Профиль проводника'),
          _IdentityCard(profile: profile),
          const SizedBox(height: 12),
          GlassCard(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
            child: const Row(
              children: [
                Icon(Icons.insights_rounded, color: VsmColors.brand),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Аналитика компетенций',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Что уже держится и где пробел',
                        style: TextStyle(
                          fontSize: 12,
                          color: VsmColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: VsmColors.textMuted),
              ],
            ),
          ),
          if (profile.pendingXp > 0) ...[
            const SizedBox(height: 12),
            GlassCard(
              accent: VsmColors.loyalty,
              child: Text(
                '${profile.pendingXp} очков ещё не в рейтинге. '
                'Следующая смена в течение 3 суток их закрепит, иначе они сгорят.',
                style: const TextStyle(height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                const SectionHeader(title: 'Средние шкалы'),
                DualGauge(
                  loyalty: profile.completedCount == 0
                      ? 0
                      : profile.averageLoyalty,
                  safety: profile.completedCount == 0
                      ? 0
                      : profile.averageSafety,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                const SectionHeader(title: 'Компетенции'),
                CompetencyRadar(
                  points: profile.competencyPoints,
                  ceiling: state.competencyCeiling,
                  weakest: weakest,
                  size: 280,
                ),
                if (weakest != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Проседает «${weakest.label}» — берите сценарии, '
                    'где эта компетенция тренируется.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: VsmColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Достижения'),
          _AchievementsGrid(profile: profile),
          const SizedBox(height: 20),
          SectionHeader(
            title: 'История смен',
            trailing: Text(
              '${profile.completedCount}',
              style: const TextStyle(fontSize: 11, color: VsmColors.textMuted),
            ),
          ),
          if (profile.runs.isEmpty)
            const GlassCard(
              child: Text(
                'Пока нет прохождений. Закройте первый сценарий — здесь '
                'появится история и аналитика компетенций.',
                style: TextStyle(color: VsmColors.textSecondary, height: 1.45),
              ),
            )
          else
            for (final run in profile.runs.reversed.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RunTile(run: run),
              ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _confirmReset(context),
            child: const Text('Сбросить прогресс'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: cabinBarrier,
      builder: (context) => CabinDialog(
        plate: 'Депо',
        title: 'Сбросить прогресс?',
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VsmColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сбросить'),
          ),
        ],
        child: const Text(
          'Уровень, ачивки и история смен обнулятся. Сценарии останутся.',
          style: TextStyle(height: 1.4, color: VsmColors.textSecondary),
        ),
      ),
    );
    if (confirmed == true && context.mounted) {
      await AppScope.read(context).resetProgress();
    }
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile});

  final ConductorProfile profile;

  @override
  Widget build(BuildContext context) {
    final trimmed = profile.name.trim();
    final initial = trimmed.isEmpty
        ? 'П'
        : trimmed.substring(0, 1).toUpperCase();

    return GlassCard(
      accent: VsmColors.brand,
      child: Row(
        children: [
          PlateMark(label: initial, width: 52, height: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '${profile.rank} · уровень ${profile.level}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: VsmColors.textSecondary,
                  ),
                ),
                Text(
                  '${profile.brigade} · ${profile.depot}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: VsmColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _editIdentity(context, profile),
            icon: const Icon(Icons.edit_outlined, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: VsmColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editIdentity(
    BuildContext context,
    ConductorProfile profile,
  ) async {
    final name = TextEditingController(text: profile.name);
    final brigade = TextEditingController(text: profile.brigade);
    final depot = TextEditingController(text: profile.depot);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: cabinBarrier,
      builder: (context) {
        return CabinSheet(
          plate: 'Бригада',
          title: 'Игровой профиль',
          subtitle:
              'Синтетическое имя. Реальные персональные данные '
              'сотрудников в демо не используются.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Имя'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: brigade,
                decoration: const InputDecoration(labelText: 'Бригада'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: depot,
                decoration: const InputDecoration(labelText: 'Депо'),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Сохранить'),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true && context.mounted) {
      await AppScope.read(context).updateIdentity(
        name: name.text.trim().isEmpty ? profile.name : name.text.trim(),
        brigade: brigade.text.trim().isEmpty
            ? profile.brigade
            : brigade.text.trim(),
        depot: depot.text.trim().isEmpty ? profile.depot : depot.text.trim(),
      );
    }
    name.dispose();
    brigade.dispose();
    depot.dispose();
  }
}

class _AchievementsGrid extends StatelessWidget {
  const _AchievementsGrid({required this.profile});

  final ConductorProfile profile;

  @override
  Widget build(BuildContext context) {
    final achievements = AchievementCatalog.all;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: achievements.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 112,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        return _AchievementTile(
          achievement: achievement,
          unlocked: profile.unlockedAchievements.contains(achievement.id),
        );
      },
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.unlocked});

  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? VsmColors.loyalty : VsmColors.textMuted;

    return GlassCard(
      accent: unlocked ? VsmColors.loyalty : null,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        children: [
          Icon(achievement.icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: unlocked ? VsmColors.textPrimary : VsmColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.run});

  final RunSummary run;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: VsmColors.brand.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${run.score}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: VsmColors.brand,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  run.scenarioTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Лояльность ${run.loyalty} · безопасность ${run.safety} · +${run.xp} XP',
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
    );
  }
}
