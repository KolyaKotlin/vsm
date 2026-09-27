import 'competency.dart';

/// Краткая запись о пройденном сценарии.
///
/// Полный лог решений не храним: для аналитики прогресса достаточно итогов, а
/// профиль остаётся компактным.
class RunSummary {
  const RunSummary({
    required this.scenarioId,
    required this.scenarioTitle,
    required this.loyalty,
    required this.safety,
    required this.xp,
    required this.competencyDelta,
    required this.mistakeCount,
    required this.timeoutCount,
    required this.finishedAt,
    this.confirmed = false,
    this.category = '',
    this.roleCycleClosed = false,
  });

  final String scenarioId;
  final String scenarioTitle;
  final int loyalty;
  final int safety;
  final int xp;
  final Map<Competency, int> competencyDelta;
  final int mistakeCount;
  final int timeoutCount;
  final DateTime finishedAt;

  /// Неподтверждённые очки сгорают для рейтинга, если за окно не было новой смены.
  final bool confirmed;
  final String category;
  final bool roleCycleClosed;

  RunSummary confirm() => RunSummary(
    scenarioId: scenarioId,
    scenarioTitle: scenarioTitle,
    loyalty: loyalty,
    safety: safety,
    xp: xp,
    competencyDelta: competencyDelta,
    mistakeCount: mistakeCount,
    timeoutCount: timeoutCount,
    finishedAt: finishedAt,
    confirmed: true,
    category: category,
    roleCycleClosed: roleCycleClosed,
  );

  int get score => ((loyalty + safety) / 2).round();

  Map<String, Object?> toJson() => {
    'scenarioId': scenarioId,
    'scenarioTitle': scenarioTitle,
    'loyalty': loyalty,
    'safety': safety,
    'xp': xp,
    'competencyDelta': {
      for (final entry in competencyDelta.entries) entry.key.id: entry.value,
    },
    'mistakeCount': mistakeCount,
    'timeoutCount': timeoutCount,
    'finishedAt': finishedAt.toIso8601String(),
    'confirmed': confirmed,
    'category': category,
    'roleCycleClosed': roleCycleClosed,
  };

  factory RunSummary.fromJson(Map<String, Object?> json) => RunSummary(
    scenarioId: json['scenarioId'] as String,
    scenarioTitle: json['scenarioTitle'] as String? ?? '',
    loyalty: (json['loyalty'] as num?)?.round() ?? 0,
    safety: (json['safety'] as num?)?.round() ?? 0,
    xp: (json['xp'] as num?)?.round() ?? 0,
    competencyDelta: Competency.parseMap(json['competencyDelta']),
    mistakeCount: (json['mistakeCount'] as num?)?.round() ?? 0,
    timeoutCount: (json['timeoutCount'] as num?)?.round() ?? 0,
    finishedAt:
        DateTime.tryParse(json['finishedAt'] as String? ?? '') ??
        DateTime.now(),
    confirmed: json['confirmed'] as bool? ?? true,
    category: json['category'] as String? ?? '',
    roleCycleClosed: json['roleCycleClosed'] as bool? ?? false,
  );
}

/// Игровой профиль проводника.
///
/// Все данные синтетические: реальные ПДн сотрудников в демо-среде не
/// используются (152-ФЗ). Профиль создаётся локально при первом запуске.
class ConductorProfile {
  const ConductorProfile({
    required this.name,
    required this.brigade,
    required this.depot,
    required this.competencyPoints,
    required this.runs,
    required this.unlockedAchievements,
    required this.seenNotificationIds,
    this.created = false,
  });

  final String name;
  final String brigade;
  final String depot;

  /// Накопленные очки по каждой компетенции.
  final Map<Competency, int> competencyPoints;
  final List<RunSummary> runs;
  final Set<String> unlockedAchievements;
  final Set<String> seenNotificationIds;

  /// Профиль ещё не создан проводником — показываем экран регистрации.
  final bool created;

  /// Окно, после которого неподтверждённые очки выпадают из рейтинга.
  static const pendingWindow = Duration(days: 3);

  factory ConductorProfile.initial() => const ConductorProfile(
    name: 'Проводник А. Смирнов',
    brigade: 'Бригада №4',
    depot: 'Депо Москва-Октябрьская',
    competencyPoints: {},
    runs: [],
    unlockedAchievements: {},
    seenNotificationIds: {},
  );

  /// Весь набранный опыт, включая сгоревший. От него считается уровень.
  int get totalXp => runs.fold(0, (sum, run) => sum + run.xp);

  bool countsInRating(RunSummary run) {
    if (run.confirmed) return true;
    return DateTime.now().difference(run.finishedAt) < pendingWindow;
  }

  /// Очки, которые идут в таблицу лидеров.
  int get ratedXp =>
      runs.where(countsInRating).fold(0, (sum, run) => sum + run.xp);

  int get pendingXp => runs
      .where((run) => !run.confirmed && countsInRating(run))
      .fold(0, (sum, run) => sum + run.xp);

  int get expiredXp => runs
      .where((run) => !run.confirmed && !countsInRating(run))
      .fold(0, (sum, run) => sum + run.xp);

  /// Каждые [xpPerLevel] очков опыта — новый уровень. Формула намеренно
  /// линейная: её видно в интерфейсе, и жюри может проверить арифметику.
  static const xpPerLevel = 500;

  int get level => 1 + totalXp ~/ xpPerLevel;
  int get xpIntoLevel => totalXp % xpPerLevel;
  double get levelProgress => xpIntoLevel / xpPerLevel;

  String get rank => switch (level) {
    1 => 'Стажёр',
    2 => 'Проводник',
    3 => 'Проводник 1 категории',
    4 => 'Старший проводник',
    5 => 'Инструктор бригады',
    _ => 'Наставник ВСМ',
  };

  int get completedCount => runs.length;

  /// Уникальные сценарии, которые уже проходили хотя бы раз.
  Set<String> get completedScenarioIds =>
      runs.map((run) => run.scenarioId).toSet();

  /// Средняя оценка по последним прохождениям — основной показатель в профиле.
  int get averageScore {
    if (runs.isEmpty) return 0;
    final sum = runs.fold(0, (total, run) => total + run.score);
    return (sum / runs.length).round();
  }

  int get averageLoyalty {
    if (runs.isEmpty) return 0;
    return (runs.fold(0, (t, r) => t + r.loyalty) / runs.length).round();
  }

  int get averageSafety {
    if (runs.isEmpty) return 0;
    return (runs.fold(0, (t, r) => t + r.safety) / runs.length).round();
  }

  /// Серия прохождений без грубых ошибок, считая от последнего.
  int get cleanStreak {
    var streak = 0;
    for (final run in runs.reversed) {
      if (run.mistakeCount > 0) break;
      streak++;
    }
    return streak;
  }

  ConductorProfile copyWith({
    String? name,
    String? brigade,
    String? depot,
    Map<Competency, int>? competencyPoints,
    List<RunSummary>? runs,
    Set<String>? unlockedAchievements,
    Set<String>? seenNotificationIds,
    bool? created,
  }) => ConductorProfile(
    name: name ?? this.name,
    brigade: brigade ?? this.brigade,
    depot: depot ?? this.depot,
    competencyPoints: competencyPoints ?? this.competencyPoints,
    runs: runs ?? this.runs,
    unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
    seenNotificationIds: seenNotificationIds ?? this.seenNotificationIds,
    created: created ?? this.created,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'brigade': brigade,
    'depot': depot,
    'competencyPoints': {
      for (final entry in competencyPoints.entries) entry.key.id: entry.value,
    },
    'runs': runs.map((run) => run.toJson()).toList(),
    'unlockedAchievements': unlockedAchievements.toList(),
    'seenNotificationIds': seenNotificationIds.toList(),
    'created': created,
  };

  factory ConductorProfile.fromJson(Map<String, Object?> json) =>
      ConductorProfile(
        name: json['name'] as String? ?? 'Проводник',
        brigade: json['brigade'] as String? ?? 'Бригада №4',
        depot: json['depot'] as String? ?? 'Депо Москва-Октябрьская',
        competencyPoints: Competency.parseMap(json['competencyPoints']),
        runs: (json['runs'] as List<Object?>? ?? const [])
            .cast<Map<String, Object?>>()
            .map(RunSummary.fromJson)
            .toList(),
        unlockedAchievements:
            (json['unlockedAchievements'] as List<Object?>? ?? const [])
                .map((e) => '$e')
                .toSet(),
        seenNotificationIds:
            (json['seenNotificationIds'] as List<Object?>? ?? const [])
                .map((e) => '$e')
                .toSet(),
        created: json['created'] as bool? ?? true,
      );
}
