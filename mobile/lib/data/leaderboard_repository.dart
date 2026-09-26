import 'dart:convert';

import 'package:flutter/services.dart';

/// Строка таблицы лидеров.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.name,
    required this.brigade,
    required this.depot,
    required this.xp,
    required this.averageScore,
    this.isCurrentUser = false,
  });

  final String name;
  final String brigade;
  final String depot;
  final int xp;
  final int averageScore;

  /// Строка текущего проводника подмешивается к синтетическим коллегам.
  final bool isCurrentUser;
}

/// Область, по которой строится рейтинг.
enum LeaderboardScope {
  brigade('Бригада'),
  depot('Депо'),
  company('Компания');

  const LeaderboardScope(this.label);

  final String label;
}

/// Таблица лидеров.
///
/// Данные синтетические — см. пометку в `assets/data/leaderboard.json`.
/// Реальные ПДн сотрудников в демо-среде не используются (152-ФЗ).
class LeaderboardRepository {
  const LeaderboardRepository();

  Future<List<LeaderboardEntry>> loadColleagues() async {
    final raw = await rootBundle.loadString('assets/data/leaderboard.json');
    final json = jsonDecode(raw) as Map<String, Object?>;
    final entries = (json['entries'] as List<Object?>).cast<Map<String, Object?>>();

    return entries
        .map((entry) => LeaderboardEntry(
              name: entry['name'] as String,
              brigade: entry['brigade'] as String,
              depot: entry['depot'] as String,
              xp: (entry['xp'] as num).round(),
              averageScore: (entry['averageScore'] as num).round(),
            ))
        .toList(growable: false);
  }

  /// Собирает итоговый рейтинг: коллеги из справочника плюс текущий проводник,
  /// отфильтрованные по выбранной области и отсортированные по опыту.
  List<LeaderboardEntry> rank({
    required List<LeaderboardEntry> colleagues,
    required LeaderboardEntry current,
    required LeaderboardScope scope,
  }) {
    final visible = [...colleagues, current].where((entry) {
      return switch (scope) {
        LeaderboardScope.brigade =>
          entry.brigade == current.brigade && entry.depot == current.depot,
        LeaderboardScope.depot => entry.depot == current.depot,
        LeaderboardScope.company => true,
      };
    }).toList();

    visible.sort((a, b) => b.xp.compareTo(a.xp));
    return visible;
  }
}
