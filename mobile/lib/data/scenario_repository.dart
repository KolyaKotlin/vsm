import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/scenario.dart';

/// Источник сценариев.
///
/// Интерфейс объявлен отдельно от реализации намеренно: когда появится бэкенд,
/// достаточно будет добавить `ApiScenarioRepository` с тем же методом, а UI и
/// движок не изменятся. Формат JSON у файла в assets и у ответа API одинаковый.
abstract interface class ScenarioRepository {
  Future<List<Scenario>> loadScenarios();
}

/// Реализация, читающая сценарии из ассетов приложения.
///
/// Работает офлайн — это принципиально: тренажёр должен запускаться в поезде,
/// где связь пропадает на скорости.
class AssetScenarioRepository implements ScenarioRepository {
  const AssetScenarioRepository({this.basePath = 'assets/scenarios'});

  final String basePath;

  @override
  Future<List<Scenario>> loadScenarios() async {
    final indexRaw = await rootBundle.loadString('$basePath/index.json');
    final index = jsonDecode(indexRaw) as Map<String, Object?>;
    final fileNames = (index['scenarios'] as List<Object?>).cast<String>();

    final scenarios = <Scenario>[];
    for (final fileName in fileNames) {
      final raw = await rootBundle.loadString('$basePath/$fileName');
      final json = jsonDecode(raw) as Map<String, Object?>;
      scenarios.add(Scenario.fromJson(json));
    }

    // Сортируем по сложности: список на главном экране должен вести от
    // рутинных ситуаций к критическим.
    scenarios.sort((a, b) => a.difficulty.compareTo(b.difficulty));
    return scenarios;
  }
}
