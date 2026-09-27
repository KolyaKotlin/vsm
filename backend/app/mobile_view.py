"""Вид сценария для мобильного приложения.

Сайт играет через попытки: качество ответа на экран не уходит. Мобильный
движок считает ветки у себя, поэтому ему нужно то же дерево, что лежит в
каталоге сервера, в его собственном формате. Источник один — файлы сценариев.
"""

from __future__ import annotations

from .engine import Scenario

_COMPETENCY = {
    "service": "empathy",
    "conflict": "communication",
    "medical": "safety",
    "time_pressure": "composure",
    "regulations": "regulations",
}

_CATEGORY = {
    "regulations": "safety",
    "medical": "medical",
    "conflict": "conflict",
    "service": "service",
}

_VERDICT = {"optimal": "good", "acceptable": "acceptable", "harmful": "bad"}
_ROLE = ["acknowledge", "rule", "solution", "assure"]


def _class_code(service_class: str) -> str:
    text = service_class.lower()
    if "бизнес" in text:
        return "business"
    if "комфорт" in text:
        return "comfort"
    if "перв" in text:
        return "first"
    return "standard"


def _effects(raw: dict) -> dict:
    competencies = {
        _COMPETENCY.get(code, code): points
        for code, points in (raw.get("competencies") or {}).items()
    }
    return {
        "loyalty": raw.get("loyalty", 0),
        "safety": raw.get("safety", 0),
        "competencies": competencies,
    }


def scenario_for_mobile(scenario: Scenario) -> dict:
    situation_ids = [
        node_id for node_id, node in scenario.nodes.items() if node.kind == "situation"
    ]
    role_by_node = {
        node_id: _ROLE[index] if index < len(_ROLE) else "none"
        for index, node_id in enumerate(situation_ids)
    }
    scenes = []
    for node_id, node in scenario.nodes.items():
        if node.kind == "outcome":
            scenes.append(
                {
                    "id": node_id,
                    "speaker": {"name": "Проводник"},
                    "line": node.verdict or node.narration,
                    "narration": node.narration,
                    "choices": [],
                    "ending": {
                        "title": node.verdict or "Ситуация завершена",
                        "text": node.narration,
                        "tone": "failure" if node.critical_failure else "success",
                    },
                }
            )
            continue
        scenes.append(
            {
                "id": node_id,
                "speaker": {"name": "Пассажир"},
                "line": node.passenger or "",
                "narration": node.narration,
                "timerSeconds": node.timer_seconds,
                "onTimeout": None
                if node.timeout is None
                else {
                    "text": node.timeout.text,
                    "effects": _effects(node.timeout.effects.model_dump()),
                    "feedback": {"verdict": "bad", "why": node.timeout.debrief},
                    "next": node.timeout.next,
                },
                "choices": [
                    {
                        "id": option.id,
                        "text": option.text,
                        "roleStep": role_by_node.get(node_id, "none"),
                        "effects": _effects(option.effects.model_dump()),
                        "feedback": {
                            "verdict": _VERDICT.get(option.quality, "acceptable"),
                            "why": option.debrief,
                        },
                        "next": option.next,
                    }
                    for option in option_list(node)
                ],
            }
        )
    return {
        "id": scenario.id,
        "title": scenario.title,
        "summary": scenario.summary,
        "category": _CATEGORY.get(scenario.primary_competency, "service"),
        "difficulty": 2,
        "source": f"Ситуация {scenario.number}. {scenario.section}",
        "competencies": [_COMPETENCY.get(scenario.primary_competency, "regulations")],
        "context": {
            "route": "Москва — Санкт-Петербург",
            "train": "ВСМ-001",
            "carClass": _class_code(scenario.service_class),
            "phase": scenario.car,
            "clock": "12:00",
        },
        "initial": {"loyalty": scenario.initial_loyalty, "safety": scenario.initial_safety},
        "startScene": scenario.start,
        "scenes": scenes,
    }


def option_list(node):
    return node.options
