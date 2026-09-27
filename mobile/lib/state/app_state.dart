import 'package:flutter/widgets.dart';

import '../data/leaderboard_repository.dart';
import '../data/notification_center.dart';
import '../data/profile_store.dart';
import '../data/scenario_repository.dart';
import '../domain/achievement.dart';
import '../domain/competency.dart';
import '../domain/profile.dart';
import '../domain/scenario.dart';
import '../engine/scenario_engine.dart';

/// Состояние приложения вне прохождения сценария: профиль, каталог сценариев,
/// лента уведомлений, рейтинг.
///
/// Управление состоянием сделано на голом [ChangeNotifier] без внешних
/// библиотек. Причина простая: здесь ровно один разделяемый объект, и
/// подключать ради него Riverpod или BLoC значило бы добавить слой, который
/// нужно объяснять, но который ничего не решает.
class AppState extends ChangeNotifier {
  AppState({
    required ScenarioRepository scenarioRepository,
    ProfileStore? profileStore,
    LeaderboardRepository? leaderboardRepository,
    NotificationCenter? notificationCenter,
  }) : _scenarioRepository = scenarioRepository,
       _profileStore = profileStore ?? ProfileStore(),
       _leaderboardRepository =
           leaderboardRepository ?? const LeaderboardRepository(),
       _notificationCenter = notificationCenter ?? const NotificationCenter();

  final ScenarioRepository _scenarioRepository;
  final ProfileStore _profileStore;
  final LeaderboardRepository _leaderboardRepository;
  final NotificationCenter _notificationCenter;

  bool _isLoading = true;
  Object? _loadError;
  List<Scenario> _scenarios = const [];
  ConductorProfile _profile = ConductorProfile.initial();
  List<LeaderboardEntry> _colleagues = const [];
  List<AppNotification> _notifications = const [];

  bool get isLoading => _isLoading;
  Object? get loadError => _loadError;
  List<Scenario> get scenarios => _scenarios;
  ConductorProfile get profile => _profile;
  List<AppNotification> get notifications => _notifications;

  /// Уведомления, которые проводник ещё не открывал — для бейджа на иконке.
  int get unreadNotificationCount => _notifications
      .where((n) => !_profile.seenNotificationIds.contains(n.id))
      .length;

  /// Повторно читает каталог. Удачный ответ сервера заменяет сохранённую копию.
  /// Если сети нет, на экране остаётся уже открытый список.
  Future<void> refreshScenarios() async {
    try {
      _scenarios = await _scenarioRepository.loadScenarios();
      _loadError = null;
      notifyListeners();
    } catch (error) {
      if (_scenarios.isEmpty) {
        _loadError = error;
        notifyListeners();
      }
    }
  }

  Future<void> bootstrap() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _scenarioRepository.loadScenarios(),
        _profileStore.load(),
        _leaderboardRepository.loadColleagues(),
      ]);
      _scenarios = results[0] as List<Scenario>;
      _profile = results[1] as ConductorProfile;
      _colleagues = results[2] as List<LeaderboardEntry>;
      _rebuildNotifications();
    } catch (error) {
      _loadError = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Scenario? scenarioById(String id) {
    for (final scenario in _scenarios) {
      if (scenario.id == id) return scenario;
    }
    return null;
  }

  /// Записывает итог прохождения в профиль и возвращает ачивки, которые
  /// открылись именно этим прохождением, — их показывает экран разбора.
  Future<CommitOutcome> commitResult(ScenarioResult result) async {
    final challengeDoubled =
        _profile.runs
            .where(
              (run) => run.scenarioId == result.scenario.id && run.score >= 80,
            )
            .isEmpty &&
        result.scenario.difficulty >= 3 &&
        result.score >= 80;
    final awardedXp = challengeDoubled ? result.xp * 2 : result.xp;

    final summary = RunSummary(
      scenarioId: result.scenario.id,
      scenarioTitle: result.scenario.title,
      loyalty: result.loyalty,
      safety: result.safety,
      xp: awardedXp,
      competencyDelta: result.competencyTotals,
      mistakeCount: result.mistakeCount,
      timeoutCount: result.timeoutCount,
      finishedAt: result.finishedAt,
      category: result.scenario.category.id,
      roleCycleClosed: RoleStep.canonicalOrder.every(result.roleTrack.contains),
    );

    final competencyPoints = Map.of(_profile.competencyPoints);
    result.competencyTotals.forEach((competency, delta) {
      // Очки компетенций не уходят в минус: отрицательные решения тормозят
      // рост, но не обнуляют уже подтверждённый навык.
      competencyPoints[competency] =
          ((competencyPoints[competency] ?? 0) + delta).clamp(0, 9999);
    });

    final secured = _profile.runs.map((run) => run.confirm()).toList();
    _profile = _profile.copyWith(
      runs: [...secured, summary],
      competencyPoints: competencyPoints,
    );

    final unlocked = AchievementCatalog.newlyUnlocked(_profile);
    if (unlocked.isNotEmpty) {
      _profile = _profile.copyWith(
        unlockedAchievements: {
          ..._profile.unlockedAchievements,
          ...unlocked.map((a) => a.id),
        },
      );
    }

    _rebuildNotifications();
    await _profileStore.save(_profile);
    notifyListeners();
    return CommitOutcome(
      unlocked: unlocked,
      awardedXp: awardedXp,
      challengeDoubled: challengeDoubled,
    );
  }

  Future<void> createProfile({
    required String name,
    required String brigade,
    required String depot,
  }) async {
    _profile = ConductorProfile.initial().copyWith(
      name: name,
      brigade: brigade,
      depot: depot,
      created: true,
    );
    _rebuildNotifications();
    await _profileStore.save(_profile);
    notifyListeners();
  }

  Future<void> markNotificationsSeen() async {
    _profile = _profile.copyWith(
      seenNotificationIds: {
        ..._profile.seenNotificationIds,
        ..._notifications.map((n) => n.id),
      },
    );
    await _profileStore.save(_profile);
    notifyListeners();
  }

  Future<void> updateIdentity({
    required String name,
    required String brigade,
    required String depot,
  }) async {
    _profile = _profile.copyWith(name: name, brigade: brigade, depot: depot);
    await _profileStore.save(_profile);
    notifyListeners();
  }

  Future<void> resetProgress() async {
    await _profileStore.reset();
    _profile = ConductorProfile.initial();
    _rebuildNotifications();
    notifyListeners();
  }

  /// Рейтинг в выбранной области с подмешанной строкой текущего проводника.
  List<LeaderboardEntry> leaderboard(LeaderboardScope scope) {
    final current = LeaderboardEntry(
      name: _profile.name,
      brigade: _profile.brigade,
      depot: _profile.depot,
      xp: _profile.ratedXp,
      averageScore: _profile.averageScore,
      isCurrentUser: true,
    );
    return _leaderboardRepository.rank(
      colleagues: _colleagues,
      current: current,
      scope: scope,
    );
  }

  /// Компетенция с наименьшим числом очков — «проседающая».
  Competency? get weakestCompetency =>
      NotificationCenter.weakestCompetency(_profile);

  /// Максимум очков среди компетенций — нужен для нормировки радара.
  int get competencyCeiling {
    var max = 10;
    for (final competency in Competency.values) {
      final points = _profile.competencyPoints[competency] ?? 0;
      if (points > max) max = points;
    }
    return max;
  }

  void _rebuildNotifications() {
    _notifications = _notificationCenter.build(
      profile: _profile,
      scenarios: _scenarios,
    );
  }
}

class CommitOutcome {
  const CommitOutcome({
    required this.unlocked,
    required this.awardedXp,
    required this.challengeDoubled,
  });

  final List<Achievement> unlocked;
  final int awardedXp;
  final bool challengeDoubled;
}

/// Пробрасывает [AppState] по дереву виджетов.
///
/// [InheritedNotifier] встроен во Flutter и делает ровно то, что нужно:
/// перестраивает подписчиков при `notifyListeners()`.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope не найден в дереве виджетов');
    return scope!.notifier!;
  }

  /// Доступ без подписки на перестроения — для обработчиков нажатий.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope не найден в дереве виджетов');
    return scope!.notifier!;
  }
}
