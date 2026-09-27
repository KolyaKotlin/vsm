import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/leaderboard_repository.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Таблица лидеров: бригада / депо / компания.
///
/// Коллеги синтетические. Текущий проводник подмешивается в рейтинг
/// по накопленному опыту — цикл «действие → очки → рейтинг».
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardScope _scope = LeaderboardScope.company;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rows = state.leaderboard(_scope);
    final myIndex = rows.indexWhere((row) => row.isCurrentUser);

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
          const SectionHeader(title: 'Рейтинг проводников'),
          Text(
            'Синтетические коллеги. Реальные персональные данные '
            'сотрудников в демо не используются.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final scope in LeaderboardScope.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _ScopeTab(
                      label: scope.label,
                      selected: _scope == scope,
                      onTap: () => setState(() => _scope = scope),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (myIndex >= 0)
            GlassCard(
              accent: VsmColors.brand,
              child: Row(
                children: [
                  Text(
                    '${myIndex + 1}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: VsmColors.brand,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ваше место',
                          style: TextStyle(
                            fontSize: 12,
                            color: VsmColors.textMuted,
                          ),
                        ),
                        Text(
                          '${rows[myIndex].xp} XP · средний итог '
                          '${rows[myIndex].averageScore}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            const EmptyState(
              icon: Icons.leaderboard_outlined,
              title: 'Пока пусто',
              message: 'В этой области ещё нет проводников.',
            )
          else
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RankRow(place: i + 1, entry: rows[i]),
              ),
        ],
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? VsmColors.brand.withValues(alpha: 0.14)
          : VsmColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? VsmColors.brand : VsmColors.stroke,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? VsmColors.brand : VsmColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.place, required this.entry});

  final int place;
  final LeaderboardEntry entry;

  Color get _placeColor => switch (place) {
    1 => const Color(0xFFFFD56A),
    2 => const Color(0xFFC9D4E8),
    3 => const Color(0xFFE0A070),
    _ => VsmColors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: entry.isCurrentUser ? VsmColors.brand : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$place',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _placeColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isCurrentUser ? '${entry.name} · вы' : entry.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: entry.isCurrentUser
                        ? VsmColors.brand
                        : VsmColors.textPrimary,
                  ),
                ),
                Text(
                  '${entry.brigade} · ${entry.depot}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: VsmColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.xp}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                'итог ${entry.averageScore}',
                style: const TextStyle(
                  fontSize: 11,
                  color: VsmColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
