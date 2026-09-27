"""Тесты движка: ветвление, влияние таймера на исход, работа обеих шкал."""

from __future__ import annotations

import pytest

from app import engine, scenarios, views


@pytest.fixture(scope="module")
def all_scenarios() -> dict[str, engine.Scenario]:
    return scenarios.load_all()


@pytest.fixture()
def conflict(all_scenarios: dict[str, engine.Scenario]) -> engine.Scenario:
    return all_scenarios["two_passengers_one_seat"]


def test_correct_reply_is_not_given_away(all_scenarios: dict[str, engine.Scenario]) -> None:
    """Первый пункт и самая длинная реплика не должны быть правильным ответом.

    Иначе прохождение превращается в поиск длинной кнопки сверху, а не в решение.
    """

    first = 0
    longest = 0
    total = 0
    for scenario in all_scenarios.values():
        for node_id, node in scenario.nodes.items():
            if node.kind != "situation":
                continue
            total += 1
            shown = views.shown_options(scenario.id, node_id, node.options)
            if shown[0].quality == "optimal":
                first += 1
            optimal = max(len(option.text) for option in node.options if option.quality == "optimal")
            others = [len(option.text) for option in node.options if option.quality != "optimal"]
            if optimal > max(others):
                longest += 1
            lengths = [len(option.text) for option in node.options]
            assert max(lengths) - min(lengths) <= 55, (
                f"{scenario.id}/{node_id}: реплики слишком разной длины, короткая читается как ошибка"
            )

    assert total >= 51
    assert first < total * 0.45
    assert longest < total * 0.45


def test_catalog_covers_every_methodology_situation(all_scenarios: dict[str, engine.Scenario]) -> None:
    numbers = [scenario.number for scenario in all_scenarios.values()]
    # 1..51 — ситуации методички. Кабинет методиста может добавить следующие.
    assert set(range(1, 52)) <= set(numbers)
    assert len(numbers) == len(set(numbers))
    assert all(scenario.section for scenario in all_scenarios.values())


def test_all_scenarios_are_valid(all_scenarios: dict[str, engine.Scenario]) -> None:
    assert all_scenarios, "каталог сценариев не должен быть пустым"
    for scenario in all_scenarios.values():
        engine.validate(scenario)


def test_every_scenario_is_branching_and_explains_itself(all_scenarios: dict[str, engine.Scenario]) -> None:
    for scenario in all_scenarios.values():
        situations = [node for node in scenario.nodes.values() if node.kind == "situation"]
        outcomes = [node for node in scenario.nodes.values() if node.kind == "outcome"]

        assert len(situations) >= 3, f"{scenario.id}: сценарий должен быть многошаговым"
        assert len(outcomes) >= 3, f"{scenario.id}: у сценария должно быть несколько исходов"

        for node in situations:
            assert node.timer_seconds, f"{scenario.id}: у ситуации нет таймера"
            assert len(node.options) >= 3, f"{scenario.id}: слишком мало вариантов решения"
            assert {option.quality for option in node.options} >= {"optimal", "harmful"}, (
                f"{scenario.id}: в ситуации нет и оптимального, и ошибочного варианта"
            )
            for option in node.options:
                assert len(option.debrief) > 40, f"{scenario.id}/{option.id}: разбор слишком короткий"

        # Обе шкалы должны реально работать в каждом сценарии, а не только одна.
        deltas = [option.effects for node in situations for option in node.options]
        assert any(item.loyalty for item in deltas), f"{scenario.id}: лояльность ни на что не влияет"
        assert any(item.safety for item in deltas), f"{scenario.id}: безопасность ни на что не влияет"


def test_unreachable_node_is_detected() -> None:
    scenario = engine.Scenario(
        id="orphan",
        title="Сценарий с забытой ветвью",
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
                        text="Дальше.",
                        quality="acceptable",
                        debrief="Служебный разбор.",
                        next="done",
                    )
                ],
            ),
            "done": engine.Node(kind="outcome", narration="Финал.", verdict="Финал."),
            "forgotten": engine.Node(kind="outcome", narration="Забытая ветка.", verdict="Забытая ветка."),
        },
    )

    with pytest.raises(engine.ScenarioError, match="недостижимые узлы"):
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


def test_critical_outcome_cannot_be_passed(conflict: engine.Scenario) -> None:
    state = engine.apply_choice(conflict, engine.start_attempt(conflict), "check_tickets")
    state = engine.apply_choice(conflict, state, "free_upgrade")
    summary = engine.summarize(conflict, state)

    # Пассажир доволен, но правила проезда нарушены: успехом это не считается.
    assert summary.loyalty >= engine.VERDICT_LOYALTY_THRESHOLD
    assert summary.passed is False


def test_critical_flag_is_allowed_only_on_outcome_nodes() -> None:
    scenario = engine.Scenario(
        id="misplaced_flag",
        title="Критический флаг не на финале",
        summary="Служебный сценарий для теста валидации.",
        service_class="стандарт",
        car="Вагон 1",
        primary_competency="service",
        start="only",
        nodes={
            "only": engine.Node(
                kind="situation",
                narration="Ситуация.",
                critical_failure=True,
                options=[
                    engine.Option(
                        id="go",
                        text="Дальше.",
                        quality="acceptable",
                        debrief="Служебный разбор.",
                        next="done",
                    )
                ],
            ),
            "done": engine.Node(kind="outcome", narration="Финал.", verdict="Финал."),
        },
    )

    with pytest.raises(engine.ScenarioError):
        engine.validate(scenario)


def test_same_choice_leads_elsewhere_after_a_harmful_decision(conflict: engine.Scenario) -> None:
    """Условный переход: финал зависит не только от последнего решения."""
    clean = engine.apply_choice(conflict, engine.start_attempt(conflict), "check_tickets")
    clean = engine.apply_choice(conflict, clean, "explain_and_chief")
    clean = engine.apply_choice(conflict, clean, "accept_and_ask_no_filming")

    spoiled = engine.apply_choice(conflict, engine.start_attempt(conflict), "take_side")
    spoiled = engine.apply_choice(conflict, spoiled, "separate_and_check")
    spoiled = engine.apply_choice(conflict, spoiled, "explain_and_chief")
    spoiled = engine.apply_choice(conflict, spoiled, "accept_and_ask_no_filming")

    assert clean.steps[-1].option_id == spoiled.steps[-1].option_id
    assert clean.node_id != spoiled.node_id
    assert clean.steps[-1].branch_note is None
    assert spoiled.steps[-1].branch_note
    assert engine.summarize(conflict, clean).passed
    assert engine.summarize(conflict, spoiled).passed is False


def test_timeout_earlier_changes_the_medical_ending(all_scenarios: dict[str, engine.Scenario]) -> None:
    medical = all_scenarios["medical_incident"]

    state = engine.apply_timeout(medical, engine.start_attempt(medical))
    state = engine.apply_choice(medical, state, "refuse_and_chief")
    state = engine.apply_choice(medical, state, "respect_but_notify")

    # Протокол выдержан, но пассажирка уже не доверяет: исход другой.
    assert state.node_id == "o_silence_remembered"
    assert state.steps[-1].branch_note
    # Условие меняет финал и разбор, но не обнуляет результат: протокол соблюдён.
    assert engine.summarize(medical, state).passed


def test_low_loyalty_changes_the_handover_ending(all_scenarios: dict[str, engine.Scenario]) -> None:
    intoxicated = all_scenarios["intoxicated_passenger"]

    state = engine.apply_choice(intoxicated, engine.start_attempt(intoxicated), "radio_says_drunk")
    state = engine.apply_choice(intoxicated, state, "move_neighbours")
    state = engine.apply_choice(intoxicated, state, "stop_with_safety_reason")
    state = engine.apply_choice(intoxicated, state, "factual_report")

    assert state.loyalty < 65
    assert state.node_id == "o_words_remembered"
    assert state.steps[-1].branch_note
    # Обращение пассажира на действия проводника не может быть зачтено.
    assert engine.summarize(intoxicated, state).passed is False


def test_branch_without_condition_is_rejected() -> None:
    scenario = engine.Scenario(
        id="empty_condition",
        title="Условный переход без условия",
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
                        text="Дальше.",
                        quality="acceptable",
                        debrief="Служебный разбор.",
                        next="done",
                        branches=[engine.Branch(when=engine.Condition(), next="other", note="Всегда.")],
                    )
                ],
            ),
            "done": engine.Node(kind="outcome", narration="Финал.", verdict="Финал."),
            "other": engine.Node(kind="outcome", narration="Другой финал.", verdict="Другой финал."),
        },
    )

    with pytest.raises(engine.ScenarioError, match="без условия"):
        engine.validate(scenario)


def test_impossible_condition_is_rejected() -> None:
    scenario = engine.Scenario(
        id="impossible_condition",
        title="Условие, которое не выполнится",
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
                        text="Дальше.",
                        quality="acceptable",
                        debrief="Служебный разбор.",
                        next="done",
                        branches=[
                            engine.Branch(
                                when=engine.Condition(safety_below=50, safety_at_least=60),
                                next="other",
                                note="Никогда.",
                            )
                        ],
                    )
                ],
            ),
            "done": engine.Node(kind="outcome", narration="Финал.", verdict="Финал."),
            "other": engine.Node(kind="outcome", narration="Другой финал.", verdict="Другой финал."),
        },
    )

    with pytest.raises(engine.ScenarioError, match="никогда не выполнится"):
        engine.validate(scenario)


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
