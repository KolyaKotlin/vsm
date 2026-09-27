import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vsm_academy/data/api_scenario_repository.dart';

void main() {
  test('сеть заменяет файл на телефоне, без сети читается он', () async {
    final directory = await Directory.systemTemp.createTemp('vsm-cache');
    addTearDown(() => directory.delete(recursive: true));

    final fixture = File(
      'test/fixtures/scenarios/boarding_no_ticket.json',
    ).readAsStringSync();
    final body = jsonEncode([jsonDecode(fixture)]);
    var online = true;

    final repository = ApiScenarioRepository(
      baseUrl: 'http://train.test',
      cacheDirectory: directory,
      client: MockClient((request) async {
        if (!online) throw const SocketException('нет сети');
        return http.Response.bytes(utf8.encode(body), 200);
      }),
    );

    final downloaded = await repository.loadScenarios();
    expect(downloaded, hasLength(1));
    expect(File('${directory.path}/vsm_scenarios.json').existsSync(), isTrue);

    online = false;
    final cached = await repository.loadScenarios();
    expect(cached.single.id, downloaded.single.id);

    online = true;
    final replaced = jsonEncode([
      {...jsonDecode(fixture) as Map<String, Object?>, 'title': 'Свежая копия'},
    ]);
    final refreshing = ApiScenarioRepository(
      baseUrl: 'http://train.test',
      cacheDirectory: directory,
      client: MockClient(
        (_) async => http.Response.bytes(utf8.encode(replaced), 200),
      ),
    );
    final again = await refreshing.loadScenarios();
    expect(again.single.title, 'Свежая копия');
    expect(
      File('${directory.path}/vsm_scenarios.json').readAsStringSync(),
      contains('Свежая копия'),
    );
  });
}
