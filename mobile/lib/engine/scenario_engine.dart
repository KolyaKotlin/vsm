import 'package:flutter/foundation.dart';

import '../domain/competency.dart';
import '../domain/scenario.dart';
import 'role_model.dart';

/// Запись об одном принятом решении. Из этих записей целиком собирается
/// экран разбора, поэтому здесь лежит всё, что нужно объяснить игроку:
/// что было сказано, что это изменило и почему.
class DecisionRecord {
  const DecisionRecord({
    required this.sceneId,
    required this.speakerName,
    required this.sceneLine,
    required this.actionText,
    required this.roleStep,
    required this.loyaltyDelta,
    required this.safetyDelta,
    required this.competencyDelta,
    required this.feedback,
    required this.wasTimeout,
    this.roleModelNote,
    this.bestAlternative,
    this.secondsLeft,
    this.timerSeconds,
  });

  final String sceneId;
  final String speakerName;
  final String sceneLine;

  /// Реплика игрока либо описание того, что случилось по таймауту.
  final String actionText;
  final RoleStep roleStep;

  /// Итоговый сдвиг шкал — уже с поправкой от ролевой модели.
  final int loyaltyDelta;
  final int safetyDelta;
  final Map<Competency, int> competencyDelta;
  final ChoiceFeedback feedback;

  /// `true`, если решение не было принято и сработал таймер.
  final bool wasTimeout;

  /// Замечание ролевой модели, если порядок шагов был нарушен.
  final String? roleModelNote;

  /// Лучший доступный вариант в этой сцене — показываем, если игрок выбрал
  /// не его. Это и есть «как можно было лучше» из требований к обратной связи.
  final String? bestAlternative;

  /// Сколько секунд оставалось на таймере в момент решения.
  final int? secondsLeft;
  final int? timerSeconds;

  bool get wasTimed => timerSeconds != null;

  /// Решение принято в последней пятой части времени — признак работы на грани.
  bool get wasLastMoment =>
      wasTimed && !wasTimeout && (secondsLeft ?? 0) <= timerSeconds! * 0.2;
}

/// Итог прохождения сценария.
class ScenarioResult {
  const ScenarioResult({
    required this.scenario,
    required this.loyalty,
    required this.safety,
    required this.competencyTotals,
    required this.decisions,
    required this.ending,
    required this.roleTrack,
    required this.completionJudgement,
    required this.xp,
    required this.finishedAt,
  });

  final Scenario scenario;
  final int loyalty;
  final int safety;
  final Map<Competency, int> competencyTotals;
  final List<DecisionRecord> decisions;
  final ScenarioEnding ending;

  /// Фактическая траектория по ролевой модели.
  final List<RoleStep> roleTrack;
  final RoleStepJudgement completionJudgement;
  final int xp;
  final DateTime finishedAt;

  /// Итоговая оценка прохождения — среднее двух шкал.
  int get score => ((loyalty + safety) / 2).round();

  int get timeoutCount => decisions.where((d) => d.wasTimeout).length;

  int get mistakeCount => decisions
      .where((d) =>
          d.feedback.verdict == ChoiceVerdict.bad ||
          d.feedback.verdict == ChoiceVerdict.critical)
      .length;
}

/// Движок прохождения одного сценария.
///
/// Это конечный автомат: состояние — текущая сцена, две шкалы и набор флагов.
/// Переход делает [choose] или [registerTimeout]. Движок ничего не знает про
/// виджеты, поэтому его можно целиком покрыть unit-тестами — и именно он, а не
/// UI, решает, чем закончится ситуация.
class ScenarioEngine extends ChangeNotifier {
  ScenarioEngine({required this.scenario})
      : _loyalty = scenario.initialLoyalty,
        _safety = scenario.initialSafety,
        _currentScene = scenario.startScene;

  final Scenario scenario;

  Scene _currentScene;
  int _loyalty;
  int _safety;
  final Set<String> _flags = <String>{};
  final List<DecisionRecord> _decisions = [];
  final List<RoleStep> _performedSteps = [];
  final Map<Competency, int> _competencyTotals = {};
  ScenarioResult? _result;

  Scene get currentScene => _currentScene;
  int get loyalty => _loyalty;
  int get safety => _safety;
  Set<String> get flags => Set.unmodifiable(_flags);
  List<DecisionRecord> get decisions => List.unmodifiable(_decisions);
  List<RoleStep> get performedSteps => List.unmodifiable(_performedSteps);

  bool get isFinished => _result != null;
  ScenarioResult? get result => _result;

  /// Сколько сцен уже пройдено — для индикатора прогресса.
  int get stepNumber => _decisions.length + 1;

  /// Варианты, доступные в текущей сцене с учётом флагов и значений шкал.
  ///
  /// Недоступные варианты не показываем вообще: проводник в реальности тоже не
  /// видит вариант «передать пассажира начальнику поезда», пока его не вызвал.
  List<Choice> get availableChoices => _currentScene.choices
      .where((choice) => choice.requirement.isSatisfied(
            activeFlags: _flags,
            loyalty: _loyalty,
            safety: _safety,
          ))
      .toList(growable: false);

  /// Игрок выбрал вариант ответа.
  ///
  /// [secondsLeft] передаёт UI для сцен с таймером: скорость решения влияет на
  /// стрессоустойчивость.
  void choose(Choice choice, {int? secondsLeft}) {
    if (isFinished) return;

    final judgement = RoleModel.judgeStep(
      step: choice.roleStep,
      previousSteps: _performedSteps,
    );

    final competencyDelta = _mergeCompetencies(
      choice.effects.competencies,
      judgement.competencyDelta,
    );

    // Быстрое решение под таймером — плюс к стрессоустойчивости.
    if (_currentScene.hasTimer &&
        secondsLeft != null &&
        secondsLeft >= _currentScene.timerSeconds! * 0.6 &&
        choice.feedback.verdict != ChoiceVerdict.critical) {
      competencyDelta[Competency.composure] =
          (competencyDelta[Competency.composure] ?? 0) + 1;
    }

    _applyDecision(
      DecisionRecord(
        sceneId: _currentScene.id,
        speakerName: _currentScene.speaker.name,
        sceneLine: _currentScene.line,
        actionText: choice.text,
        roleStep: choice.roleStep,
        loyaltyDelta: choice.effects.loyalty + judgement.loyaltyDelta,
        safetyDelta: choice.effects.safety,
        competencyDelta: competencyDelta,
        feedback: choice.feedback,
        wasTimeout: false,
        roleModelNote: judgement.note,
        bestAlternative: _bestAlternativeTo(choice),
        secondsLeft: secondsLeft,
        timerSeconds: _currentScene.timerSeconds,
      ),
      setFlags: choice.effects.setFlags,
      roleStep: choice.roleStep,
      nextSceneId: choice.nextSceneId,
    );
  }

  /// Таймер критического решения истёк.
  void registerTimeout() {
    if (isFinished) return;
    final outcome = _currentScene.onTimeout;
    if (outcome == null) return;

    _applyDecision(
      DecisionRecord(
        sceneId: _currentScene.id,
        speakerName: _currentScene.speaker.name,
        sceneLine: _currentScene.line,
        actionText: outcome.text,
        roleStep: RoleStep.none,
        loyaltyDelta: outcome.effects.loyalty,
        safetyDelta: outcome.effects.safety,
        competencyDelta: Map.of(outcome.effects.competencies),
        feedback: outcome.feedback,
        wasTimeout: true,
        bestAlternative: _bestAlternativeTo(null),
        secondsLeft: 0,
        timerSeconds: _currentScene.timerSeconds,
      ),
      setFlags: outcome.effects.setFlags,
      roleStep: RoleStep.none,
      nextSceneId: outcome.nextSceneId,
    );
  }

  void _applyDecision(
    DecisionRecord record, {
    required List<String> setFlags,
    required RoleStep roleStep,
    required String? nextSceneId,
  }) {
    _loyalty = _clamp(_loyalty + record.loyaltyDelta);
    _safety = _clamp(_safety + record.safetyDelta);
    _flags.addAll(setFlags);
    _decisions.add(record);
    if (roleStep != RoleStep.none) _performedSteps.add(roleStep);

    record.competencyDelta.forEach((competency, delta) {
      _competencyTotals[competency] =
          (_competencyTotals[competency] ?? 0) + delta;
    });

    final nextScene = nextSceneId == null ? null : scenario.sceneById(nextSceneId);
    if (nextScene == null) {
      _finish(_currentScene.ending);
      return;
    }

    _currentScene = nextScene;
    if (nextScene.isFinal) {
      _finish(nextScene.ending);
      return;
    }
    notifyListeners();
  }

  void _finish(ScenarioEnding? sceneEnding) {
    final completion = RoleModel.judgeCompletion(_performedSteps);

    _loyalty = _clamp(_loyalty + completion.loyaltyDelta);
    completion.competencyDelta.forEach((competency, delta) {
      _competencyTotals[competency] =
          (_competencyTotals[competency] ?? 0) + delta;
    });

    final score = ((_loyalty + _safety) / 2).round();

    _result = ScenarioResult(
      scenario: scenario,
      loyalty: _loyalty,
      safety: _safety,
      competencyTotals: Map.unmodifiable(_competencyTotals),
      decisions: List.unmodifiable(_decisions),
      ending: sceneEnding ?? _fallbackEnding(score),
      roleTrack: RoleModel.distinctTrack(_performedSteps),
      completionJudgement: completion,
      // Очки опыта: средняя оценка, умноженная на сложность сценария.
      // Формула намеренно простая — её видно на экране разбора.
      xp: (score * scenario.difficulty).clamp(10, 999),
      finishedAt: DateTime.now(),
    );
    notifyListeners();
  }

  ScenarioEnding _fallbackEnding(int score) => ScenarioEnding(
        title: score >= 70 ? 'Ситуация разрешена' : 'Ситуация закрыта с потерями',
        text: score >= 70
            ? 'Пассажир остался в рамках сервисного диалога, безопасность не нарушена.'
            : 'Формально ситуация завершена, но качество обслуживания пострадало.',
        tone: score >= 70 ? 'success' : 'partial',
      );

  /// Ищет в текущей сцене вариант с вердиктом «верно», который игрок не выбрал.
  String? _bestAlternativeTo(Choice? chosen) {
    if (chosen != null && chosen.feedback.verdict == ChoiceVerdict.good) {
      return null;
    }
    for (final choice in availableChoices) {
      if (choice.feedback.verdict == ChoiceVerdict.good) return choice.text;
    }
    return null;
  }

  static Map<Competency, int> _mergeCompetencies(
    Map<Competency, int> a,
    Map<Competency, int> b,
  ) {
    final merged = Map.of(a);
    b.forEach((key, value) => merged[key] = (merged[key] ?? 0) + value);
    return merged;
  }

  static int _clamp(int value) => value.clamp(0, 100);
}
