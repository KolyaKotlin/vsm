"""Профиль, история попыток, аналитика и уведомления."""

from __future__ import annotations

import sqlite3

from fastapi import APIRouter, Depends, HTTPException

from .. import analytics, profiles, service, views
from ..db import now_iso
from ..deps import get_connection

router = APIRouter(prefix="/api", tags=["Проводник"])


@router.get("/employees", response_model=list[views.EmployeeBrief], summary="Список проводников демо-среды")
def list_employees(connection: sqlite3.Connection = Depends(get_connection)) -> list[views.EmployeeBrief]:
    return profiles.employee_list(connection)


@router.get("/employees/{employee_id}/profile", response_model=views.ProfileView, summary="Игровой профиль")
def get_profile(employee_id: int, connection: sqlite3.Connection = Depends(get_connection)) -> views.ProfileView:
    return profiles.profile(connection, employee_id)


@router.get("/employees/{employee_id}/attempts", summary="История попыток")
def get_attempts(employee_id: int, connection: sqlite3.Connection = Depends(get_connection)) -> list[dict]:
    profiles.employee_row(connection, employee_id)
    return service.attempt_history(connection, employee_id)


@router.get(
    "/employees/{employee_id}/analytics",
    response_model=views.AnalyticsView,
    summary="Аналитика компетенций и пробелов",
)
def get_analytics(employee_id: int, connection: sqlite3.Connection = Depends(get_connection)) -> views.AnalyticsView:
    profiles.employee_row(connection, employee_id)
    return analytics.build(connection, employee_id)


@router.get(
    "/employees/{employee_id}/notifications",
    response_model=list[views.NotificationView],
    summary="Уведомления о сценариях, челленджах и сгорающих баллах",
)
def get_notifications(
    employee_id: int, connection: sqlite3.Connection = Depends(get_connection)
) -> list[views.NotificationView]:
    return profiles.notifications(connection, employee_id)


@router.post("/notifications/{notification_id}/read", summary="Отметить уведомление прочитанным")
def mark_notification_read(
    notification_id: int, connection: sqlite3.Connection = Depends(get_connection)
) -> dict[str, object]:
    cursor = connection.execute(
        "UPDATE notifications SET read_at = ? WHERE id = ? AND read_at IS NULL", (now_iso(), notification_id)
    )
    if cursor.rowcount == 0 and connection.execute(
        "SELECT 1 FROM notifications WHERE id = ?", (notification_id,)
    ).fetchone() is None:
        raise HTTPException(status_code=404, detail="Уведомление не найдено")
    return {"id": notification_id, "read": True}
