"""Профиль проводника и таблица лидеров."""

from __future__ import annotations

import sqlite3

from . import engine, scoring, views
from .service import EmployeeNotFound

LEADERBOARD_SCOPES = ("brigade", "depot", "company")


class InvalidAccessCode(Exception):
    """Код с учебной карточки не совпал ни с одним демо-профилем."""


def employee_row(connection: sqlite3.Connection, employee_id: int) -> sqlite3.Row:
    row = connection.execute("SELECT * FROM employees WHERE id = ?", (employee_id,)).fetchone()
    if row is None:
        raise EmployeeNotFound(employee_id)
    return row


def _brief(row: sqlite3.Row) -> views.EmployeeBrief:
    return views.EmployeeBrief(
        id=row["id"],
        login=row["login"],
        display_name=row["display_name"],
        position=row["position"],
        brigade=row["brigade"],
        depot=row["depot"],
        xp=row["xp"],
        level=scoring.level_for_xp(row["xp"]),
    )


def employee_by_access_code(connection: sqlite3.Connection, code: str) -> views.EmployeeBrief:
    row = connection.execute(
        "SELECT * FROM employees WHERE access_code = ?",
        (code.strip(),),
    ).fetchone()
    if row is None:
        raise InvalidAccessCode
    return _brief(row)


def employee_list(connection: sqlite3.Connection) -> list[views.EmployeeBrief]:
    return [
        _brief(row)
        for row in connection.execute("SELECT * FROM employees ORDER BY xp DESC")
    ]


def profile(connection: sqlite3.Connection, employee_id: int) -> views.ProfileView:
    row = employee_row(connection, employee_id)

    points = {
        item["competency"]: item["points"]
        for item in connection.execute(
            "SELECT competency, points FROM competency_points WHERE employee_id = ?", (employee_id,)
        )
    }
    competencies = [
        views.CompetencyProfile(competency=code, title=title, points=points.get(code, 0))
        for code, title in engine.COMPETENCY_TITLES.items()
    ]

    achievements = [
        views.UnlockedAchievement(code=item["code"], title=item["title"], description=item["description"])
        for item in connection.execute(
            "SELECT a.code, a.title, a.description FROM employee_achievements ea "
            "JOIN achievements a ON a.code = ea.code WHERE ea.employee_id = ? ORDER BY ea.awarded_at",
            (employee_id,),
        )
    ]

    attempts_finished = connection.execute(
        "SELECT COUNT(*) FROM attempts WHERE employee_id = ? AND status = 'finished'", (employee_id,)
    ).fetchone()[0]
    unread = connection.execute(
        "SELECT COUNT(*) FROM notifications WHERE employee_id = ? AND read_at IS NULL", (employee_id,)
    ).fetchone()[0]

    return views.ProfileView(
        employee_id=row["id"],
        login=row["login"],
        display_name=row["display_name"],
        position=row["position"],
        brigade=row["brigade"],
        depot=row["depot"],
        xp=row["xp"],
        level=scoring.level_for_xp(row["xp"]),
        xp_to_next_level=scoring.xp_to_next_level(row["xp"]),
        competencies=sorted(competencies, key=lambda item: -item.points),
        achievements=achievements,
        attempts_finished=attempts_finished,
        unread_notifications=unread,
    )


def leaderboard(
    connection: sqlite3.Connection, scope: str, employee_id: int | None = None
) -> list[views.LeaderboardRow]:
    """Рейтинг внутри бригады, депо или всей компании.

    Для бригады и депо нужен сотрудник, относительно которого считается срез.
    """
    if scope not in LEADERBOARD_SCOPES:
        raise ValueError(f"Неизвестный срез рейтинга: {scope}")

    query = "SELECT * FROM employees"
    params: tuple[object, ...] = ()

    if scope != "company":
        if employee_id is None:
            raise ValueError("Для среза по бригаде или депо нужен employee_id")
        row = employee_row(connection, employee_id)
        column = "brigade" if scope == "brigade" else "depot"
        query += f" WHERE {column} = ?"
        params = (row[column],)

    query += " ORDER BY xp DESC, display_name"

    return [
        views.LeaderboardRow(
            place=place,
            employee_id=row["id"],
            display_name=row["display_name"],
            brigade=row["brigade"],
            depot=row["depot"],
            xp=row["xp"],
            level=scoring.level_for_xp(row["xp"]),
        )
        for place, row in enumerate(connection.execute(query, params), start=1)
    ]


def notifications(connection: sqlite3.Connection, employee_id: int) -> list[views.NotificationView]:
    employee_row(connection, employee_id)
    return [
        views.NotificationView(
            id=row["id"],
            kind=row["kind"],
            title=row["title"],
            body=row["body"],
            created_at=row["created_at"],
            read_at=row["read_at"],
        )
        for row in connection.execute(
            "SELECT * FROM notifications WHERE employee_id = ? ORDER BY created_at DESC, id DESC",
            (employee_id,),
        )
    ]
