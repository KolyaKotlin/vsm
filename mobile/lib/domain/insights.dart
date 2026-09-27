import 'competency.dart';
import 'profile.dart';
import 'scenario.dart';

enum FindingTone { good, attention, note }

enum CompetencyStanding { strong, steady, weak, quiet }

/// Одна компетенция в разборе: очки, свежий сдвиг и оценка относительно своих же.
class CompetencyRead {
  const CompetencyRead({
    required this.competency,
    required this.points,
    required this.recentDelta,
    required this.standing,
  });

  final Competency competency;
  final int points;
  final int recentDelta;
  final CompetencyStanding standing;
}

/// Как идут сценарии одного типа.
class CategoryRead {
  const CategoryRead({
    required this.category,
    required this.attempts,
    required this.average,
    required this.best,
    required this.latest,
  });

  final ScenarioCategory category;
  final int attempts;
  final int average;
  final int best;
  final int latest;
}

class Finding {
  const Finding({required this.title, required this.text, required this.tone});

  final String title;
  final String text;
  final FindingTone tone;
}

/// Разбор профиля по фактическим сменам, без общих фраз «в целом неплохо».
class TrainingReport {
  const TrainingReport({
    required this.headline,
    required this.summary,
    required this.findings,
    required this.competencies,
    required this.categories,
    required this.averageScore,
    required this.latestScore,
    required this.bestScore,
    required this.trendLabel,
    this.nextStep,
  });

  final String headline;
  final String summary;
  final List<Finding> findings;
  final List<CompetencyRead> competencies;
  final List<CategoryRead> categories;
  final int averageScore;
  final int latestScore;
  final int bestScore;
  final String trendLabel;
  final String? nextStep;

  List<Competency> get mastered => [
    for (final read in competencies)
      if (read.standing == CompetencyStanding.strong) read.competency,
  ];

  List<Competency> get gaps => [
    for (final read in competencies)
      if (read.standing == CompetencyStanding.weak) read.competency,
  ];

  static TrainingReport build(
    ConductorProfile profile, {
    List<Scenario> scenarios = const [],
  }) {
    if (profile.runs.isEmpty) {
      return const TrainingReport(
        headline: 'Разбирать пока нечего',
        summary:
            'После первой смены здесь будут тренд, перекос шкал и тип ситуаций, который проседает.',
        findings: [],
        competencies: [],
        categories: [],
        averageScore: 0,
        latestScore: 0,
        bestScore: 0,
        trendLabel: 'нет смен',
      );
    }

    final runs = profile.runs;
    final scores = [for (final run in runs) run.score];
    final average = _average(scores);
    final best = scores.reduce((a, b) => a > b ? a : b);
    final latest = scores.last;
    final trend = _trend(scores);

    final competencies = _competencies(profile);
    final categories = _categories(profile);
    final findings = _findings(profile, competencies, categories, trend);
    final next = _nextStep(profile, competencies, scenarios);

    return TrainingReport(
      headline: _headline(average, trend, profile),
      summary:
          'Смен ${runs.length}, уникальных сценариев ${profile.completedScenarioIds.length}. '
          'Средний итог $average: лояльность ${profile.averageLoyalty}, '
          'безопасность ${profile.averageSafety}.',
      findings: findings,
      competencies: competencies,
      categories: categories,
      averageScore: average,
      latestScore: latest,
      bestScore: best,
      trendLabel: trend.label,
      nextStep: next,
    );
  }

  static String _headline(int average, _Trend trend, ConductorProfile profile) {
    final gap = (profile.averageLoyalty - profile.averageSafety).abs();
    if (profile.runs.length == 1) {
      return average >= 80
          ? 'Первая смена закрыта уверенно'
          : 'По одной смене рано говорить о навыке';
    }
    if (trend.kind == _TrendKind.falling) {
      return 'Последние смены слабее предыдущих';
    }
    if (trend.kind == _TrendKind.rising && average >= 70) {
      return 'Последние смены лучше предыдущих';
    }
    if (gap >= 12) {
      return profile.averageSafety > profile.averageLoyalty
          ? 'Безопасность держится, лояльность нет'
          : 'Пассажир доволен, безопасность проседает';
    }
    if (average >= 80) return 'Итог устойчиво высокий';
    if (average < 60) return 'Итог ниже рабочей планки';
    return 'Результат ровный, без явного роста';
  }

  static List<CompetencyRead> _competencies(ConductorProfile profile) {
    final recent = profile.runs.length <= 3
        ? profile.runs
        : profile.runs.sublist(profile.runs.length - 3);
    final points = {
      for (final competency in Competency.values)
        competency: profile.competencyPoints[competency] ?? 0,
    };
    final values = points.values.toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final maxPoints = values.reduce((a, b) => a > b ? a : b);
    final minPoints = values.reduce((a, b) => a < b ? a : b);
    final flat = maxPoints == minPoints;

    return [
      for (final competency in Competency.values)
        CompetencyRead(
          competency: competency,
          points: points[competency]!,
          recentDelta: recent.fold(
            0,
            (sum, run) => sum + (run.competencyDelta[competency] ?? 0),
          ),
          standing: _standing(
            points: points[competency]!,
            mean: mean,
            maxPoints: maxPoints,
            minPoints: minPoints,
            flat: flat,
          ),
        ),
    ];
  }

  static CompetencyStanding _standing({
    required int points,
    required double mean,
    required int maxPoints,
    required int minPoints,
    required bool flat,
  }) {
    if (points == 0) return CompetencyStanding.quiet;
    if (flat) return CompetencyStanding.steady;
    if (points >= mean + 3 && points >= 6) return CompetencyStanding.strong;
    if (points <= mean - 3 && maxPoints - minPoints >= 4) {
      return CompetencyStanding.weak;
    }
    if (points == minPoints && maxPoints - points >= 6) {
      return CompetencyStanding.weak;
    }
    return CompetencyStanding.steady;
  }

  static List<CategoryRead> _categories(ConductorProfile profile) {
    final buckets = <String, List<RunSummary>>{};
    for (final run in profile.runs) {
      if (run.category.isEmpty) continue;
      buckets.putIfAbsent(run.category, () => []).add(run);
    }

    final reads = <CategoryRead>[];
    for (final category in ScenarioCategory.values) {
      final runs = buckets[category.id];
      if (runs == null || runs.isEmpty) continue;
      final scores = [for (final run in runs) run.score];
      reads.add(
        CategoryRead(
          category: category,
          attempts: runs.length,
          average: _average(scores),
          best: scores.reduce((a, b) => a > b ? a : b),
          latest: scores.last,
        ),
      );
    }
    return reads;
  }

  static List<Finding> _findings(
    ConductorProfile profile,
    List<CompetencyRead> competencies,
    List<CategoryRead> categories,
    _Trend trend,
  ) {
    final findings = <Finding>[];
    final runs = profile.runs;

    if (runs.length >= 2) {
      findings.add(
        Finding(
          title: 'Тренд',
          tone: switch (trend.kind) {
            _TrendKind.rising => FindingTone.good,
            _TrendKind.falling => FindingTone.attention,
            _ => FindingTone.note,
          },
          text: trend.text,
        ),
      );
    }

    final loyaltyLeads = runs
        .where((run) => run.loyalty >= run.safety + 10)
        .length;
    final safetyLeads = runs
        .where((run) => run.safety >= run.loyalty + 10)
        .length;
    if (loyaltyLeads >= 2 && loyaltyLeads > safetyLeads) {
      findings.add(
        Finding(
          title: 'Перекос в сторону пассажира',
          tone: FindingTone.attention,
          text:
              'В $loyaltyLeads из ${runs.length} смен лояльность заметно выше безопасности. '
              'Так бывает, когда правило смягчают, чтобы не спорить.',
        ),
      );
    } else if (safetyLeads >= 2 && safetyLeads > loyaltyLeads) {
      findings.add(
        Finding(
          title: 'Перекос в сторону нормы',
          tone: FindingTone.attention,
          text:
              'В $safetyLeads из ${runs.length} смен безопасность выше лояльности. '
              'Правило звучит раньше, чем ситуация признана.',
        ),
      );
    } else if ((profile.averageLoyalty - profile.averageSafety).abs() <= 6 &&
        runs.length >= 2) {
      findings.add(
        const Finding(
          title: 'Шкалы идут вместе',
          tone: FindingTone.good,
          text:
              'Лояльность и безопасность не разъезжаются. Решения не покупают одну шкалу ценой другой.',
        ),
      );
    }

    final timedOut = runs.where((run) => run.timeoutCount > 0).toList();
    if (timedOut.isNotEmpty) {
      final titles = timedOut
          .map((run) => run.scenarioTitle)
          .toSet()
          .join(', ');
      findings.add(
        Finding(
          title: 'Таймер',
          tone: FindingTone.attention,
          text:
              'Пауза сорвала исход в ${timedOut.length} из ${runs.length} смен: $titles. '
              'На этих сценах короткий верный ответ лучше долгого.',
        ),
      );
    }

    final mistaken = runs.where((run) => run.mistakeCount > 0).length;
    if (runs.length >= 2 && mistaken == 0) {
      findings.add(
        Finding(
          title: 'Без критических ошибок',
          tone: FindingTone.good,
          text:
              'В последних ${profile.cleanStreak} сменах нет решений с критическим вердиктом.',
        ),
      );
    } else if (mistaken * 2 >= runs.length && runs.length >= 2) {
      findings.add(
        Finding(
          title: 'Ошибки повторяются',
          tone: FindingTone.attention,
          text:
              'Критический вердикт был в $mistaken из ${runs.length} смен. '
              'Это уже не разовая оговорка.',
        ),
      );
    }

    final closed = runs.where((run) => run.roleCycleClosed).length;
    if (closed == runs.length && runs.length >= 2) {
      findings.add(
        const Finding(
          title: 'Ролевой цикл закрыт',
          tone: FindingTone.good,
          text: 'В каждой смене есть признание, правило, решение и заверение.',
        ),
      );
    } else if (closed < runs.length) {
      findings.add(
        Finding(
          title: 'Ролевой цикл',
          tone: FindingTone.attention,
          text:
              'Полный цикл закрыт в $closed из ${runs.length} смен. '
              'Незакрытая смена обычно обрывается до заверения: пассажир не слышит, что вопрос решён.',
        ),
      );
    }

    if (categories.length >= 2) {
      final sorted = [...categories]
        ..sort((a, b) => a.average.compareTo(b.average));
      final weak = sorted.first;
      final strong = sorted.last;
      final spread = strong.average - weak.average;
      if (spread >= 12 && weak.attempts >= 2) {
        findings.add(
          Finding(
            title: 'Тип ситуации',
            tone: FindingTone.attention,
            text:
                '«${weak.category.label}» — ${weak.average} в среднем за ${weak.attempts} '
                '${_attempts(weak.attempts)}. «${strong.category.label}» — ${strong.average}. '
                'Разрыв $spread баллов.',
          ),
        );
      } else if (spread >= 15 && weak.attempts == 1) {
        findings.add(
          Finding(
            title: 'Тип ситуации',
            tone: FindingTone.note,
            text:
                '«${weak.category.label}» сыгран один раз на ${weak.average}, '
                '«${strong.category.label}» — ${strong.average}. '
                'Повторите слабый тип, прежде чем считать это устойчивым пробелом.',
          ),
        );
      }
    }

    final played = {for (final read in categories) read.category};
    final missing = [
      for (final category in ScenarioCategory.values)
        if (!played.contains(category)) category.label,
    ];
    if (missing.isNotEmpty && played.isNotEmpty) {
      findings.add(
        Finding(
          title: 'Ещё не сыграно',
          tone: FindingTone.note,
          text:
              'Нет смен по типам: ${missing.join(', ')}. '
              'По ним вывод делать рано.',
        ),
      );
    }

    final slipping = competencies
        .where((read) => read.recentDelta <= -4)
        .toList();
    if (slipping.isNotEmpty) {
      final names = slipping
          .map((read) => '«${read.competency.label}» ${read.recentDelta}')
          .join(', ');
      findings.add(
        Finding(
          title: 'Свежий откат',
          tone: FindingTone.attention,
          text:
              'За последние смены очки упали: $names. '
              'Накопленный запас это пока прячет, в разборе уже видно.',
        ),
      );
    }

    final replay = _replayNote(runs);
    if (replay != null) findings.add(replay);

    return findings;
  }

  static Finding? _replayNote(List<RunSummary> runs) {
    final groups = <String, List<RunSummary>>{};
    for (final run in runs) {
      groups.putIfAbsent(run.scenarioId, () => []).add(run);
    }

    String? improved;
    var improvedBy = 0;
    String? worse;
    var worseBy = 0;
    groups.forEach((_, attempts) {
      if (attempts.length < 2) return;
      final delta = attempts.last.score - attempts.first.score;
      if (delta >= 10 && delta > improvedBy) {
        improvedBy = delta;
        improved = attempts.last.scenarioTitle;
      }
      if (delta <= -10 && -delta > worseBy) {
        worseBy = -delta;
        worse = attempts.last.scenarioTitle;
      }
    });

    if (improved != null) {
      return Finding(
        title: 'Повтор помог',
        tone: FindingTone.good,
        text:
            '«$improved»: последняя попытка на $improvedBy баллов выше первой.',
      );
    }
    if (worse != null) {
      return Finding(
        title: 'Повтор не закрепил',
        tone: FindingTone.attention,
        text: '«$worse»: последняя попытка на $worseBy баллов ниже первой.',
      );
    }
    return null;
  }

  static String? _nextStep(
    ConductorProfile profile,
    List<CompetencyRead> competencies,
    List<Scenario> scenarios,
  ) {
    if (scenarios.isEmpty || competencies.isEmpty) return null;

    final weak = competencies
        .where((read) => read.standing == CompetencyStanding.weak)
        .toList();
    final ranked = competencies.toList()
      ..sort((a, b) => a.points.compareTo(b.points));
    final spread = ranked.last.points - ranked.first.points;
    if (weak.isEmpty && spread < 4) return null;
    final target = weak.isNotEmpty
        ? (weak..sort((a, b) => a.points.compareTo(b.points))).first
        : ranked.first;

    final trainers = scenarios
        .where(
          (scenario) =>
              scenario.trainedCompetencies.contains(target.competency),
        )
        .toList();
    if (trainers.isEmpty) {
      return 'Подтянуть «${target.competency.label}»: ${_advice(target.competency)}';
    }

    int? personalBest(String id) {
      final scores = [
        for (final run in profile.runs)
          if (run.scenarioId == id) run.score,
      ];
      if (scores.isEmpty) return null;
      return scores.reduce((a, b) => a > b ? a : b);
    }

    trainers.sort((a, b) {
      final aScore = personalBest(a.id);
      final bScore = personalBest(b.id);
      if (aScore == null && bScore != null) return -1;
      if (bScore == null && aScore != null) return 1;
      return (aScore ?? 0).compareTo(bScore ?? 0);
    });
    final pick = trainers.first;
    final best = personalBest(pick.id);
    final attempt = best == null ? 'ещё не проходили' : 'лучший итог $best';
    return 'Следующая смена — «${pick.title}» ($attempt). '
        'Там тренируется «${target.competency.label}» '
        '(${target.points} очков). ${_advice(target.competency)}';
  }

  static String _advice(Competency competency) {
    return switch (competency) {
      Competency.empathy =>
        'Начинайте с признания ситуации, даже когда правило на вашей стороне.',
      Competency.regulations =>
        'Сверяйте реплику с пунктом в разборе: верный тон без нормы всё равно ошибка.',
      Competency.safety =>
        'Не пропускайте на борт и не скрывайте инцидент ради одного пассажира.',
      Competency.communication =>
        'Называйте следующий шаг: куда идти, кого позовёте, что будет дальше.',
      Competency.composure => 'На таймере короткий верный ответ лучше долгого.',
    };
  }

  static _Trend _trend(List<int> scores) {
    if (scores.length < 2) {
      return const _Trend(
        _TrendKind.short,
        'мало данных',
        'Одной смены мало, чтобы отделить навык от удачного ответа.',
      );
    }
    if (scores.length == 2) {
      final delta = scores[1] - scores[0];
      if (delta >= 8) {
        return _Trend(
          _TrendKind.rising,
          'лучше',
          'Вторая смена на $delta баллов выше первой.',
        );
      }
      if (delta <= -8) {
        return _Trend(
          _TrendKind.falling,
          'слабее',
          'Вторая смена на ${-delta} баллов ниже первой.',
        );
      }
      return _Trend(
        _TrendKind.flat,
        'ровно',
        'Две смены рядом: ${scores[0]} и ${scores[1]}. Роста пока нет.',
      );
    }

    final recentCount = scores.length >= 4 ? 2 : 1;
    final recent = scores.sublist(scores.length - recentCount);
    final earlier = scores.sublist(0, scores.length - recentCount);
    final delta = _average(recent) - _average(earlier);
    if (delta >= 8) {
      return _Trend(
        _TrendKind.rising,
        'растёт',
        'Последние смены в среднем на $delta баллов выше предыдущих '
            '(${_average(recent)} против ${_average(earlier)}).',
      );
    }
    if (delta <= -8) {
      return _Trend(
        _TrendKind.falling,
        'проседает',
        'Последние смены в среднем на ${-delta} баллов ниже предыдущих '
            '(${_average(recent)} против ${_average(earlier)}).',
      );
    }
    return _Trend(
      _TrendKind.flat,
      'ровно',
      'Последние смены держатся около прежнего уровня: '
          '${_average(recent)} против ${_average(earlier)}.',
    );
  }

  static int _average(List<int> values) {
    if (values.isEmpty) return 0;
    return (values.reduce((a, b) => a + b) / values.length).round();
  }

  static String _attempts(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'попытку';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'попытки';
    }
    return 'попыток';
  }
}

enum _TrendKind { rising, falling, flat, short }

class _Trend {
  const _Trend(this.kind, this.label, this.text);

  final _TrendKind kind;
  final String label;
  final String text;
}
