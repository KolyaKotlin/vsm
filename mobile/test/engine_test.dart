import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsm_academy/domain/scenario.dart';
import 'package:vsm_academy/engine/role_model.dart';
import 'package:vsm_academy/engine/scenario_engine.dart';

Scenario _load(String fileName) {
  final file = File('test/fixtures/scenarios/$fileName');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return Scenario.fromJson(json);
}

Choice _choice(ScenarioEngine engine, String id) {
  return engine.availableChoices.firstWhere((choice) => choice.id == id);
}

void main() {
  test('ролевая модель штрафует правило до признания ситуации', () {
    final judgement = RoleModel.judgeStep(
      step: RoleStep.rule,
      previousSteps: const [],
    );
    expect(judgement.loyaltyDelta, lessThan(0));
    expect(judgement.note, isNotNull);
  });

  test('посадка без билета: правильный цикл закрывает сценарий штатно', () {
    final scenario = _load('boarding_no_ticket.json');
    final engine = ScenarioEngine(scenario: scenario);

    engine.choose(_choice(engine, 's1_ack'));
    engine.choose(_choice(engine, 's2_rule'));
    engine.choose(_choice(engine, 's5_app'));
    engine.choose(_choice(engine, 's6_assure'));

    expect(engine.isFinished, isTrue);
    expect(engine.result!.ending.tone, 'success');
    expect(engine.result!.loyalty, greaterThan(70));
    expect(engine.result!.safety, 100);
    expect(engine.result!.roleTrack, containsAll(RoleStep.canonicalOrder));
  });

  test('пропуск без билета роняет шкалу безопасности', () {
    final scenario = _load('boarding_no_ticket.json');
    final engine = ScenarioEngine(scenario: scenario);

    engine.choose(_choice(engine, 's1_let_through'));
    expect(engine.safety, lessThan(80));

    engine.choose(_choice(engine, 's4_hide'));
    expect(engine.isFinished, isTrue);
    expect(engine.result!.ending.tone, 'failure');
    expect(engine.result!.safety, lessThan(engine.scenario.initialSafety));
  });

  test('таймер критического решения меняет исход', () {
    final scenario = _load('boarding_no_ticket.json');
    final engine = ScenarioEngine(scenario: scenario);

    engine.choose(_choice(engine, 's1_ack'));
    engine.choose(_choice(engine, 's2_rule'));
    expect(engine.currentScene.hasTimer, isTrue);

    engine.registerTimeout();
    expect(engine.decisions.last.wasTimeout, isTrue);
    expect(engine.loyalty, lessThan(scenario.initialLoyalty + 6));
  });
}
