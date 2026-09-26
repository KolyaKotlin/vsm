import 'competency.dart';

/// Шаг основной ролевой модели из памятки РЖД:
/// «признать ситуацию → обозначить правило → предложить решение → заверить».
///
/// Каждый вариант ответа игрока помечен одним из этих шагов. Движок следит не
/// только за тем, *что* выбрал игрок, но и за тем, в каком *порядке* — именно
/// это отличает тренажёр от теста с единственным правильным ответом.
enum RoleStep {
  acknowledge('acknowledge', 'Признать ситуацию'),
  rule('rule', 'Обозначить правило'),
  solution('solution', 'Предложить решение'),
  assure('assure', 'Заверить'),

  /// Действие вне ролевой модели: вызвать начальника поезда, промолчать и т.п.
  none('none', 'Действие');

  const RoleStep(this.id, this.label);

  final String id;
  final String label;

  /// Канонический порядок, по которому движок считает нарушения.
  static const canonicalOrder = [acknowledge, rule, solution, assure];

  static RoleStep parse(Object? raw) {
    for (final value in values) {
      if (value.id == raw) return value;
    }
    return none;
  }
}

/// Насколько выбор игрока соответствует стандарту обслуживания.
enum ChoiceVerdict {
  good('good', 'Верно'),
  acceptable('acceptable', 'Допустимо'),
  bad('bad', 'Ошибка'),
  critical('critical', 'Грубое нарушение');

  const ChoiceVerdict(this.id, this.label);

  final String id;
  final String label;

  static ChoiceVerdict parse(Object? raw) {
    for (final value in values) {
      if (value.id == raw) return value;
    }
    return acceptable;
  }
}

enum ScenarioCategory {
  conflict('conflict', 'Конфликт'),
  medical('medical', 'Медицина'),
  service('service', 'Сервис'),
  safety('safety', 'Безопасность'),
  boarding('boarding', 'Посадка');

  const ScenarioCategory(this.id, this.label);

  final String id;
  final String label;

  static ScenarioCategory parse(Object? raw) {
    for (final value in values) {
      if (value.id == raw) return value;
    }
    return service;
  }
}

/// Условие доступности варианта ответа.
///
/// Благодаря `requires` один и тот же узел сценария выглядит по-разному в
/// зависимости от предыстории: например, «Передать пассажира начальнику поезда»
/// доступно только после того, как его вызвали.
class ChoiceRequirement {
  const ChoiceRequirement({
    this.flags = const [],
    this.notFlags = const [],
    this.minLoyalty,
    this.minSafety,
  });

  final List<String> flags;
  final List<String> notFlags;
  final int? minLoyalty;
  final int? minSafety;

  bool isSatisfied({
    required Set<String> activeFlags,
    required int loyalty,
    required int safety,
  }) {
    if (flags.any((flag) => !activeFlags.contains(flag))) return false;
    if (notFlags.any(activeFlags.contains)) return false;
    if (minLoyalty != null && loyalty < minLoyalty!) return false;
    if (minSafety != null && safety < minSafety!) return false;
    return true;
  }

  factory ChoiceRequirement.fromJson(Map<String, Object?>? json) {
    if (json == null) return const ChoiceRequirement();
    return ChoiceRequirement(
      flags: _stringList(json['flags']),
      notFlags: _stringList(json['notFlags']),
      minLoyalty: (json['minLoyalty'] as num?)?.round(),
      minSafety: (json['minSafety'] as num?)?.round(),
    );
  }
}

/// Последствия выбора: сдвиг обеих шкал, очки компетенций и выставленные флаги.
class ChoiceEffects {
  const ChoiceEffects({
    this.loyalty = 0,
    this.safety = 0,
    this.competencies = const {},
    this.setFlags = const [],
  });

  final int loyalty;
  final int safety;
  final Map<Competency, int> competencies;
  final List<String> setFlags;

  factory ChoiceEffects.fromJson(Map<String, Object?>? json) {
    if (json == null) return const ChoiceEffects();
    return ChoiceEffects(
      loyalty: (json['loyalty'] as num?)?.round() ?? 0,
      safety: (json['safety'] as num?)?.round() ?? 0,
      competencies: Competency.parseMap(json['competencies']),
      setFlags: _stringList(json['setFlags']),
    );
  }
}

/// Обучающий разбор выбора.
///
/// `better` заполняют для всех неидеальных вариантов: по критерию оценки
/// обратная связь должна показывать, *как можно было лучше*, а не просто
/// «верно/неверно».
class ChoiceFeedback {
  const ChoiceFeedback({
    required this.verdict,
    required this.why,
    this.better,
    this.regulation,
  });

  final ChoiceVerdict verdict;
  final String why;
  final String? better;

  /// Пункт стандарта или памятки, на который опирается разбор.
  final String? regulation;

  factory ChoiceFeedback.fromJson(Map<String, Object?>? json) {
    if (json == null) {
      return const ChoiceFeedback(verdict: ChoiceVerdict.acceptable, why: '');
    }
    return ChoiceFeedback(
      verdict: ChoiceVerdict.parse(json['verdict']),
      why: json['why'] as String? ?? '',
      better: json['better'] as String?,
      regulation: json['regulation'] as String?,
    );
  }
}

class Choice {
  const Choice({
    required this.id,
    required this.text,
    required this.roleStep,
    required this.effects,
    required this.feedback,
    required this.nextSceneId,
    this.requirement = const ChoiceRequirement(),
  });

  final String id;
  final String text;
  final RoleStep roleStep;
  final ChoiceEffects effects;
  final ChoiceFeedback feedback;

  /// `null` означает «сценарий заканчивается на этой сцене».
  final String? nextSceneId;
  final ChoiceRequirement requirement;

  factory Choice.fromJson(Map<String, Object?> json) {
    return Choice(
      id: json['id'] as String,
      text: json['text'] as String,
      roleStep: RoleStep.parse(json['roleStep']),
      effects: ChoiceEffects.fromJson(json['effects'] as Map<String, Object?>?),
      feedback:
          ChoiceFeedback.fromJson(json['feedback'] as Map<String, Object?>?),
      nextSceneId: json['next'] as String?,
      requirement: ChoiceRequirement.fromJson(
        json['requires'] as Map<String, Object?>?,
      ),
    );
  }
}

/// Что происходит, если игрок не успел принять решение до истечения таймера.
class TimeoutOutcome {
  const TimeoutOutcome({
    required this.text,
    required this.effects,
    required this.feedback,
    required this.nextSceneId,
  });

  final String text;
  final ChoiceEffects effects;
  final ChoiceFeedback feedback;
  final String? nextSceneId;

  factory TimeoutOutcome.fromJson(Map<String, Object?> json) {
    return TimeoutOutcome(
      text: json['text'] as String? ?? 'Время вышло — ситуация развивается сама',
      effects: ChoiceEffects.fromJson(json['effects'] as Map<String, Object?>?),
      feedback:
          ChoiceFeedback.fromJson(json['feedback'] as Map<String, Object?>?),
      nextSceneId: json['next'] as String?,
    );
  }
}

/// Кто произносит реплику сцены.
class Speaker {
  const Speaker({required this.name, this.note, this.mood = 'neutral'});

  final String name;

  /// Короткая пометка: «мужчина ~35 лет, торопится».
  final String? note;

  /// Настроение влияет только на оформление аватара.
  final String mood;

  factory Speaker.fromJson(Map<String, Object?>? json) {
    if (json == null) return const Speaker(name: 'Пассажир');
    return Speaker(
      name: json['name'] as String? ?? 'Пассажир',
      note: json['note'] as String?,
      mood: json['mood'] as String? ?? 'neutral',
    );
  }
}

/// Финал сценария.
class ScenarioEnding {
  const ScenarioEnding({
    required this.title,
    required this.text,
    required this.tone,
  });

  final String title;
  final String text;

  /// `success` | `partial` | `failure` — влияет на оформление экрана разбора.
  final String tone;

  factory ScenarioEnding.fromJson(Map<String, Object?> json) {
    return ScenarioEnding(
      title: json['title'] as String? ?? 'Ситуация завершена',
      text: json['text'] as String? ?? '',
      tone: json['tone'] as String? ?? 'partial',
    );
  }
}

class Scene {
  const Scene({
    required this.id,
    required this.speaker,
    required this.line,
    required this.choices,
    this.narration,
    this.timerSeconds,
    this.onTimeout,
    this.ending,
  });

  final String id;
  final Speaker speaker;

  /// Реплика говорящего.
  final String line;

  /// Ремарка от «рассказчика»: обстановка, реакция салона, шум.
  final String? narration;

  /// Если задано — сцена считается критическим решением и включает таймер.
  final int? timerSeconds;
  final TimeoutOutcome? onTimeout;
  final List<Choice> choices;

  /// Заполнено только у финальных сцен (у них `choices` пуст).
  final ScenarioEnding? ending;

  bool get isFinal => ending != null;
  bool get hasTimer => timerSeconds != null && onTimeout != null;

  factory Scene.fromJson(Map<String, Object?> json) {
    final rawChoices = json['choices'] as List<Object?>? ?? const [];
    final rawTimeout = json['onTimeout'] as Map<String, Object?>?;
    final rawEnding = json['ending'] as Map<String, Object?>?;

    return Scene(
      id: json['id'] as String,
      speaker: Speaker.fromJson(json['speaker'] as Map<String, Object?>?),
      line: json['line'] as String? ?? '',
      narration: json['narration'] as String?,
      timerSeconds: (json['timerSeconds'] as num?)?.round(),
      onTimeout: rawTimeout == null ? null : TimeoutOutcome.fromJson(rawTimeout),
      choices: rawChoices
          .cast<Map<String, Object?>>()
          .map(Choice.fromJson)
          .toList(growable: false),
      ending: rawEnding == null ? null : ScenarioEnding.fromJson(rawEnding),
    );
  }
}

/// Обстановка, в которой происходит сценарий. Нужна для «погружения» и для
/// того, чтобы одни и те же правила по-разному применялись в разных классах
/// обслуживания (нормативы времени в СТО РЖД 03.011-2026 п. 10.5 различаются).
class ScenarioContext {
  const ScenarioContext({
    required this.route,
    required this.train,
    required this.carClass,
    required this.phase,
    required this.clock,
  });

  final String route;
  final String train;

  /// `standard` | `comfort` | `business` | `first`.
  final String carClass;
  final String phase;
  final String clock;

  String get carClassLabel => switch (carClass) {
        'first' => 'Первый класс',
        'business' => 'Бизнес-класс',
        'comfort' => 'Комфорт-класс',
        _ => 'Стандарт-класс',
      };

  factory ScenarioContext.fromJson(Map<String, Object?>? json) {
    if (json == null) {
      return const ScenarioContext(
        route: 'Москва — Санкт-Петербург',
        train: 'ВСМ-400',
        carClass: 'standard',
        phase: 'В пути',
        clock: '12:00',
      );
    }
    return ScenarioContext(
      route: json['route'] as String? ?? 'Москва — Санкт-Петербург',
      train: json['train'] as String? ?? 'ВСМ-400',
      carClass: json['carClass'] as String? ?? 'standard',
      phase: json['phase'] as String? ?? 'В пути',
      clock: json['clock'] as String? ?? '12:00',
    );
  }
}

class Scenario {
  const Scenario({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.difficulty,
    required this.source,
    required this.trainedCompetencies,
    required this.context,
    required this.initialLoyalty,
    required this.initialSafety,
    required this.startSceneId,
    required this.scenes,
  });

  final String id;
  final String title;
  final String summary;
  final ScenarioCategory category;

  /// 1 — рутина, 2 — напряжённая ситуация, 3 — критический инцидент.
  final int difficulty;

  /// Ссылка на первоисточник: пункт стандарта или номер ситуации в памятке.
  final String source;
  final List<Competency> trainedCompetencies;
  final ScenarioContext context;
  final int initialLoyalty;
  final int initialSafety;
  final String startSceneId;
  final Map<String, Scene> scenes;

  Scene? sceneById(String id) => scenes[id];
  Scene get startScene => scenes[startSceneId]!;

  /// Сколько сцен с таймером — показываем на карточке сценария, чтобы игрок
  /// заранее понимал уровень стресса.
  int get timedSceneCount => scenes.values.where((s) => s.hasTimer).length;

  factory Scenario.fromJson(Map<String, Object?> json) {
    final rawScenes = (json['scenes'] as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(Scene.fromJson);

    final initial = json['initial'] as Map<String, Object?>? ?? const {};

    return Scenario(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String? ?? '',
      category: ScenarioCategory.parse(json['category']),
      difficulty: (json['difficulty'] as num?)?.round() ?? 1,
      source: json['source'] as String? ?? '',
      trainedCompetencies: _stringList(json['competencies'])
          .map(Competency.tryParse)
          .whereType<Competency>()
          .toList(growable: false),
      context: ScenarioContext.fromJson(
        json['context'] as Map<String, Object?>?,
      ),
      initialLoyalty: (initial['loyalty'] as num?)?.round() ?? 60,
      initialSafety: (initial['safety'] as num?)?.round() ?? 100,
      startSceneId: json['startScene'] as String,
      scenes: {for (final scene in rawScenes) scene.id: scene},
    );
  }
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => '$e').toList(growable: false);
}
