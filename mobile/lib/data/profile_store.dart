import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/profile.dart';

/// Хранилище профиля проводника.
///
/// Пока это локальный `shared_preferences`. Когда появится бэкенд, здесь
/// добавится синхронизация: тот же JSON уйдёт в `PUT /api/v1/profile`, поэтому
/// формат [ConductorProfile.toJson] и есть контракт с сервером.
class ProfileStore {
  static const _key = 'vsm_academy.profile.v1';

  Future<ConductorProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return ConductorProfile.initial();

    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      return ConductorProfile.fromJson(json);
    } on FormatException {
      // Профиль от несовместимой версии не должен ронять приложение:
      // начинаем заново, а не падаем на старте.
      return ConductorProfile.initial();
    }
  }

  Future<void> save(ConductorProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
