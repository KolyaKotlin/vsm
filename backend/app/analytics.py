"""Аналитика компетенций: что освоено, что проседает и что делать дальше."""

from __future__ import annotations

import sqlite3

from . import engine, service, views

STRONG_POINTS = 10
WEAK_POINTS = 4

TIMEOUT_SHARE_ALERT = 0.2
HARMFUL_SHARE_ALERT = 0.3


def build(connection: sqlite3.Connection, employee_id: int) -> views.AnalyticsView:
    totals = connection.execute(
        "SELECT COUNT(*) AS finished, COALESCE(SUM(passed), 0) AS passed, "
        "AVG(loyalty) AS avg_loyalty, AVG(safety) AS avg_safety "
        "FROM attempts WHERE employee_id = ? AND status = 'finished'",
        (employee_id,),
    ).fetchone()

    steps = service.raw_steps_json(connection, employee_id)
    timeouts = sum(1 for step in steps if step.get("timed_out"))
    harmful = sum(1 for step in steps if step.get("quality") == "harmful")

    points = {
        row["competency"]: row["points"]
        for row in connection.execute(
            "SELECT competency, points FROM competency_points WHERE employee_id = ?", (employee_id,)
        )
    }
    best = max(points.values(), default=0)

    competencies: list[views.CompetencyAnalytics] = []
    gaps: list[str] = []
    for code, title in engine.COMPETENCY_TITLES.items():
        value = points.get(code, 0)
        if value >= STRONG_POINTS:
            status = "освоено"
        elif value > WEAK_POINTS:
            status = "в работе"
        else:
            status = "проседает"
            gaps.append(title)

        competencies.append(
            views.CompetencyAnalytics(
                competency=code,
                title=title,
                points=value,
                # Доля от самой сильной компетенции: показывает перекос в подготовке.
                share=round(value / best, 2) if best else 0.0,
                status=status,
            )
        )

    return views.AnalyticsView(
        employee_id=employee_id,
        attempts_finished=totals["finished"],
        attempts_passed=totals["passed"],
        timeouts=timeouts,
        harmful_choices=harmful,
        average_loyalty=round(totals["avg_loyalty"]) if totals["avg_loyalty"] is not None else None,
        average_safety=round(totals["avg_safety"]) if totals["avg_safety"] is not None else None,
        competencies=sorted(competencies, key=lambda item: -item.points),
        gaps=gaps,
        recommendations=_recommendations(steps, timeouts, harmful, gaps),
    )


def _recommendations(
    steps: list[dict[str, object]], timeouts: int, harmful: int, gaps: list[str]
) -> list[str]:
    """Выводы о пользователе, а не пересказ лога действий."""
    if not steps:
        return ["Пройдите первый сценарий — после него появится разбор компетенций."]

    advice: list[str] = []
    total = len(steps)

    if timeouts / total >= TIMEOUT_SHARE_ALERT:
        advice.append(
            "Таймеры истекают слишком часто: отрабатывайте первую фразу, которая признаёт ситуацию, "
            "чтобы не терять секунды на обдумывание."
        )
    if harmful / total >= HARMFUL_SHARE_ALERT:
        advice.append(
            "Много ошибочных решений: перечитайте порядок «признать ситуацию — обозначить правило — "
            "предложить решение — заверить»."
        )

    safety_drops = sum(1 for step in steps if int(step.get("safety_delta", 0)) < 0)
    loyalty_drops = sum(1 for step in steps if int(step.get("loyalty_delta", 0)) < 0)
    if safety_drops > loyalty_drops:
        advice.append(
            "Вы чаще жертвуете безопасностью в пользу пассажира. Уступка в обход регламента почти всегда "
            "возвращается новым инцидентом."
        )
    elif loyalty_drops > safety_drops:
        advice.append(
            "Регламент вы держите, но лояльность проседает: добавляйте эмпатию и альтернативу, "
            "а не только ссылку на правило."
        )

    for title in gaps:
        advice.append(f"Компетенция «{title}» почти не тренировалась — возьмите сценарий, где она основная.")

    return advice
