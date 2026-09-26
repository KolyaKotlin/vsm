import '../domain/competency.dart';
import '../domain/scenario.dart';

/// Вердикт ролевой модели по одному шагу игрока.
class RoleStepJudgement {
  const RoleStepJudgement({
    this.loyaltyDelta = 0,
    this.competencyDelta = const {},
    this.note,
  });

  /// Дополнительный сдвиг лояльности — сверх того, что прописан в сценарии.
  final int loyaltyDelta;
  final Map<Competency, int> competencyDelta;

  /// Пояснение для экрана разбора. `null` — замечаний нет.
  final String? note;

  bool get isEmpty => loyaltyDelta == 0 && competencyDelta.isEmpty && note == null;
}

/// Правила основной ролевой модели РЖД.
///
/// Памятка «Примеры ситуаций взаимодействия поездного персонала с пассажирами»
/// задаёт последовательность: признать ситуацию → обозначить правило →
/// предложить решение → заверить. Формально правильная реплика, сказанная не в
/// свой момент, работает против проводника: если начать с правила, пассажир
/// слышит выговор, а не помощь.
///
/// Эти правила живут здесь, а не внутри сценариев. Поэтому изменить логику
/// («сделайте штраф мягче», «добавьте требование заверения») можно правкой
/// одного файла, и она сразу применится ко всем сценариям.
abstract final class RoleModel {
  /// Штраф за правило, озвученное до признания ситуации.
  static const _ruleBeforeAcknowledgePenalty = -6;

  /// Штраф за решение, предложенное до признания ситуации.
  static const _solutionBeforeAcknowledgePenalty = -4;

  /// Премия за полностью пройденный цикл из четырёх шагов.
  static const _fullCycleBonus = 8;

  /// Оценивает очередной шаг игрока с учётом того, что он делал раньше.
  static RoleStepJudgement judgeStep({
    required RoleStep step,
    required List<RoleStep> previousSteps,
  }) {
    final acknowledged = previousSteps.contains(RoleStep.acknowledge);

    if (step == RoleStep.rule && !acknowledged) {
      return const RoleStepJudgement(
        loyaltyDelta: _ruleBeforeAcknowledgePenalty,
        competencyDelta: {Competency.empathy: -2},
        note: 'Правило озвучено до того, как ситуация признана. Пассажир '
            'услышал выговор вместо помощи — по ролевой модели сначала идёт '
            '«Я Вас понимаю…», и только потом «Обращаю Ваше внимание…».',
      );
    }

    if (step == RoleStep.solution && !acknowledged) {
      return const RoleStepJudgement(
        loyaltyDelta: _solutionBeforeAcknowledgePenalty,
        competencyDelta: {Competency.empathy: -1},
        note: 'Решение предложено без признания ситуации. Технически верно, но '
            'пассажир не почувствовал, что его услышали.',
      );
    }

    if (step == RoleStep.assure && previousSteps.isEmpty) {
      return const RoleStepJudgement(
        loyaltyDelta: -3,
        note: 'Благодарность за понимание до того, как что-то сделано, звучит '
            'формально.',
      );
    }

    return const RoleStepJudgement();
  }

  /// Проверяет по завершении сценария, закрыт ли полный цикл ролевой модели.
  static RoleStepJudgement judgeCompletion(List<RoleStep> performedSteps) {
    final missing = RoleStep.canonicalOrder
        .where((step) => !performedSteps.contains(step))
        .toList(growable: false);

    if (missing.isEmpty) {
      return const RoleStepJudgement(
        loyaltyDelta: _fullCycleBonus,
        competencyDelta: {Competency.communication: 3},
        note: 'Полный цикл ролевой модели: ситуация признана, правило '
            'обозначено, решение предложено, пассажир заверен.',
      );
    }

    return RoleStepJudgement(
      note: 'Цикл ролевой модели не закрыт. Не хватило шагов: '
          '${missing.map((s) => s.label.toLowerCase()).join(', ')}.',
    );
  }

  /// Порядок шагов, фактически выполненный игроком, без повторов.
  /// Используется на экране разбора, чтобы показать траекторию.
  static List<RoleStep> distinctTrack(List<RoleStep> performedSteps) {
    final seen = <RoleStep>[];
    for (final step in performedSteps) {
      if (step != RoleStep.none && !seen.contains(step)) seen.add(step);
    }
    return seen;
  }
}
