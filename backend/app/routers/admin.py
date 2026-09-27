"""Кабинет методиста. Код методиста не открывает профиль проводника."""

from __future__ import annotations

import logging
import sqlite3

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from .. import service, studio, views
from ..deps import get_connection
from ..engine import ScenarioError

router = APIRouter(prefix="/api/admin", tags=["Методист"])
logger = logging.getLogger(__name__)


class AdminCode(BaseModel):
    code: str = Field(min_length=1, max_length=64)


class NewEmployee(BaseModel):
    display_name: str
    position: str = "Проводник"
    brigade: str = "Бригада 1"
    depot: str = "Депо Москва-Восточное"


class NewScenario(BaseModel):
    title: str
    summary: str
    section: str = "Добавленные"
    car: str = "Вагон 1"
    service_class: str = "стандарт"
    primary_competency: str = "service"
    scene: str
    passenger: str
    rule: str
    offer: str = ""
    refusal: str
    critical: bool = False


def _guard(code: str) -> None:
    try:
        studio.check_code(code)
    except studio.AdminError as error:
        raise HTTPException(status_code=401, detail=str(error)) from None


@router.post("/session", summary="Проверить код методиста")
def open_session(payload: AdminCode) -> dict[str, bool]:
    _guard(payload.code)
    return {"ok": True}


@router.get("/employees", summary="Проводники и их коды")
def employees(
    x_admin_code: str = Header(default=""),
    connection: sqlite3.Connection = Depends(get_connection),
) -> list[dict]:
    _guard(x_admin_code)
    return studio.list_employees(connection)


@router.post("/employees", summary="Завести проводника и выдать код")
def create_employee(
    payload: NewEmployee,
    x_admin_code: str = Header(default=""),
    connection: sqlite3.Connection = Depends(get_connection),
) -> dict:
    _guard(x_admin_code)
    try:
        return studio.create_employee(connection, payload.model_dump())
    except studio.AdminError as error:
        raise HTTPException(status_code=400, detail=str(error)) from None


@router.post("/employees/{employee_id}/code", summary="Выдать проводнику новый код")
def reissue(
    employee_id: int,
    x_admin_code: str = Header(default=""),
    connection: sqlite3.Connection = Depends(get_connection),
) -> dict:
    _guard(x_admin_code)
    try:
        return studio.reissue_code(connection, employee_id)
    except studio.AdminError as error:
        raise HTTPException(status_code=404, detail=str(error)) from None


@router.get("/scenarios", response_model=list[views.ScenarioBrief], summary="Ситуации каталога")
def scenarios(x_admin_code: str = Header(default="")) -> list[views.ScenarioBrief]:
    _guard(x_admin_code)
    return service.scenario_list()


@router.post("/scenarios", response_model=views.ScenarioBrief, summary="Добавить ситуацию")
def create_scenario(
    payload: NewScenario,
    x_admin_code: str = Header(default=""),
    connection: sqlite3.Connection = Depends(get_connection),
) -> views.ScenarioBrief:
    _guard(x_admin_code)
    try:
        scenario = studio.save_scenario(payload.model_dump())
        studio.announce_scenario(connection, scenario.title)
    except studio.AdminError as error:
        raise HTTPException(status_code=400, detail=str(error)) from None
    except ScenarioError as error:
        raise HTTPException(status_code=400, detail=str(error)) from None
    except Exception as error:
        logger.exception("Не удалось добавить ситуацию")
        raise HTTPException(status_code=400, detail=f"Не удалось добавить ситуацию: {error}") from None
    return views.scenario_brief(scenario)
