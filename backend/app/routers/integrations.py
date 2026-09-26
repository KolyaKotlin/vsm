"""Заглушки интеграции с внешними системами.

Контракт описан и работает на демо-данных, но реальных подключений к HR и LMS
в прототипе нет: нет авторизации, подписи запросов и обмена ключами. Ограничения
перечислены в docs/LIMITS_AND_ROADMAP.md.
"""

from __future__ import annotations

import sqlite3

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from .. import engine, profiles, service
from ..deps import get_connection

router = APIRouter(prefix="/api/integrations", tags=["Интеграции"])


class HrEmployeePayload(BaseModel):
    """Сотрудник, приходящий из HR-системы."""

    hr_ref: str = Field(description="Идентификатор сотрудника в HR-системе")
    login: str
    display_name: str
    position: str = "Проводник"
    brigade: str
    depot: str


@router.post("/hr/employees", summary="Принять сотрудника из HR-системы")
def upsert_employee(
    payload: HrEmployeePayload, connection: sqlite3.Connection = Depends(get_connection)
) -> dict[str, object]:
    """Создаёт или обновляет проводника по данным HR.

    Прогресс и очки при обновлении не сбрасываются: меняются только кадровые поля.
    """
    connection.execute(
        "INSERT INTO employees (login, display_name, position, brigade, depot, hr_ref) VALUES (?, ?, ?, ?, ?, ?) "
        "ON CONFLICT (login) DO UPDATE SET display_name = excluded.display_name, position = excluded.position, "
        "brigade = excluded.brigade, depot = excluded.depot, hr_ref = excluded.hr_ref",
        (payload.login, payload.display_name, payload.position, payload.brigade, payload.depot, payload.hr_ref),
    )
    row = connection.execute("SELECT id FROM employees WHERE login = ?", (payload.login,)).fetchone()
    return {"employee_id": row["id"], "login": payload.login, "hr_ref": payload.hr_ref}


@router.get("/lms/results/{employee_id}", summary="Отдать результаты обучения в LMS")
def export_results(employee_id: int, connection: sqlite3.Connection = Depends(get_connection)) -> dict[str, object]:
    """Выгрузка для системы обучения: уровень, компетенции и закрытые сценарии."""
    profile = profiles.profile(connection, employee_id)
    history = service.attempt_history(connection, employee_id)

    return {
        "employee": {
            "employee_id": profile.employee_id,
            "login": profile.login,
            "display_name": profile.display_name,
            "brigade": profile.brigade,
            "depot": profile.depot,
        },
        "level": profile.level,
        "xp": profile.xp,
        "competencies": [
            {
                "code": item.competency,
                "title": engine.COMPETENCY_TITLES.get(item.competency, item.competency),
                "points": item.points,
            }
            for item in profile.competencies
        ],
        "achievements": [item.code for item in profile.achievements],
        "attempts": [
            {
                "scenario_id": item["scenario_id"],
                "passed": item["passed"],
                "loyalty": item["loyalty"],
                "safety": item["safety"],
                "finished_at": item["finished_at"],
            }
            for item in history
            if item["status"] == "finished"
        ],
    }
