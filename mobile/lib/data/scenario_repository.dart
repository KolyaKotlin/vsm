import '../domain/scenario.dart';

/// Источник сценариев. Сайт и телефон читают один каталог с сервера.
abstract interface class ScenarioRepository {
  Future<List<Scenario>> loadScenarios();
}
