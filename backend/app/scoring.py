"""Начисление очков, уровней и достижений по итогам сценария.

Правила собраны в одном месте и вынесены в константы: на защите их видно
целиком и можно изменить одной строкой.
"""

from __future__ import annotations

import sqlite3

from . import engine
from .db import now_iso

LEVEL_XP_STEP = 100

XP_FOR_FINISH = 20
XP_FOR_PASSED = 30
XP_FOR_NO_TIMEOUTS = 10
XP_PENALTY_PER_HARMFUL = 5

BALANCE_ACHIEVEMENT_THRESHOLD = 75
DECISIVE_ATTEMPTS_REQUIRED = 3
NEGOTIATOR_POINTS_REQUIRED = 10
MEDIC_POINTS_REQUIRED = 8


def level_for_xp(xp: int) -> int:
    return xp // LEVEL_XP_STEP + 1


def xp_to_next_level(xp: int) -> int:
    return LEVEL_XP_STEP - xp % LEVEL_XP_STEP


def xp_for_summary(summary: engine.Summary) -> int:
    xp = XP_FOR_FINISH
    if summary.passed:
        xp += XP_FOR_PASSED
    if summary.timeouts == 0:
        xp += XP_FOR_NO_TIMEOUTS
    xp -= XP_PENALTY_PER_HARMFUL * summary.harmful_choices
    return max(0, xp)


def apply_results(connection: sqlite3.Connection, employee_id: int, summary: engine.Summary) -> dict[str, object]:
    """Записывает очки компетенций, опыт и выдаёт новые достижения."""
    for competency, points in summary.competency_gain.items():
        if points == 0:
            continue
        connection.execute(
            "INSERT INTO competency_points (employee_id, competency, points) VALUES (?, ?, ?) "
            "ON CONFLICT (employee_id, competency) DO UPDATE SET points = points + excluded.points",
            (employee_id, competency, points),
        )

    xp = xp_for_summary(summary)
    connection.execute("UPDATE employees SET xp = xp + ? WHERE id = ?", (xp, employee_id))

    unlocked = _award_achievements(connection, employee_id, summary)
    return {"xp_awarded": xp, "unlocked_achievements": unlocked}


def _award_achievements(
    connection: sqlite3.Connection, employee_id: int, summary: engine.Summary
) -> list[dict[str, str]]:
    earned: list[str] = ["first_shift"]

    if summary.loyalty >= BALANCE_ACHIEVEMENT_THRESHOLD and summary.safety >= BALANCE_ACHIEVEMENT_THRESHOLD:
        earned.append("balance_keeper")

    if summary.harmful_choices == 0 and summary.timeouts == 0:
        earned.append("protocol_clean")

    clean_attempts = connection.execute(
        """
        SELECT COUNT(*) FROM attempts a
        WHERE a.employee_id = ? AND a.status = 'finished'
          AND NOT EXISTS (
              SELECT 1 FROM attempt_steps s
              WHERE s.attempt_id = a.id AND json_extract(s.payload, '$.timed_out') = 1
          )
        """,
        (employee_id,),
    ).fetchone()[0]
    if clean_attempts >= DECISIVE_ATTEMPTS_REQUIRED:
        earned.append("decisive")

    points = {
        row["competency"]: row["points"]
        for row in connection.execute(
            "SELECT competency, points FROM competency_points WHERE employee_id = ?", (employee_id,)
        )
    }
    if points.get("conflict", 0) >= NEGOTIATOR_POINTS_REQUIRED:
        earned.append("negotiator")
    if points.get("medical", 0) >= MEDIC_POINTS_REQUIRED:
        earned.append("medic_ready")

    unlocked: list[dict[str, str]] = []
    for code in earned:
        cursor = connection.execute(
            "INSERT INTO employee_achievements (employee_id, code, awarded_at) VALUES (?, ?, ?) "
            "ON CONFLICT (employee_id, code) DO NOTHING",
            (employee_id, code, now_iso()),
        )
        if cursor.rowcount:
            row = connection.execute(
                "SELECT code, title, description FROM achievements WHERE code = ?", (code,)
            ).fetchone()
            unlocked.append({"code": row["code"], "title": row["title"], "description": row["description"]})
            connection.execute(
                "INSERT INTO notifications (employee_id, kind, title, body, created_at) VALUES (?, ?, ?, ?, ?)",
                (employee_id, "achievement", f"Новое достижение: {row['title']}", row["description"], now_iso()),
            )

    return unlocked
