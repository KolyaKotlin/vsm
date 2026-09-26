"""Доплаты на борту: повышение класса и платные услуги.

Регламент допускает повышение класса обслуживания только с доплатой через
утверждённый канал, а услугу, о платности которой пассажира не предупредили,
требуется вернуть. Здесь описан именно этот контракт: тренажёр фиксирует факт и
сумму, а реквизиты оплаты не принимает и не хранит.

Реального подключения к биллингу в прототипе нет, ограничения перечислены в
docs/LIMITS_AND_ROADMAP.md.
"""

from __future__ import annotations

import sqlite3
from typing import Literal

from .db import now_iso

ChargeKind = Literal["class_upgrade", "service"]
ChargeStatus = Literal["pending", "paid", "refunded"]

# Канал по умолчанию: мобильная касса проводника из регламента обслуживания.
DEFAULT_CHANNEL = "mobile_cash"

KIND_TITLES: dict[str, str] = {
    "class_upgrade": "Повышение класса обслуживания",
    "service": "Платная услуга на борту",
}


class BillingError(Exception):
    """Недопустимый переход состояния доплаты."""


class ChargeNotFound(Exception):
    pass


def create_charge(
    connection: sqlite3.Connection,
    *,
    employee_id: int,
    kind: ChargeKind,
    title: str,
    amount_kopecks: int,
    attempt_id: int | None = None,
    channel: str = DEFAULT_CHANNEL,
) -> dict[str, object]:
    """Оформляет доплату. Пока она не оплачена, пересадка не считается оформленной."""
    if amount_kopecks <= 0:
        raise BillingError("Сумма доплаты должна быть больше нуля")

    moment = now_iso()
    cursor = connection.execute(
        "INSERT INTO billing_charges "
        "(employee_id, attempt_id, kind, title, amount_kopecks, channel, status, created_at, updated_at) "
        "VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?)",
        (employee_id, attempt_id, kind, title, amount_kopecks, channel, moment, moment),
    )
    return charge(connection, int(cursor.lastrowid))


def charge(connection: sqlite3.Connection, charge_id: int) -> dict[str, object]:
    row = connection.execute("SELECT * FROM billing_charges WHERE id = ?", (charge_id,)).fetchone()
    if row is None:
        raise ChargeNotFound(charge_id)
    return dict(row)


def charges(connection: sqlite3.Connection, employee_id: int) -> list[dict[str, object]]:
    return [
        dict(row)
        for row in connection.execute(
            "SELECT * FROM billing_charges WHERE employee_id = ? ORDER BY created_at DESC, id DESC",
            (employee_id,),
        )
    ]


STATUS_TITLES: dict[str, str] = {
    "pending": "ожидает оплаты",
    "paid": "оплачена",
    "refunded": "возвращена",
}


def mark_paid(connection: sqlite3.Connection, charge_id: int) -> dict[str, object]:
    return _move(connection, charge_id, expected="pending", target="paid", action="подтвердить оплату")


def refund(connection: sqlite3.Connection, charge_id: int) -> dict[str, object]:
    """Возврат за услугу, о платности которой пассажира не предупредили."""
    return _move(connection, charge_id, expected="paid", target="refunded", action="оформить возврат")


def _move(
    connection: sqlite3.Connection,
    charge_id: int,
    *,
    expected: ChargeStatus,
    target: ChargeStatus,
    action: str,
) -> dict[str, object]:
    current = charge(connection, charge_id)
    if current["status"] != expected:
        raise BillingError(
            f"Доплата {charge_id} уже {STATUS_TITLES[str(current['status'])]}, {action} нельзя"
        )

    connection.execute(
        "UPDATE billing_charges SET status = ?, updated_at = ? WHERE id = ?",
        (target, now_iso(), charge_id),
    )
    return charge(connection, charge_id)
