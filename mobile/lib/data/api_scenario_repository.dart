import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/scenario.dart';
import 'scenario_repository.dart';

/// Каталог с сервера тренажёра. Тот же источник, что у сайта.
///
/// Если сервер недоступен (поезд без сети), остаётся запасной каталог из
/// сборки приложения, чтобы экран не был пустым.
class ApiScenarioRepository implements ScenarioRepository {
  ApiScenarioRepository({
    required this.baseUrl,
    required this.fallback,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final ScenarioRepository fallback;
  final http.Client _client;

  @override
  Future<List<Scenario>> loadScenarios() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/mobile/scenarios'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw Exception('Сервер ответил ${response.statusCode}');
      }
      final raw = jsonDecode(utf8.decode(response.bodyBytes)) as List<Object?>;
      final scenarios = raw
          .cast<Map<String, Object?>>()
          .map(Scenario.fromJson)
          .toList();
      scenarios.sort((a, b) => a.title.compareTo(b.title));
      return scenarios;
    } catch (error) {
      debugPrint('Каталог с сервера не прочитался, беру локальный: $error');
      return fallback.loadScenarios();
    }
  }
}
