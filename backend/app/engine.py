"""Движок сценариев: ветвление, две шкалы, таймауты, очки компетенций.

Модуль намеренно не знает ни про HTTP, ни про базу данных: на вход подаётся
сценарий и текущее состояние попытки, на выходе — новое состояние. Благодаря
этому логику можно проверять обычными тестами и объяснять по одному файлу.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

# Шкалы живут в диапазоне 0..100. Значения ниже используются и в разборе,
# и в аналитике, поэтому вынесены в константы, а не разбросаны по коду.
SCALE_MIN = 0
SCALE_MAX = 100

# Бонус за решение, принятое до истечения таймера. Отдельная компетенция
# «решение в дефиците времени» из требований ТЗ.
TIME_PRESSURE_COMPETENCY = "time_pressure"
TIME_PRESSURE_BONUS = 1

# Порог «успешного» прохождения для итогового вердикта.
VERDICT_LOYALTY_THRESHOLD = 60
VERDICT_SAFETY_THRESHOLD = 70

COMPETENCY_TITLES: dict[str, str] = {
    "conflict": "Работа с конфликтом",
    "medical": "Медицинский протокол",
    "regulations": "Регламент безопасности",
    "service": "Сервис и эмпатия",
    TIME_PRESSURE_COMPETENCY: "Решение в дефиците времени",
}

OptionQuality = Literal["optimal", "acceptable", "harmful"]

QUALITY_TITLES: dict[str, str] = {
    "optimal": "Оптимальное решение",
    "acceptable": "Допустимое решение",
    "harmful": "Ошибочное решение",
}


class Frozen(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")


class Effects(Frozen):
    """Как решение двигает шкалы и очки компетенций."""

    loyalty: int = 0
    safety: int = 0
    competencies: dict[str, int] = Field(default_factory=dict)


class Option(Frozen):
    """Вариант реплики или действия проводника."""

    id: str
    text: str
    quality: OptionQuality
    effects: Effects = Field(default_factory=Effects)
    debrief: str
    next: str


class Timeout(Frozen):
    """Что происходит, если проводник не успел принять решение."""

    text: str
    effects: Effects = Field(default_factory=Effects)
    debrief: str
    next: str


class Node(Frozen):
    """Узел сценария: либо ситуация с выбором, либо финал ветки."""

    kind: Literal["situation", "outcome"]
    narration: str
    passenger: str | None = None
    timer_seconds: int | None = None
    options: list[Option] = Field(default_factory=list)
    timeout: Timeout | None = None
    verdict: str | None = None
    # Исход, который нельзя считать успешным ни при каких шкалах: например,
    # пассажир доволен, но правила проезда нарушены.
    critical_failure: bool = False


class Scenario(Frozen):
    id: str
    title: str
    summary: str
    service_class: str
    car: str
    primary_competency: str
    initial_loyalty: int = 70
    initial_safety: int = 80
    start: str
    nodes: dict[str, Node]


class Step(Frozen):
    """Запись одного решения — основа обучающего разбора."""

    node_id: str
    narration: str
    passenger: str | None
    choice_text: str
    option_id: str | None
    timed_out: bool
    quality: OptionQuality
    loyalty_delta: int
    safety_delta: int
    loyalty_after: int
    safety_after: int
    competency_gain: dict[str, int]
    debrief: str


class State(Frozen):
    scenario_id: str
    node_id: str
    loyalty: int
    safety: int
    steps: list[Step] = Field(default_factory=list)


class Summary(Frozen):
    """Итог попытки: вердикт, очки компетенций, слабые места."""

    scenario_id: str
    loyalty: int
    safety: int
    passed: bool
    verdict: str
    competency_gain: dict[str, int]
    timeouts: int
    harmful_choices: int
    steps: list[Step]


class ScenarioError(Exception):
    """Сценарий или выбор не соответствуют структуре движка."""


def clamp(value: int) -> int:
    return max(SCALE_MIN, min(SCALE_MAX, value))


def validate(scenario: Scenario) -> None:
    """Проверяет связность сценария до того, как его начнёт проходить человек.

    Ошибка здесь лучше, чем обрыв ветки на демонстрации: при правке JSON
    неверная ссылка на узел видна сразу при загрузке.
    """
    if scenario.start not in scenario.nodes:
        raise ScenarioError(f"{scenario.id}: стартовый узел {scenario.start!r} не найден")

    for node_id, node in scenario.nodes.items():
        if node.kind == "outcome":
            if node.options or node.timeout:
                raise ScenarioError(f"{scenario.id}/{node_id}: финальный узел не может иметь выборов")
            continue

        if node.critical_failure:
            raise ScenarioError(f"{scenario.id}/{node_id}: критический исход можно отметить только на финальном узле")

        if not node.options:
            raise ScenarioError(f"{scenario.id}/{node_id}: у ситуации нет вариантов решения")

        if node.timer_seconds is not None and node.timeout is None:
            raise ScenarioError(f"{scenario.id}/{node_id}: есть таймер, но не описан исход по таймауту")

        seen: set[str] = set()
        for option in node.options:
            if option.id in seen:
                raise ScenarioError(f"{scenario.id}/{node_id}: повтор идентификатора варианта {option.id!r}")
            seen.add(option.id)
            if option.next not in scenario.nodes:
                raise ScenarioError(f"{scenario.id}/{node_id}/{option.id}: ссылка на несуществующий узел {option.next!r}")

        if node.timeout and node.timeout.next not in scenario.nodes:
            raise ScenarioError(f"{scenario.id}/{node_id}: таймаут ведёт в несуществующий узел {node.timeout.next!r}")

    unreachable = set(scenario.nodes) - _reachable_nodes(scenario)
    if unreachable:
        raise ScenarioError(f"{scenario.id}: недостижимые узлы: {', '.join(sorted(unreachable))}")


def _reachable_nodes(scenario: Scenario) -> set[str]:
    """Узлы, до которых можно дойти от старта: защита от забытых веток."""
    reachable: set[str] = set()
    queue = [scenario.start]

    while queue:
        node_id = queue.pop()
        if node_id in reachable:
            continue
        reachable.add(node_id)

        node = scenario.nodes[node_id]
        queue.extend(option.next for option in node.options)
        if node.timeout:
            queue.append(node.timeout.next)

    return reachable


def start_attempt(scenario: Scenario) -> State:
    return State(
        scenario_id=scenario.id,
        node_id=scenario.start,
        loyalty=clamp(scenario.initial_loyalty),
        safety=clamp(scenario.initial_safety),
        steps=[],
    )


def current_node(scenario: Scenario, state: State) -> Node:
    node = scenario.nodes.get(state.node_id)
    if node is None:
        raise ScenarioError(f"{scenario.id}: узел {state.node_id!r} не найден")
    return node


def is_finished(scenario: Scenario, state: State) -> bool:
    return current_node(scenario, state).kind == "outcome"


def apply_choice(scenario: Scenario, state: State, option_id: str) -> State:
    """Применяет выбранный вариант и переводит попытку в следующий узел."""
    node = current_node(scenario, state)
    if node.kind == "outcome":
        raise ScenarioError(f"{scenario.id}/{state.node_id}: сценарий уже завершён")

    option = next((item for item in node.options if item.id == option_id), None)
    if option is None:
        raise ScenarioError(f"{scenario.id}/{state.node_id}: вариант {option_id!r} не найден")

    gain = dict(option.effects.competencies)
    # Решение уложилось в таймер — значит навык работы под давлением сработал.
    if node.timer_seconds is not None:
        gain[TIME_PRESSURE_COMPETENCY] = gain.get(TIME_PRESSURE_COMPETENCY, 0) + TIME_PRESSURE_BONUS

    return _advance(
        state=state,
        node=node,
        next_node_id=option.next,
        choice_text=option.text,
        option_id=option.id,
        timed_out=False,
        quality=option.quality,
        effects=option.effects,
        competency_gain=gain,
        debrief=option.debrief,
    )


def apply_timeout(scenario: Scenario, state: State) -> State:
    """Применяет исход по истечению таймера: молчание — это тоже решение."""
    node = current_node(scenario, state)
    if node.kind == "outcome":
        raise ScenarioError(f"{scenario.id}/{state.node_id}: сценарий уже завершён")
    if node.timeout is None:
        raise ScenarioError(f"{scenario.id}/{state.node_id}: у узла нет таймера")

    return _advance(
        state=state,
        node=node,
        next_node_id=node.timeout.next,
        choice_text=node.timeout.text,
        option_id=None,
        timed_out=True,
        quality="harmful",
        effects=node.timeout.effects,
        competency_gain=dict(node.timeout.effects.competencies),
        debrief=node.timeout.debrief,
    )


def _advance(
    *,
    state: State,
    node: Node,
    next_node_id: str,
    choice_text: str,
    option_id: str | None,
    timed_out: bool,
    quality: OptionQuality,
    effects: Effects,
    competency_gain: dict[str, int],
    debrief: str,
) -> State:
    loyalty_after = clamp(state.loyalty + effects.loyalty)
    safety_after = clamp(state.safety + effects.safety)

    step = Step(
        node_id=state.node_id,
        narration=node.narration,
        passenger=node.passenger,
        choice_text=choice_text,
        option_id=option_id,
        timed_out=timed_out,
        quality=quality,
        # Шкалы обрезаются по границам, поэтому в разборе показываем фактическое
        # изменение, а не заявленное в сценарии.
        loyalty_delta=loyalty_after - state.loyalty,
        safety_delta=safety_after - state.safety,
        loyalty_after=loyalty_after,
        safety_after=safety_after,
        competency_gain=competency_gain,
        debrief=debrief,
    )

    return State(
        scenario_id=state.scenario_id,
        node_id=next_node_id,
        loyalty=loyalty_after,
        safety=safety_after,
        steps=[*state.steps, step],
    )


def summarize(scenario: Scenario, state: State) -> Summary:
    """Собирает разбор попытки: вердикт, очки компетенций, слабые места."""
    gain: dict[str, int] = {}
    for step in state.steps:
        for competency, points in step.competency_gain.items():
            gain[competency] = gain.get(competency, 0) + points

    node = current_node(scenario, state)
    scales_ok = state.loyalty >= VERDICT_LOYALTY_THRESHOLD and state.safety >= VERDICT_SAFETY_THRESHOLD
    passed = scales_ok and not node.critical_failure

    return Summary(
        scenario_id=scenario.id,
        loyalty=state.loyalty,
        safety=state.safety,
        passed=passed,
        verdict=node.verdict or node.narration,
        competency_gain=gain,
        timeouts=sum(1 for step in state.steps if step.timed_out),
        harmful_choices=sum(1 for step in state.steps if step.quality == "harmful"),
        steps=list(state.steps),
    )
