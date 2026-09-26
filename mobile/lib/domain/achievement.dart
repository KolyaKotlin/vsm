import 'package:flutter/material.dart';

import 'competency.dart';
import 'profile.dart';

/// Достижение проводника.
///
/// Условие выдачи — обычная функция от профиля. Добавить новую ачивку значит
/// дописать одну запись в [AchievementCatalog.all]; ядро при этом не меняется.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlockedBy,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool Function(ConductorProfile profile) isUnlockedBy;
}

abstract final class AchievementCatalog {
  static final all = <Achievement>[
    Achievement(
      id: 'first_shift',
      title: 'Первая смена',
      description: 'Пройден первый сценарий',
      icon: Icons.play_circle_rounded,
      isUnlockedBy: (profile) => profile.completedCount >= 1,
    ),
    Achievement(
      id: 'diplomat',
      title: 'Дипломат',
      description: 'Лояльность пассажира 85+ в любом сценарии',
      icon: Icons.handshake_rounded,
      isUnlockedBy: (profile) => profile.runs.any((run) => run.loyalty >= 85),
    ),
    Achievement(
      id: 'spotless_safety',
      title: 'Безупречная безопасность',
      description: 'Сценарий закрыт с рейтингом безопасности 100',
      icon: Icons.verified_user_rounded,
      isUnlockedBy: (profile) => profile.runs.any((run) => run.safety == 100),
    ),
    Achievement(
      id: 'keeps_the_clock',
      title: 'Держит темп',
      description: 'Три сценария подряд без просроченных таймеров',
      icon: Icons.timer_rounded,
      isUnlockedBy: (profile) {
        final recent = profile.runs.reversed.take(3).toList();
        return recent.length == 3 && recent.every((run) => run.timeoutCount == 0);
      },
    ),
    Achievement(
      id: 'clean_streak',
      title: 'Без замечаний',
      description: 'Серия из 3 прохождений без грубых ошибок',
      icon: Icons.workspace_premium_rounded,
      isUnlockedBy: (profile) => profile.cleanStreak >= 3,
    ),
    Achievement(
      id: 'empath',
      title: 'Эмпат',
      description: '25 очков компетенции «Эмпатия»',
      icon: Icons.favorite_rounded,
      isUnlockedBy: (profile) =>
          (profile.competencyPoints[Competency.empathy] ?? 0) >= 25,
    ),
    Achievement(
      id: 'regulation_keeper',
      title: 'Знает регламент',
      description: '25 очков компетенции «Регламент»',
      icon: Icons.menu_book_rounded,
      isUnlockedBy: (profile) =>
          (profile.competencyPoints[Competency.regulations] ?? 0) >= 25,
    ),
    Achievement(
      id: 'full_route',
      title: 'Полный маршрут',
      description: 'Пройдены все доступные сценарии',
      icon: Icons.route_rounded,
      isUnlockedBy: (profile) => profile.completedCount >= 5,
    ),
    Achievement(
      id: 'senior',
      title: 'Старший проводник',
      description: 'Достигнут 4 уровень',
      icon: Icons.military_tech_rounded,
      isUnlockedBy: (profile) => profile.level >= 4,
    ),
  ];

  static Achievement? byId(String id) {
    for (final achievement in all) {
      if (achievement.id == id) return achievement;
    }
    return null;
  }

  /// Ачивки, которые профиль заслужил, но ещё не получил.
  /// Вызывается после каждого прохождения — так появляется «выдача» награды.
  static List<Achievement> newlyUnlocked(ConductorProfile profile) => all
      .where((achievement) =>
          !profile.unlockedAchievements.contains(achievement.id) &&
          achievement.isUnlockedBy(profile))
      .toList(growable: false);
}
