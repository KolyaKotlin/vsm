"""Тесты API: прохождение сценария, таймеры на сервере, профиль и интеграции."""

from __future__ import annotations

import sqlite3

import pytest
from fastapi.testclient import TestClient

from app import engine, scenarios

SCENARIO = "two_passengers_one_seat"


def start(client: TestClient, employee_id: int, scenario_id: str = SCENARIO) -> dict:
    response = client.post("/api/attempts", json={"employee_id": employee_id, "scenario_id": scenario_id})
    assert response.status_code == 200, response.text
    return response.json()


def choose(client: TestClient, attempt_id: int, option_id: str) -> dict:
    response = client.post(f"/api/attempts/{attempt_id}/choice", json={"option_id": option_id})
    assert response.status_code == 200, response.text
    return response.json()


def test_health_reports_loaded_scenarios(client: TestClient) -> None:
    body = client.get("/api/health").json()
    assert body["status"] == "ok"
    assert body["scenarios"] >= 1


def test_scenario_list_is_not_empty(client: TestClient) -> None:
    scenarios = client.get("/api/scenarios").json()
    assert any(item["id"] == SCENARIO for item in scenarios)


def test_options_do_not_leak_correct_answer(client: TestClient, trainee_id: int) -> None:
    attempt = start(client, trainee_id)
    option = attempt["node"]["options"][0]

    # Проходящему сценарий отдаются только текст и идентификатор варианта.
    assert set(option) == {"id", "text"}
    assert attempt["node"]["deadline_at"] is not None


def test_full_optimal_run_awards_xp_and_achievement(client: TestClient, trainee_id: int) -> None:
    attempt = start(client, trainee_id)
    attempt_id = attempt["attempt_id"]

    choose(client, attempt_id, "check_tickets")
    choose(client, attempt_id, "explain_and_chief")
    final = choose(client, attempt_id, "accept_and_ask_no_filming")

    assert final["finished"] is True
    debrief = final["debrief"]
    assert debrief["passed"] is True
    assert debrief["xp_awarded"] > 0
    assert len(debrief["steps"]) == 3
    assert all(step["debrief"] for step in debrief["steps"])
    assert {item["code"] for item in debrief["unlocked_achievements"]} >= {"first_shift"}

    profile = client.get(f"/api/employees/{trainee_id}/profile").json()
    assert profile["xp"] == debrief["xp_awarded"]
    assert profile["attempts_finished"] == 1


def test_timeout_endpoint_sends_attempt_to_another_branch(client: TestClient, trainee_id: int) -> None:
    timed_out = client.post(f"/api/attempts/{start(client, trainee_id)['attempt_id']}/timeout").json()
    in_time = choose(client, start(client, trainee_id)["attempt_id"], "check_tickets")

    assert timed_out["node"]["id"] != in_time["node"]["id"]
    assert timed_out["last_step"]["timed_out"] is True
    assert timed_out["safety"] < in_time["safety"]


def test_late_choice_is_treated_as_timeout(client: TestClient, trainee_id: int, raw_db: sqlite3.Connection) -> None:
    attempt_id = start(client, trainee_id)["attempt_id"]

    # Сдвигаем серверный дедлайн в прошлое: браузер «опоздал» с ответом.
    raw_db.execute("UPDATE attempts SET deadline_at = '2020-01-01T00:00:00+00:00' WHERE id = ?", (attempt_id,))
    raw_db.commit()

    late = choose(client, attempt_id, "check_tickets")
    assert late["last_step"]["timed_out"] is True
    assert late["last_step"]["option_id"] is None


def test_two_scales_diverge_on_regulation_breach(client: TestClient, trainee_id: int) -> None:
    attempt_id = start(client, trainee_id)["attempt_id"]
    choose(client, attempt_id, "check_tickets")
    breach = choose(client, attempt_id, "free_upgrade")

    step = breach["last_step"]
    assert step["loyalty_delta"] > 0
    assert step["safety_delta"] < 0
    assert breach["finished"] is True
    assert breach["debrief"]["passed"] is False


def test_leaderboard_scopes(client: TestClient, trainee_id: int) -> None:
    brigade = client.get("/api/leaderboard", params={"scope": "brigade", "employee_id": trainee_id}).json()
    company = client.get("/api/leaderboard", params={"scope": "company"}).json()

    assert len(company) > len(brigade)
    assert {row["brigade"] for row in brigade} == {"Бригада 1"}
    assert [row["place"] for row in company] == sorted(row["place"] for row in company)
    assert company[0]["xp"] >= company[-1]["xp"]


def test_leaderboard_requires_employee_for_brigade_scope(client: TestClient) -> None:
    assert client.get("/api/leaderboard", params={"scope": "brigade"}).status_code == 422


def test_notifications_can_be_marked_read(client: TestClient, trainee_id: int) -> None:
    notifications = client.get(f"/api/employees/{trainee_id}/notifications").json()
    assert notifications, "демо-профиль должен получить приветственные уведомления"

    unread_before = client.get(f"/api/employees/{trainee_id}/profile").json()["unread_notifications"]
    client.post(f"/api/notifications/{notifications[0]['id']}/read")
    unread_after = client.get(f"/api/employees/{trainee_id}/profile").json()["unread_notifications"]

    assert unread_after == unread_before - 1


def test_analytics_reports_gaps_and_advice(client: TestClient, trainee_id: int) -> None:
    empty = client.get(f"/api/employees/{trainee_id}/analytics").json()
    assert empty["attempts_finished"] == 0
    assert empty["recommendations"]

    attempt_id = start(client, trainee_id)["attempt_id"]
    client.post(f"/api/attempts/{attempt_id}/timeout")
    choose(client, attempt_id, "argue")

    filled = client.get(f"/api/employees/{trainee_id}/analytics").json()
    assert filled["attempts_finished"] == 1
    assert filled["timeouts"] == 1
    assert filled["harmful_choices"] == 2
    assert "Медицинский протокол" in filled["gaps"]
    assert filled["recommendations"]


def test_unknown_attempt_and_scenario_return_404(client: TestClient, trainee_id: int) -> None:
    assert client.get("/api/attempts/99999").status_code == 404
    assert client.post("/api/attempts", json={"employee_id": trainee_id, "scenario_id": "nope"}).status_code == 404
    assert client.post("/api/attempts", json={"employee_id": 99999, "scenario_id": SCENARIO}).status_code == 404


def test_invalid_option_returns_400(client: TestClient, trainee_id: int) -> None:
    attempt_id = start(client, trainee_id)["attempt_id"]
    response = client.post(f"/api/attempts/{attempt_id}/choice", json={"option_id": "ghost"})
    assert response.status_code == 400
    assert "не найден" in response.json()["detail"]


def test_hr_integration_creates_employee_and_lms_exports_results(client: TestClient) -> None:
    created = client.post(
        "/api/integrations/hr/employees",
        json={
            "hr_ref": "HR-0001",
            "login": "demo.imported",
            "display_name": "П. Демидов (демо)",
            "brigade": "Бригада 7",
            "depot": "Депо Москва-Восточное",
        },
    )
    assert created.status_code == 200
    employee_id = created.json()["employee_id"]

    attempt_id = start(client, employee_id)["attempt_id"]
    choose(client, attempt_id, "check_tickets")
    choose(client, attempt_id, "explain_and_chief")
    choose(client, attempt_id, "accept_and_ask_no_filming")

    export = client.get(f"/api/integrations/lms/results/{employee_id}").json()
    assert export["employee"]["login"] == "demo.imported"
    assert export["attempts"][0]["passed"] is True
    assert export["level"] >= 1


def test_billing_charge_goes_from_pending_to_paid_and_refunded(client: TestClient, trainee_id: int) -> None:
    created = client.post(
        "/api/integrations/billing/charges",
        json={
            "employee_id": trainee_id,
            "kind": "class_upgrade",
            "title": "Повышение класса до бизнес-класса, вагон 5 → вагон 7",
            "amount_kopecks": 245000,
        },
    )
    assert created.status_code == 200, created.text
    charge = created.json()
    assert charge["status"] == "pending"
    assert charge["channel"] == "mobile_cash"

    paid = client.post(f"/api/integrations/billing/charges/{charge['id']}/pay").json()
    assert paid["status"] == "paid"

    # Повторная оплата — недопустимый переход, а не ошибка сервера.
    again = client.post(f"/api/integrations/billing/charges/{charge['id']}/pay")
    assert again.status_code == 400
    assert "оплачена" in again.json()["detail"]

    refunded = client.post(f"/api/integrations/billing/charges/{charge['id']}/refund").json()
    assert refunded["status"] == "refunded"

    listed = client.get("/api/integrations/billing/charges", params={"employee_id": trainee_id}).json()
    assert [item["id"] for item in listed] == [charge["id"]]


def test_billing_refuses_unpaid_refund_and_non_positive_amount(client: TestClient, trainee_id: int) -> None:
    created = client.post(
        "/api/integrations/billing/charges",
        json={
            "employee_id": trainee_id,
            "kind": "service",
            "title": "Плед из каталога товаров на борту",
            "amount_kopecks": 90000,
        },
    ).json()

    early_refund = client.post(f"/api/integrations/billing/charges/{created['id']}/refund")
    assert early_refund.status_code == 400

    zero = client.post(
        "/api/integrations/billing/charges",
        json={"employee_id": trainee_id, "kind": "service", "title": "Бесплатно", "amount_kopecks": 0},
    )
    assert zero.status_code == 422

    missing = client.post("/api/integrations/billing/charges/9999/pay")
    assert missing.status_code == 404


def test_scenario_reload_keeps_catalog_available(client: TestClient) -> None:
    reloaded = client.post("/api/scenarios/reload").json()
    assert any(item["id"] == SCENARIO for item in reloaded)


def test_broken_scenario_does_not_break_running_service(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    working = client.get("/api/scenarios").json()

    def fail(*_: object, **__: object) -> None:
        raise engine.ScenarioError("s1_meet: ссылка на несуществующий узел")

    monkeypatch.setattr(scenarios, "load_all", fail)
    broken = client.post("/api/scenarios/reload")

    assert broken.status_code == 400
    assert "несуществующий узел" in broken.json()["detail"]
    # Опечатка в сценарии не должна обрушить идущую демонстрацию.
    assert client.get("/api/scenarios").json() == working
