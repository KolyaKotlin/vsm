"""Загрузка сценариев из JSON-файлов.

Сценарии лежат отдельно от кода: чтобы добавить развилку или новую ситуацию,
достаточно поправить JSON, ядро движка при этом не меняется.
"""

from __future__ import annotations

import json
from pathlib import Path

from pydantic import ValidationError

from .engine import Scenario, ScenarioError, validate

SCENARIOS_DIR = Path(__file__).resolve().parent.parent / "scenarios"


def load_scenario(path: Path) -> Scenario:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ScenarioError(f"{path.name}: файл не является корректным JSON ({error})") from error

    try:
        scenario = Scenario.model_validate(raw)
    except ValidationError as error:
        raise ScenarioError(f"{path.name}: структура сценария не прошла проверку\n{error}") from error

    validate(scenario)
    return scenario


def load_all(directory: Path | None = None) -> dict[str, Scenario]:
    """Читает все сценарии каталога. Порядок файлов задаёт порядок в каталоге сценариев."""
    directory = directory or SCENARIOS_DIR
    scenarios: dict[str, Scenario] = {}

    for path in sorted(directory.glob("*.json")):
        scenario = load_scenario(path)
        if scenario.id in scenarios:
            raise ScenarioError(f"{path.name}: сценарий с идентификатором {scenario.id!r} уже загружен")
        scenarios[scenario.id] = scenario

    if not scenarios:
        raise ScenarioError(f"В каталоге {directory} не найдено ни одного сценария")

    return scenarios
