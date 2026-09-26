"""Каталог сценариев."""

from __future__ import annotations

from fastapi import APIRouter

from .. import engine, service, views

router = APIRouter(prefix="/api/scenarios", tags=["Сценарии"])


@router.get("", response_model=list[views.ScenarioBrief], summary="Список доступных сценариев")
def list_scenarios() -> list[views.ScenarioBrief]:
    return service.scenario_list()


@router.post("/reload", response_model=list[views.ScenarioBrief], summary="Перечитать JSON-сценарии")
def reload_scenarios() -> list[views.ScenarioBrief]:
    """Подхватывает правки сценариев без перезапуска сервера.

    Используется при добавлении развилки: поправили JSON — вызвали этот метод.
    """
    service.reload_catalog()
    return service.scenario_list()


@router.get("/{scenario_id}", response_model=views.ScenarioBrief, summary="Карточка сценария")
def get_scenario(scenario_id: str) -> views.ScenarioBrief:
    scenario = service.get_scenario(scenario_id)
    return views.ScenarioBrief(
        id=scenario.id,
        title=scenario.title,
        summary=scenario.summary,
        service_class=scenario.service_class,
        car=scenario.car,
        primary_competency=scenario.primary_competency,
    )


@router.get("/{scenario_id}/source", response_model=engine.Scenario, summary="Исходник сценария для методиста")
def get_scenario_source(scenario_id: str) -> engine.Scenario:
    """Полное дерево сценария вместе с эффектами и разборами.

    Метод методистский: проходящему сценарий эти данные не отдаются, иначе
    правильный вариант виден заранее.
    """
    return service.get_scenario(scenario_id)
