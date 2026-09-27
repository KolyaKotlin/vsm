import 'package:flutter/material.dart';

import '../domain/achievement.dart';
import '../domain/competency.dart';
import '../domain/profile.dart';
import '../domain/scenario.dart';

enum NotificationKind {
  newScenario('Новый сценарий', Icons.new_releases_rounded),
  challenge('Челлендж', Icons.flag_rounded),
  expiringPoints('Сгорающие баллы', Icons.hourglass_bottom_rounded),
  competencyGap('Пробел в компетенциях', Icons.trending_down_rounded),
  achievement('Достижение', Icons.emoji_events_rounded);

  const NotificationKind(this.label, this.icon);

  final String label;
  final IconData icon;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.scenarioId,
    this.deadline,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;

  /// Если задан — по нажатию открываем сценарий.
  final String? scenarioId;

  /// Для челленджей и сгорающих баллов.
  final DateTime? deadline;

  String? get deadlineLabel {
    if (deadline == null) return null;
    final left = deadline!.difference(DateTime.now());
    if (left.isNegative) return 'срок истёк';
    if (left.inHours < 24) return 'осталось ${left.inHours} ч';
    return 'осталось ${left.inDays} дн';
  }
}

/// Генератор уведомлений.
///
/// Уведомления не лежат готовым списком, а выводятся из состояния профиля:
/// какие сценарии не пройдены, какая компетенция отстаёт, сколько баллов ждёт
/// подтверждения. Поэтому лента живая — она меняется после каждого
/// прохождения, а не показывает одни и те же заготовки.
class NotificationCenter {
  const NotificationCenter();

  /// Баллы, начисленные за последние сутки, считаются неподтверждёнными и
  /// «сгорают», если проводник не закрепит их ещё одним прохождением.
  /// Механика взята из требования ТЗ об оповещении о сгорающих баллах.
  static const pendingPointsWindow = Duration(days: 3);

  List<AppNotification> build({
    required ConductorProfile profile,
    required List<Scenario> scenarios,
  }) {
    final notifications = <AppNotification>[];
    final completed = profile.completedScenarioIds;

    // 1. Непройденные сценарии.
    for (final scenario in scenarios) {
      if (completed.contains(scenario.id)) continue;
      notifications.add(
        AppNotification(
          id: 'new_scenario_${scenario.id}',
          kind: NotificationKind.newScenario,
          title: scenario.title,
          body:
              '${scenario.category.label} · сложность ${scenario.difficulty} '
              '· ${scenario.summary}',
          scenarioId: scenario.id,
        ),
      );
    }

    // 2. Челлендж: закрыть сложный сценарий на высокий результат.
    final hardScenario = scenarios
        .where((s) => s.difficulty >= 3)
        .cast<Scenario?>()
        .firstWhere(
          (s) => (profile.runs
              .where((run) => run.scenarioId == s!.id && run.score >= 80)
              .isEmpty),
          orElse: () => null,
        );
    if (hardScenario != null) {
      notifications.add(
        AppNotification(
          id: 'challenge_${hardScenario.id}',
          kind: NotificationKind.challenge,
          title: 'Челлендж недели',
          body:
              'Закройте «${hardScenario.title}» с итогом 80+ '
              'и получите двойной опыт.',
          scenarioId: hardScenario.id,
          deadline: DateTime.now().add(const Duration(days: 4)),
        ),
      );
    }

    // 3. Сгорающие баллы: опыт, набранный недавно и не закреплённый.
    final pending = _pendingXp(profile);
    if (pending > 0) {
      notifications.add(
        AppNotification(
          id: 'expiring_$pending',
          kind: NotificationKind.expiringPoints,
          title: '$pending очков ждут подтверждения',
          body:
              'Пройдите любой сценарий в ближайшие трое суток, чтобы закрепить '
              'баллы. Иначе они сгорят и пропадут из рейтинга бригады.',
          deadline: _pendingDeadline(profile),
        ),
      );
    }

    if (profile.expiredXp > 0) {
      notifications.add(
        AppNotification(
          id: 'burned_${profile.expiredXp}',
          kind: NotificationKind.expiringPoints,
          title: '${profile.expiredXp} очков сгорели',
          body:
              'Их не закрепили новой сменой. В рейтинг бригады они больше '
              'не входят, уровень при этом сохраняется.',
        ),
      );
    }

    // 4. Проседающая компетенция.
    final gap = weakestCompetency(profile);
    if (gap != null) {
      final scenario = scenarios
          .where((s) => s.trainedCompetencies.contains(gap))
          .cast<Scenario?>()
          .firstWhere((_) => true, orElse: () => null);
      notifications.add(
        AppNotification(
          id: 'gap_${gap.id}',
          kind: NotificationKind.competencyGap,
          title: 'Компетенция «${gap.label}» отстаёт',
          body: scenario == null
              ? 'По этой компетенции у вас меньше всего очков.'
              : 'Подтяните её на сценарии «${scenario.title}».',
          scenarioId: scenario?.id,
        ),
      );
    }

    // 5. Ачивка, до которой остался один шаг.
    final nextAchievement = AchievementCatalog.all
        .where((a) => !profile.unlockedAchievements.contains(a.id))
        .cast<Achievement?>()
        .firstWhere((_) => true, orElse: () => null);
    if (nextAchievement != null && profile.completedCount > 0) {
      notifications.add(
        AppNotification(
          id: 'achievement_${nextAchievement.id}',
          kind: NotificationKind.achievement,
          title: 'Достижение рядом: «${nextAchievement.title}»',
          body: nextAchievement.description,
        ),
      );
    }

    return notifications;
  }

  /// Опыт, который ещё не закреплён следующей сменой.
  int _pendingXp(ConductorProfile profile) => profile.pendingXp;

  DateTime? _pendingDeadline(ConductorProfile profile) {
    final threshold = DateTime.now().subtract(pendingPointsWindow);
    final recent = profile.runs.where((r) => r.finishedAt.isAfter(threshold));
    if (recent.isEmpty) return null;
    final earliest = recent
        .map((r) => r.finishedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return earliest.add(pendingPointsWindow);
  }

  /// Компетенция с наименьшим числом очков — основа аналитики пробелов.
  static Competency? weakestCompetency(ConductorProfile profile) {
    if (profile.runs.isEmpty) return null;
    Competency? weakest;
    var minPoints = 1 << 30;
    for (final competency in Competency.values) {
      final points = profile.competencyPoints[competency] ?? 0;
      if (points < minPoints) {
        minPoints = points;
        weakest = competency;
      }
    }
    return weakest;
  }
}
