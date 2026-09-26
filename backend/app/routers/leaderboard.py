"""Таблица лидеров по бригаде, депо и компании."""

from __future__ import annotations

import sqlite3
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query

from .. import profiles, views
from ..deps import get_connection

router = APIRouter(prefix="/api/leaderboard", tags=["Рейтинг"])


@router.get("", response_model=list[views.LeaderboardRow], summary="Рейтинг проводников")
def get_leaderboard(
    scope: Literal["brigade", "depot", "company"] = "brigade",
    employee_id: int | None = Query(default=None, description="Нужен для срезов по бригаде и депо"),
    connection: sqlite3.Connection = Depends(get_connection),
) -> list[views.LeaderboardRow]:
    try:
        return profiles.leaderboard(connection, scope, employee_id)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
