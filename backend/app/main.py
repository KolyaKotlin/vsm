"""Точка входа FastAPI.

Документация API доступна на /docs (Swagger) и /openapi.json.
"""

from __future__ import annotations

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from . import billing, engine, service
from .db import init_db
from .routers import catalog, employees, integrations, leaderboard, play

DESCRIPTION = """
Геймифицированный тренажёр для проводников ВСМ.

Проводник проходит нештатные ситуации на борту, принимает решения под таймером
и видит, как каждое решение двигает «лояльность пассажира» и «рейтинг
безопасности». По итогам сценария начисляются очки компетенций, выдаются
достижения и обновляется место в рейтинге бригады, депо и компании.

Демо-среда работает только на синтетических данных.
"""

ALLOWED_ORIGINS = os.environ.get(
    "VSM_ALLOWED_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173"
).split(",")


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Сценарии проверяются на старте: битая ссылка на узел не доживёт до демонстрации.
    init_db()
    service.reload_catalog()
    yield


app = FastAPI(
    title="Тренажёр проводников ВСМ",
    description=DESCRIPTION,
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(catalog.router)
app.include_router(play.router)
app.include_router(employees.router)
app.include_router(leaderboard.router)
app.include_router(integrations.router)


@app.exception_handler(service.AttemptNotFound)
async def attempt_not_found(_: Request, error: service.AttemptNotFound) -> JSONResponse:
    return JSONResponse(status_code=404, content={"detail": f"Попытка {error.args[0]} не найдена"})


@app.exception_handler(service.ScenarioNotFound)
async def scenario_not_found(_: Request, error: service.ScenarioNotFound) -> JSONResponse:
    return JSONResponse(status_code=404, content={"detail": f"Сценарий {error.args[0]!r} не найден"})


@app.exception_handler(service.EmployeeNotFound)
async def employee_not_found(_: Request, error: service.EmployeeNotFound) -> JSONResponse:
    return JSONResponse(status_code=404, content={"detail": f"Проводник {error.args[0]} не найден"})


@app.exception_handler(billing.ChargeNotFound)
async def charge_not_found(_: Request, error: billing.ChargeNotFound) -> JSONResponse:
    return JSONResponse(status_code=404, content={"detail": f"Доплата {error.args[0]} не найдена"})


@app.exception_handler(billing.BillingError)
async def billing_error(_: Request, error: billing.BillingError) -> JSONResponse:
    return JSONResponse(status_code=400, content={"detail": str(error)})


@app.exception_handler(engine.ScenarioError)
async def scenario_error(_: Request, error: engine.ScenarioError) -> JSONResponse:
    # Некорректное действие пользователя не должно выглядеть как падение сервера.
    return JSONResponse(status_code=400, content={"detail": str(error)})


@app.get("/api/health", tags=["Служебные"], summary="Проверка готовности сервиса")
def health() -> dict[str, object]:
    return {"status": "ok", "scenarios": len(service.catalog())}
