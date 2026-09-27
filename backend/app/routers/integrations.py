"""Заглушки интеграции с внешними системами.

Контракт описан и работает на демо-данных, но реальных подключений к HR, LMS и
биллингу в прототипе нет: нет авторизации, подписи запросов и обмена ключами.
Ограничения перечислены в docs/LIMITS_AND_ROADMAP.md.
"""

from __future__ import annotations

import sqlite3

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from .. import billing, engine, profiles, service
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


class ChargePayload(BaseModel):
    """Доплата, оформляемая проводником на борту.

    Реквизиты оплаты в тренажёр не передаются: оплата проходит через утверждённый
    канал, а здесь фиксируются только повод, сумма и статус.
    """

    employee_id: int
    kind: billing.ChargeKind = Field(description="class_upgrade — повышение класса, service — платная услуга")
    title: str = Field(description="Что именно оплачивается, формулировкой для пассажира")
    amount_kopecks: int = Field(gt=0, description="Сумма в копейках: без чисел с плавающей точкой")
    attempt_id: int | None = Field(default=None, description="Заполняется, если доплата оформлена внутри сценария")
    channel: str = billing.DEFAULT_CHANNEL


@router.post("/billing/charges", summary="Оформить доплату за повышение класса или услугу")
def create_charge(
    payload: ChargePayload, connection: sqlite3.Connection = Depends(get_connection)
) -> dict[str, object]:
    """Регламент допускает повышение класса только с доплатой, поэтому оформление
    начинается здесь, а пересадка считается законной лишь после оплаты."""
    profiles.employee_row(connection, payload.employee_id)
    return billing.create_charge(
        connection,
        employee_id=payload.employee_id,
        kind=payload.kind,
        title=payload.title,
        amount_kopecks=payload.amount_kopecks,
        attempt_id=payload.attempt_id,
        channel=payload.channel,
    )


@router.post("/billing/charges/{charge_id}/pay", summary="Подтвердить оплату доплаты")
def pay_charge(charge_id: int, connection: sqlite3.Connection = Depends(get_connection)) -> dict[str, object]:
    return billing.mark_paid(connection, charge_id)


@router.post("/billing/charges/{charge_id}/refund", summary="Вернуть оплату")
def refund_charge(charge_id: int, connection: sqlite3.Connection = Depends(get_connection)) -> dict[str, object]:
    """Возврат за услугу, о платности которой пассажира не предупредили."""
    return billing.refund(connection, charge_id)


@router.get("/billing/charges", summary="Доплаты, оформленные проводником")
def list_charges(
    employee_id: int, connection: sqlite3.Connection = Depends(get_connection)
) -> list[dict[str, object]]:
    profiles.employee_row(connection, employee_id)
    return billing.charges(connection, employee_id)
