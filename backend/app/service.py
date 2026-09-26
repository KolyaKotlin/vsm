"""Сценарная сессия: связывает движок, серверные таймеры и базу.

Движок остаётся чистым, здесь появляются время и хранение: дедлайн шага,
история попытки, начисление очков по завершении.
"""

from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timedelta, timezone
from functools import lru_cache

from . import engine, scoring, views
from .db import now_iso, parse_iso

# Запас на сетевую задержку: решение, отправленное в последнюю секунду, не
# должно превращаться в таймаут из-за времени в пути.
TIMER_GRACE_SECONDS = 2


class AttemptNotFound(Exception):
    pass


class ScenarioNotFound(Exception):
    pass


class EmployeeNotFound(Exception):
    pass


@lru_cache(maxsize=1)
def catalog() -> dict[str, engine.Scenario]:
    from . import scenarios

    return scenarios.load_all()


def reload_catalog() -> dict[str, engine.Scenario]:
    """Перечитывает JSON-сценарии без перезапуска сервера.

    Нужно для правки сценария на ходу: поправили файл — вызвали перезагрузку.
    """
    catalog.cache_clear()
    return catalog()


def get_scenario(scenario_id: str) -> engine.Scenario:
    scenario = catalog().get(scenario_id)
    if scenario is None:
        raise ScenarioNotFound(scenario_id)
    return scenario


def scenario_list() -> list[views.ScenarioBrief]:
    return [
        views.ScenarioBrief(
            id=scenario.id,
            title=scenario.title,
            summary=scenario.summary,
            service_class=scenario.service_class,
            car=scenario.car,
            primary_competency=scenario.primary_competency,
        )
        for scenario in catalog().values()
    ]


def start_attempt(connection: sqlite3.Connection, employee_id: int, scenario_id: str) -> views.AttemptView:
    scenario = get_scenario(scenario_id)
    if connection.execute("SELECT 1 FROM employees WHERE id = ?", (employee_id,)).fetchone() is None:
        raise EmployeeNotFound(employee_id)

    state = engine.start_attempt(scenario)
    node = engine.current_node(scenario, state)
    deadline = _deadline_for(node)

    cursor = connection.execute(
        "INSERT INTO attempts (employee_id, scenario_id, status, node_id, loyalty, safety, deadline_at, started_at) "
        "VALUES (?, ?, 'in_progress', ?, ?, ?, ?, ?)",
        (employee_id, scenario.id, state.node_id, state.loyalty, state.safety, deadline, now_iso()),
    )
    return get_attempt(connection, int(cursor.lastrowid))


def get_attempt(connection: sqlite3.Connection, attempt_id: int) -> views.AttemptView:
    row = _row(connection, attempt_id)
    scenario = get_scenario(row["scenario_id"])
    state = _state_from_row(connection, row)
    last_step = state.steps[-1] if state.steps else None
    return _view(connection, row, scenario, state, last_step)


def choose(connection: sqlite3.Connection, attempt_id: int, option_id: str) -> views.AttemptView:
    """Применяет выбор проводника или таймаут, если серверный дедлайн уже прошёл."""
    row = _row(connection, attempt_id)
    if row["status"] == "finished":
        raise engine.ScenarioError("Попытка уже завершена")

    scenario = get_scenario(row["scenario_id"])
    state = _state_from_row(connection, row)

    if _deadline_passed(row):
        new_state = engine.apply_timeout(scenario, state)
    else:
        new_state = engine.apply_choice(scenario, state, option_id)

    return _commit_step(connection, row, scenario, new_state)


def expire(connection: sqlite3.Connection, attempt_id: int) -> views.AttemptView:
    """Применяет исход по таймауту: клиент сообщает, что время на экране вышло."""
    row = _row(connection, attempt_id)
    if row["status"] == "finished":
        raise engine.ScenarioError("Попытка уже завершена")

    scenario = get_scenario(row["scenario_id"])
    state = _state_from_row(connection, row)
    new_state = engine.apply_timeout(scenario, state)
    return _commit_step(connection, row, scenario, new_state)


def _commit_step(
    connection: sqlite3.Connection,
    row: sqlite3.Row,
    scenario: engine.Scenario,
    new_state: engine.State,
) -> views.AttemptView:
    step = new_state.steps[-1]
    connection.execute(
        "INSERT INTO attempt_steps (attempt_id, position, payload) VALUES (?, ?, ?)",
        (row["id"], len(new_state.steps) - 1, step.model_dump_json()),
    )

    node = engine.current_node(scenario, new_state)
    finished = node.kind == "outcome"
    connection.execute(
        "UPDATE attempts SET node_id = ?, loyalty = ?, safety = ?, deadline_at = ?, status = ? WHERE id = ?",
        (
            new_state.node_id,
            new_state.loyalty,
            new_state.safety,
            None if finished else _deadline_for(node),
            "finished" if finished else "in_progress",
            row["id"],
        ),
    )

    unlocked: list[views.UnlockedAchievement] = []
    if finished:
        summary = engine.summarize(scenario, new_state)
        results = scoring.apply_results(connection, row["employee_id"], summary)
        connection.execute(
            "UPDATE attempts SET finished_at = ?, passed = ?, xp_awarded = ? WHERE id = ?",
            (now_iso(), 1 if summary.passed else 0, results["xp_awarded"], row["id"]),
        )
        unlocked = [views.UnlockedAchievement(**item) for item in results["unlocked_achievements"]]  # type: ignore[arg-type]

    return _view(connection, _row(connection, row["id"]), scenario, new_state, step, unlocked)


def _view(
    connection: sqlite3.Connection,
    row: sqlite3.Row,
    scenario: engine.Scenario,
    state: engine.State,
    last_step: engine.Step | None,
    unlocked: list[views.UnlockedAchievement] | None = None,
) -> views.AttemptView:
    node = engine.current_node(scenario, state)
    finished = node.kind == "outcome"

    node_view = views.NodeView(
        id=state.node_id,
        kind=node.kind,
        narration=node.narration,
        passenger=node.passenger,
        options=[views.OptionView(id=option.id, text=option.text) for option in node.options],
        timer_seconds=node.timer_seconds,
        deadline_at=row["deadline_at"],
    )

    debrief = None
    if finished:
        summary = engine.summarize(scenario, state)
        debrief = views.DebriefView(
            passed=summary.passed,
            verdict=summary.verdict,
            loyalty=summary.loyalty,
            safety=summary.safety,
            timeouts=summary.timeouts,
            harmful_choices=summary.harmful_choices,
            competency_gain=[
                views.CompetencyGain(
                    competency=competency,
                    title=engine.COMPETENCY_TITLES.get(competency, competency),
                    points=points,
                )
                for competency, points in sorted(summary.competency_gain.items(), key=lambda item: -item[1])
            ],
            steps=summary.steps,
            xp_awarded=row["xp_awarded"] or 0,
            unlocked_achievements=unlocked or [],
        )

    return views.AttemptView(
        attempt_id=row["id"],
        employee_id=row["employee_id"],
        scenario=views.ScenarioBrief(
            id=scenario.id,
            title=scenario.title,
            summary=scenario.summary,
            service_class=scenario.service_class,
            car=scenario.car,
            primary_competency=scenario.primary_competency,
        ),
        loyalty=state.loyalty,
        safety=state.safety,
        finished=finished,
        node=node_view,
        last_step=last_step,
        server_time=now_iso(),
        debrief=debrief,
    )


def _row(connection: sqlite3.Connection, attempt_id: int) -> sqlite3.Row:
    row = connection.execute("SELECT * FROM attempts WHERE id = ?", (attempt_id,)).fetchone()
    if row is None:
        raise AttemptNotFound(attempt_id)
    return row


def _state_from_row(connection: sqlite3.Connection, row: sqlite3.Row) -> engine.State:
    steps = [
        engine.Step.model_validate_json(item["payload"])
        for item in connection.execute(
            "SELECT payload FROM attempt_steps WHERE attempt_id = ? ORDER BY position", (row["id"],)
        )
    ]
    return engine.State(
        scenario_id=row["scenario_id"],
        node_id=row["node_id"],
        loyalty=row["loyalty"],
        safety=row["safety"],
        steps=steps,
    )


def _deadline_for(node: engine.Node) -> str | None:
    if node.timer_seconds is None:
        return None
    deadline = datetime.now(timezone.utc) + timedelta(seconds=node.timer_seconds + TIMER_GRACE_SECONDS)
    return deadline.isoformat(timespec="seconds")


def _deadline_passed(row: sqlite3.Row) -> bool:
    if not row["deadline_at"]:
        return False
    return datetime.now(timezone.utc) > parse_iso(row["deadline_at"])


def attempt_history(connection: sqlite3.Connection, employee_id: int) -> list[dict[str, object]]:
    rows = connection.execute(
        "SELECT id, scenario_id, status, loyalty, safety, passed, xp_awarded, started_at, finished_at "
        "FROM attempts WHERE employee_id = ? ORDER BY started_at DESC",
        (employee_id,),
    ).fetchall()

    history: list[dict[str, object]] = []
    for row in rows:
        scenario = catalog().get(row["scenario_id"])
        history.append(
            {
                "attempt_id": row["id"],
                "scenario_id": row["scenario_id"],
                "scenario_title": scenario.title if scenario else row["scenario_id"],
                "status": row["status"],
                "loyalty": row["loyalty"],
                "safety": row["safety"],
                "passed": bool(row["passed"]) if row["passed"] is not None else None,
                "xp_awarded": row["xp_awarded"],
                "started_at": row["started_at"],
                "finished_at": row["finished_at"],
            }
        )
    return history


def steps_of_attempt(connection: sqlite3.Connection, attempt_id: int) -> list[engine.Step]:
    return [
        engine.Step.model_validate_json(item["payload"])
        for item in connection.execute(
            "SELECT payload FROM attempt_steps WHERE attempt_id = ? ORDER BY position", (attempt_id,)
        )
    ]


def raw_steps_json(connection: sqlite3.Connection, employee_id: int) -> list[dict[str, object]]:
    """Все шаги сотрудника — основа аналитики компетенций."""
    rows = connection.execute(
        "SELECT s.payload FROM attempt_steps s JOIN attempts a ON a.id = s.attempt_id WHERE a.employee_id = ?",
        (employee_id,),
    ).fetchall()
    return [json.loads(row["payload"]) for row in rows]
