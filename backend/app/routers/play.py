"""Прохождение сценария: старт, выбор, таймаут."""

from __future__ import annotations

import sqlite3

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from .. import service, views
from ..deps import get_connection

router = APIRouter(prefix="/api/attempts", tags=["Прохождение"])


class StartAttemptRequest(BaseModel):
    employee_id: int
    scenario_id: str


class ChoiceRequest(BaseModel):
    option_id: str


@router.post("", response_model=views.AttemptView, summary="Начать сценарий")
def start_attempt(
    payload: StartAttemptRequest, connection: sqlite3.Connection = Depends(get_connection)
) -> views.AttemptView:
    return service.start_attempt(connection, payload.employee_id, payload.scenario_id)


@router.get("/{attempt_id}", response_model=views.AttemptView, summary="Текущее состояние попытки")
def get_attempt(attempt_id: int, connection: sqlite3.Connection = Depends(get_connection)) -> views.AttemptView:
    return service.get_attempt(connection, attempt_id)


@router.post("/{attempt_id}/choice", response_model=views.AttemptView, summary="Принять решение")
def choose(
    attempt_id: int, payload: ChoiceRequest, connection: sqlite3.Connection = Depends(get_connection)
) -> views.AttemptView:
    """Применяет выбор проводника.

    Если серверный дедлайн узла уже прошёл, вместо выбора применяется исход по
    таймауту — время на решение контролирует сервер, а не браузер.
    """
    return service.choose(connection, attempt_id, payload.option_id)


@router.post("/{attempt_id}/timeout", response_model=views.AttemptView, summary="Сообщить об истечении времени")
def expire(attempt_id: int, connection: sqlite3.Connection = Depends(get_connection)) -> views.AttemptView:
    return service.expire(connection, attempt_id)
