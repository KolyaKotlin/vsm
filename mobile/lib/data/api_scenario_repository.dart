import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../domain/scenario.dart';
import 'scenario_repository.dart';

/// Каталог с сервера. Удачная загрузка целиком заменяет файл на телефоне.
///
/// Без сети читается этот файл: в поезде связь пропадает, а сценарии уже
/// скачаны. Своего каталога в сборке приложения нет.
class ApiScenarioRepository implements ScenarioRepository {
  ApiScenarioRepository({
    required this.baseUrl,
    this.cacheDirectory,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;

  /// Для тестов. В приложении каталог лежит в документах телефона.
  final Directory? cacheDirectory;
  final http.Client _client;

  static const _fileName = 'vsm_scenarios.json';

  @override
  Future<List<Scenario>> loadScenarios() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/mobile/scenarios'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        throw Exception('Сервер ответил ${response.statusCode}');
      }
      final body = utf8.decode(response.bodyBytes);
      final scenarios = _parse(body);
      await _replaceCache(body);
      return scenarios;
    } catch (error) {
      final cached = await _readCache();
      if (cached != null) {
        debugPrint('Сети нет, открываю сохранённый каталог: $error');
        return cached;
      }
      throw Exception(
        'Каталог ещё не скачан. Подключитесь к сети и откройте приложение ещё раз — потом он останется на телефоне.',
      );
    }
  }

  List<Scenario> _parse(String body) {
    final raw = jsonDecode(body) as List<Object?>;
    return raw.cast<Map<String, Object?>>().map(Scenario.fromJson).toList();
  }

  Future<Directory> _directory() async {
    final injected = cacheDirectory;
    if (injected != null) return injected;
    try {
      return await getApplicationDocumentsDirectory().timeout(
        const Duration(seconds: 2),
      );
    } catch (error) {
      debugPrint('Папка документов недоступна: $error');
      return Directory.systemTemp;
    }
  }

  Future<File> _file() async {
    final directory = await _directory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> _replaceCache(String body) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(body, flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  Future<List<Scenario>?> _readCache() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      return _parse(await file.readAsString());
    } catch (error) {
      debugPrint('Сохранённый каталог не прочитался: $error');
      return null;
    }
  }
}
