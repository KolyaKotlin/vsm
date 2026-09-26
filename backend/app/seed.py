"""Синтетические данные демо-среды.

Все сотрудники, бригады и депо вымышленные, фамилии помечены словом «демо».
Реальные персональные данные сотрудников и пассажиров в тренажёр не переносятся.
"""

from __future__ import annotations

import sqlite3

from .db import now_iso

ACHIEVEMENTS: list[tuple[str, str, str]] = [
    ("first_shift", "Первый рейс", "Завершён первый сценарий тренажёра."),
    ("balance_keeper", "Держит баланс", "Сценарий закрыт с лояльностью и безопасностью не ниже 75."),
    ("protocol_clean", "Чистый протокол", "Сценарий пройден без ошибочных решений и без таймаутов."),
    ("decisive", "Без промедления", "Три завершённых сценария, в которых ни один таймер не истёк."),
    ("negotiator", "Переговорщик", "Накоплено 10 очков компетенции «Работа с конфликтом»."),
    ("medic_ready", "Готов к медицинскому случаю", "Накоплено 8 очков компетенции «Медицинский протокол»."),
]

# Демо-сотрудники: первый — профиль игрока, остальные нужны, чтобы таблица
# лидеров показывала сравнение по бригаде, депо и компании.
DEMO_EMPLOYEES: list[dict[str, object]] = [
    {
        "login": "demo.trainee",
        "display_name": "Вы (демо-профиль)",
        "position": "Проводник",
        "brigade": "Бригада 1",
        "depot": "Депо Москва-Восточное",
        "xp": 0,
        "competencies": {},
    },
    {
        "login": "demo.morozov",
        "display_name": "А. Морозов (демо)",
        "position": "Проводник",
        "brigade": "Бригада 1",
        "depot": "Депо Москва-Восточное",
        "xp": 240,
        "competencies": {"conflict": 12, "regulations": 14, "service": 9, "medical": 6, "time_pressure": 7},
    },
    {
        "login": "demo.lebedeva",
        "display_name": "И. Лебедева (демо)",
        "position": "Проводник",
        "brigade": "Бригада 1",
        "depot": "Депо Москва-Восточное",
        "xp": 185,
        "competencies": {"conflict": 8, "regulations": 9, "service": 13, "medical": 4, "time_pressure": 5},
    },
    {
        "login": "demo.kim",
        "display_name": "С. Ким (демо)",
        "position": "Старший проводник",
        "brigade": "Бригада 2",
        "depot": "Депо Москва-Восточное",
        "xp": 310,
        "competencies": {"conflict": 15, "regulations": 18, "service": 11, "medical": 12, "time_pressure": 9},
    },
    {
        "login": "demo.saidov",
        "display_name": "Р. Саидов (демо)",
        "position": "Проводник",
        "brigade": "Бригада 2",
        "depot": "Депо Москва-Восточное",
        "xp": 90,
        "competencies": {"conflict": 4, "regulations": 5, "service": 6, "medical": 2, "time_pressure": 3},
    },
    {
        "login": "demo.novikova",
        "display_name": "Е. Новикова (демо)",
        "position": "Проводник",
        "brigade": "Бригада 4",
        "depot": "Депо Санкт-Петербург-Южное",
        "xp": 205,
        "competencies": {"conflict": 9, "regulations": 11, "service": 10, "medical": 8, "time_pressure": 6},
    },
    {
        "login": "demo.orlov",
        "display_name": "Д. Орлов (демо)",
        "position": "Проводник",
        "brigade": "Бригада 4",
        "depot": "Депо Санкт-Петербург-Южное",
        "xp": 150,
        "competencies": {"conflict": 7, "regulations": 8, "service": 7, "medical": 5, "time_pressure": 4},
    },
]

DEMO_NOTIFICATIONS: list[tuple[str, str, str]] = [
    (
        "new_scenario",
        "Новый сценарий: «Пассажиру стало плохо»",
        "В тренажёр добавлен медицинский сценарий. Пройдите его, чтобы открыть компетенцию «Медицинский протокол».",
    ),
    (
        "challenge",
        "Челлендж недели: ни одного истёкшего таймера",
        "Закройте три сценария, не допустив истечения таймера, и получите достижение «Без промедления».",
    ),
    (
        "expiring_points",
        "Баллы компетенции сгорают через 7 дней",
        "Компетенция «Работа с конфликтом» не тренировалась две недели. Без практики накопленные баллы по ней сгорают.",
    ),
]


def ensure_reference_data(connection: sqlite3.Connection) -> None:
    connection.executemany(
        "INSERT INTO achievements (code, title, description) VALUES (?, ?, ?) "
        "ON CONFLICT (code) DO UPDATE SET title = excluded.title, description = excluded.description",
        ACHIEVEMENTS,
    )


def ensure_demo_employees(connection: sqlite3.Connection) -> None:
    for employee in DEMO_EMPLOYEES:
        cursor = connection.execute(
            "INSERT INTO employees (login, display_name, position, brigade, depot, xp) VALUES (?, ?, ?, ?, ?, ?)",
            (
                employee["login"],
                employee["display_name"],
                employee["position"],
                employee["brigade"],
                employee["depot"],
                employee["xp"],
            ),
        )
        employee_id = cursor.lastrowid

        competencies: dict[str, int] = employee["competencies"]  # type: ignore[assignment]
        connection.executemany(
            "INSERT INTO competency_points (employee_id, competency, points) VALUES (?, ?, ?)",
            [(employee_id, competency, points) for competency, points in competencies.items()],
        )

    player = connection.execute("SELECT id FROM employees WHERE login = 'demo.trainee'").fetchone()
    connection.executemany(
        "INSERT INTO notifications (employee_id, kind, title, body, created_at) VALUES (?, ?, ?, ?, ?)",
        [(player["id"], kind, title, body, now_iso()) for kind, title, body in DEMO_NOTIFICATIONS],
    )
