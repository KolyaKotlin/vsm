"""Тесты движка: ветвление, влияние таймера на исход, работа обеих шкал."""

from __future__ import annotations

import pytest

from app import engine, scenarios


@pytest.fixture(scope="module")
def all_scenarios() -> dict[str, engine.Scenario]:
    return scenarios.load_all()


@pytest.fixture()
def conflict(all_scenarios: dict[str, engine.Scenario]) -> engine.Scenario:
    return all_scenarios["two_passengers_one_seat"]


def test_all_scenarios_are_valid(all_scenarios: dict[str, engine.Scenario]) -> None:
    assert all_scenarios, "каталог сценариев не должен быть пустым"
    for scenario in all_scenarios.values():
        engine.validate(scenario)


def test_optimal_path_raises_both_scales(conflict: engine.Scenario) -> None:
    state = engine.start_attempt(conflict)
    state = engine.apply_choice(conflict, state, "check_tickets")
    state = engine.apply_choice(conflict, state, "explain_and_chief")
    state = engine.apply_choice(conflict, state, "accept_and_ask_no_filming")

    assert engine.is_finished(conflict, state)
    summary = engine.summarize(conflict, state)
    assert summary.passed
    assert summary.loyalty > conflict.initial_loyalty
    assert summary.safety > conflict.initial_safety
    assert summary.timeouts == 0


def test_timeout_leads_to_another_branch(conflict: engine.Scenario) -> None:
    chosen = engine.apply_choice(conflict, engine.start_attempt(conflict), "check_tickets")
    expired = engine.apply_timeout(conflict, engine.start_attempt(conflict))

    assert chosen.node_id != expired.node_id
    assert expired.loyalty < chosen.loyalty
    assert expired.safety < chosen.safety
    assert expired.steps[-1].timed_out is True


def test_scales_move_in_opposite_directions(conflict: engine.Scenario) -> None:
    state = engine.apply_choice(conflict, engine.start_attempt(conflict), "check_tickets")
    state = engine.apply_choice(conflict, state, "free_upgrade")
    step = state.steps[-1]

    # Бесплатное повышение класса радует пассажира и нарушает регламент:
    # ровно тот случай, когда шкалы расходятся.
    assert step.loyalty_delta > 0
    assert step.safety_delta < 0


def test_time_pressure_points_only_without_timeout(conflict: engine.Scenario) -> None:
    in_time = engine.apply_choice(conflict, engine.start_attempt(conflict), "check_tickets")
    expired = engine.apply_timeout(conflict, engine.start_attempt(conflict))

    assert in_time.steps[-1].competency_gain.get(engine.TIME_PRESSURE_COMPETENCY) == engine.TIME_PRESSURE_BONUS
    assert engine.TIME_PRESSURE_COMPETENCY not in expired.steps[-1].competency_gain


def test_summary_collects_competencies_and_mistakes(conflict: engine.Scenario) -> None:
    state = engine.apply_timeout(conflict, engine.start_attempt(conflict))
    state = engine.apply_choice(conflict, state, "argue")
    summary = engine.summarize(conflict, state)

    assert summary.passed is False
    assert summary.timeouts == 1
    assert summary.harmful_choices == 2
    assert summary.steps[-1].debrief


def test_unknown_option_is_rejected(conflict: engine.Scenario) -> None:
    state = engine.start_attempt(conflict)
    with pytest.raises(engine.ScenarioError):
        engine.apply_choice(conflict, state, "no_such_option")


def test_finished_scenario_accepts_no_choices(conflict: engine.Scenario) -> None:
    state = engine.apply_choice(conflict, engine.start_attempt(conflict), "check_tickets")
    state = engine.apply_choice(conflict, state, "free_upgrade")

    assert engine.is_finished(conflict, state)
    with pytest.raises(engine.ScenarioError):
        engine.apply_choice(conflict, state, "accept_and_ask_no_filming")


def test_scales_are_clamped() -> None:
    scenario = engine.Scenario(
        id="clamp_probe",
        title="Проверка границ шкал",
        summary="Служебный сценарий для теста границ.",
        service_class="стандарт",
        car="Вагон 1",
        primary_competency="service",
        initial_loyalty=95,
        initial_safety=5,
        start="only",
        nodes={
            "only": engine.Node(
                kind="situation",
                narration="Проверка границ.",
                options=[
                    engine.Option(
                        id="push",
                        text="Сдвинуть шкалы за границы диапазона.",
                        quality="acceptable",
                        effects=engine.Effects(loyalty=20, safety=-20),
                        debrief="Служебный разбор.",
                        next="done",
                    )
                ],
            ),
            "done": engine.Node(kind="outcome", narration="Финал.", verdict="Финал."),
        },
    )

    state = engine.apply_choice(scenario, engine.start_attempt(scenario), "push")
    assert state.loyalty == engine.SCALE_MAX
    assert state.safety == engine.SCALE_MIN
    # В разборе показываем фактическое изменение, а не заявленное в сценарии.
    assert state.steps[-1].loyalty_delta == 5
    assert state.steps[-1].safety_delta == -5


def test_broken_link_is_detected() -> None:
    scenario = engine.Scenario(
        id="broken",
        title="Сценарий с битой ссылкой",
        summary="Служебный сценарий для теста валидации.",
        service_class="стандарт",
        car="Вагон 1",
        primary_competency="service",
        start="only",
        nodes={
            "only": engine.Node(
                kind="situation",
                narration="Ситуация.",
                options=[
                    engine.Option(
                        id="go",
                        text="Уйти в несуществующий узел.",
                        quality="acceptable",
                        debrief="Служебный разбор.",
                        next="missing",
                    )
                ],
            )
        },
    )

    with pytest.raises(engine.ScenarioError):
        engine.validate(scenario)
