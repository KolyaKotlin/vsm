import 'package:flutter/material.dart';

/// Компетенции проводника ВСМ, которые тренирует приложение.
///
/// Набор взят не из головы: это те качества, по которым СТО РЖД 03.011-2026
/// (разделы 9-10) и памятка «Примеры ситуаций взаимодействия поездного
/// персонала с пассажирами» оценивают работу поездной бригады.
enum Competency {
  empathy('empathy', 'Эмпатия', Icons.favorite_rounded),
  regulations('regulations', 'Регламент', Icons.menu_book_rounded),
  safety('safety', 'Безопасность', Icons.shield_rounded),
  communication('communication', 'Коммуникация', Icons.forum_rounded),
  composure('composure', 'Стрессоустойчивость', Icons.self_improvement_rounded);

  const Competency(this.id, this.label, this.icon);

  /// Ключ, под которым компетенция лежит в JSON сценария и в профиле.
  final String id;
  final String label;
  final IconData icon;

  static Competency? tryParse(String raw) {
    for (final value in values) {
      if (value.id == raw) return value;
    }
    return null;
  }

  /// Разбирает блок `competencies` из JSON, молча пропуская незнакомые ключи.
  ///
  /// Это осознанная уступка расширяемости: сценарий, написанный под будущую
  /// версию приложения, не сломает текущую.
  static Map<Competency, int> parseMap(Object? raw) {
    if (raw is! Map) return const {};
    final result = <Competency, int>{};
    raw.forEach((key, value) {
      final competency = tryParse('$key');
      if (competency != null && value is num) {
        result[competency] = value.round();
      }
    });
    return result;
  }
}
