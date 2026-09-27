"""Каталог для мобильного приложения. Тот же сервер, что и у сайта."""

from __future__ import annotations

from fastapi import APIRouter

from .. import service
from ..mobile_view import scenario_for_mobile

router = APIRouter(prefix="/api/mobile", tags=["Мобильное приложение"])


@router.get("/scenarios", summary="Ситуации в формате мобильного тренажёра")
def scenarios() -> list[dict]:
    ordered = sorted(service.catalog().values(), key=lambda scenario: (scenario.number or 999, scenario.title))
    return [scenario_for_mobile(scenario) for scenario in ordered]
