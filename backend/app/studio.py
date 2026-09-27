"""Кабинет методиста: новые ситуации и коды проводников.

Сценарий собирается в том же формате, что и остальные файлы каталога, и сразу
проверяется движком. Код доступа выдаётся здесь и больше нигде не светится
в списке для сайта.
"""

from __future__ import annotations

import json
import os
import random
import re
import sqlite3

from . import scenarios, service
from .engine import Scenario, ScenarioError, validate

ADMIN_CODE = os.environ.get("VSM_ADMIN_CODE", "mentor")


class AdminError(Exception):
    pass


def check_code(code: str) -> None:
    if code.strip() != ADMIN_CODE:
        raise AdminError("Нужен код методиста")


def _fit_lengths(options: list[dict]) -> None:
    fillers = {
        "optimal": [" Благодарю.", " Я на связи."],
        "acceptable": [" На этом остановлюсь.", " Второй раз не повторю."],
        "harmful": [" Так и сделаю.", " И отойду от спора."],
    }
    if not options:
        return
    for _ in range(8):
        longest = max(len(item["text"]) for item in options)
        short = min(options, key=lambda item: len(item["text"]))
        if longest - len(short["text"]) <= 50:
            return
        extra = next((item for item in fillers[short["quality"]] if item.strip() not in short["text"]), None)
        if extra is None:
            return
        text = short["text"].rstrip()
        short["text"] = text[:-1].rstrip() + extra + "»" if text.endswith("»") else text + extra


def _slug(title: str) -> str:
    letters = re.sub(r"[^a-z0-9]+", "_", title.lower()).strip("_")
    return letters[:24] or "situation"


def _choice(option_id: str, text: str, quality: str, loyalty: int, safety: int, competency: str, points: int, debrief: str, nxt: str) -> dict:
    return {
        "id": option_id,
        "text": text,
        "quality": quality,
        "effects": {"loyalty": loyalty, "safety": safety, "competencies": {competency: points} if points else {}},
        "debrief": debrief,
        "next": nxt,
    }


def build_scenario_document(payload: dict, number: int) -> dict:
    """Три шага по ролевой модели плюс отказ пассажира не нужен методисту вручную.

    Из формулировок собирается проходимый сценарий: признать, назвать правило,
    закрыть разговор. Ошибочный обход правила не даёт сдать попытку.
    """

    title = payload["title"].strip()
    summary = payload["summary"].strip()
    competency = payload["primary_competency"]
    rule = payload["rule"].strip()
    refusal = payload["refusal"].strip()
    scene = payload["scene"].strip()
    passenger = payload["passenger"].strip()
    scenario_id = f"custom_{number}_{_slug(title)}"
    critical = bool(payload.get("critical"))

    def step(narration: str, line: str, timer: int, options: list[dict], timeout_next: str) -> dict:
        return {
            "kind": "situation",
            "narration": narration,
            "passenger": line,
            "timer_seconds": timer,
            "options": options,
            "timeout": {
                "text": "Проводник молчит, и пассажир повторяет требование громче.",
                "effects": {"loyalty": -8, "safety": -8, "competencies": {}},
                "debrief": "Молчание здесь читается как отказ помогать. Нужно ответить сразу.",
                "next": timeout_next,
            },
        }

    document = {
        "id": scenario_id,
        "number": number,
        "section": payload.get("section", "Добавленные").strip() or "Добавленные",
        "title": title,
        "summary": summary,
        "service_class": payload.get("service_class", "стандарт").strip() or "стандарт",
        "car": payload.get("car", "Вагон 1").strip() or "Вагон 1",
        "primary_competency": competency,
        "initial_loyalty": 70,
        "initial_safety": 80,
        "start": "s1",
        "nodes": {
            "s1": step(
                scene,
                passenger,
                25,
                [
                    _choice("opt", f"«Я вас понимаю. Давайте разберёмся спокойно: {rule}»", "optimal", 5, 5, competency, 3, f"Сначала признали ситуацию и назвали правило без спора. {summary}", "s2"),
                    _choice("mid", "«Сейчас не до разговоров. Правило есть, выполняйте его и не задерживайте салон.»", "acceptable", -2, 3, competency, 1, "Правило названо, но человек не услышал, что его услышали. Спор из-за этого становится громче.", "s2"),
                    _choice("bad", refusal, "harmful", -8, -16, competency, 0, f"Так правило обходится. {summary}", "o_bad"),
                ],
                "s2",
            ),
            "s2": step(
                "Пассажир не соглашается и просит сделать исключение при других людях.",
                "«Ну сделайте исключение. Никто ведь не увидит.»",
                22,
                [
                    _choice("opt", "«Исключения не будет. Я подскажу законный следующий шаг и останусь рядом, пока вопрос не закроется.»", "optimal", 5, 5, competency, 3, "Отказ от исключения спокойный, и у человека остаётся понятный следующий шаг.", "s3"),
                    _choice("mid", "«Исключений нет. Куда идти дальше, спросите на станции, я повторять не буду.»", "acceptable", -2, 3, competency, 1, "Рамка удержана, но человека оставили без маршрута, и он продолжает стоять в проходе.", "s3"),
                    _choice("bad", "«Ладно, один раз можно. Только никому не говорите, что я разрешил.»", "harmful", -8, -16, competency, 0, "Исключение шёпотом — то же нарушение, только ещё и скрытое от бригады.", "o_bad"),
                ],
                "s3",
            ),
            "s3": step(
                "Нужно закрыть разговор: подтвердить, что будет дальше, и вернуть салон к обычной работе.",
                "«И вы просто уйдёте? Мне-то что теперь делать?»",
                20,
                [
                    _choice(
                        "opt",
                        "«Благодарю за понимание. Дальше действуем по правилу, я на связи, если станет хуже.»",
                        "optimal",
                        5,
                        5,
                        competency,
                        3,
                        "Разговор закрыт: правило на месте, человека поблагодарили и не бросили.",
                        "o_good",
                    ),
                    _choice("mid", "«Я всё сказал. Дальше сами, у меня другие пассажиры.»", "acceptable", -2, 3, competency, 1, "Формально ответ дан, но человек остаётся один с нерешённым вопросом.", "o_mixed"),
                    _choice("bad", refusal, "harmful", -8, -16, competency, 0, "В финале правило снова обошли. Закрыть ситуацию так нельзя.", "o_bad"),
                ],
                "o_bad",
            ),
            "o_good": {"kind": "outcome", "narration": f"Ситуация «{title}» закрыта по правилу, пассажир понял следующий шаг.", "verdict": f"Ситуация «{title}» закрыта по правилу."},
            "o_mixed": {"kind": "outcome", "narration": f"Правило в «{title}» названо, но человека оставили без ясного шага.", "verdict": f"Правило названо, следующий шаг пассажир не получил."},
            "o_bad": {
                "kind": "outcome",
                "narration": f"В ситуации «{title}» правило обошли или промолчали.",
                "verdict": f"Ситуация «{title}» закрыта с нарушением.",
                "critical_failure": critical,
            },
            "o_remembered": {
                "kind": "outcome",
                "narration": f"Финал по «{title}» верный, но раньше правило уже нарушали.",
                "verdict": "Верная последняя фраза не отменяет прежнее нарушение.",
                "critical_failure": critical,
            },
        },
    }
    document["nodes"]["s3"]["options"][0]["branches"] = [
        {
            "when": {"after_harmful": True},
            "next": "o_remembered",
            "note": "Последняя фраза верная, но раньше в этой попытке уже было вредное решение или молчание.",
        }
    ]
    for node in document["nodes"].values():
        options = node.get("options") or []
        _fit_lengths(options)
    scenario = Scenario.model_validate(document)
    validate(scenario)
    return document


def next_number() -> int:
    numbers = [scenario.number for scenario in service.catalog().values()]
    return max(numbers or [0]) + 1


def save_scenario(payload: dict) -> Scenario:
    document = build_scenario_document(payload, next_number())
    path = scenarios.SCENARIOS_DIR / f"{document['number']:02d}_{document['id']}.json"
    if path.exists():
        raise AdminError("Файл ситуации уже есть")
    path.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    try:
        service.reload_catalog()
    except ScenarioError:
        path.unlink(missing_ok=True)
        service.reload_catalog()
        raise
    return service.get_scenario(document["id"])


def list_employees(connection: sqlite3.Connection) -> list[dict]:
    rows = connection.execute(
        "SELECT id, login, display_name, position, brigade, depot, access_code FROM employees ORDER BY display_name"
    ).fetchall()
    return [dict(row) for row in rows]


def _fresh_code(connection: sqlite3.Connection) -> str:
    taken = {
        row["access_code"]
        for row in connection.execute("SELECT access_code FROM employees WHERE access_code IS NOT NULL")
    }
    for _ in range(50):
        code = f"{random.randint(1000, 9999)}"
        if code not in taken:
            return code
    raise AdminError("Не удалось подобрать свободный код")


def create_employee(connection: sqlite3.Connection, payload: dict) -> dict:
    name = payload["display_name"].strip()
    if not name:
        raise AdminError("Нужно имя проводника")
    code = _fresh_code(connection)
    login = f"conductor.{code}"
    connection.execute(
        "INSERT INTO employees (login, display_name, position, brigade, depot, xp, access_code) VALUES (?, ?, ?, ?, ?, 0, ?)",
        (
            login,
            name,
            payload.get("position", "Проводник").strip() or "Проводник",
            payload.get("brigade", "Бригада 1").strip() or "Бригада 1",
            payload.get("depot", "Депо Москва-Восточное").strip() or "Депо Москва-Восточное",
            code,
        ),
    )
    row = connection.execute("SELECT id, login, display_name, position, brigade, depot, access_code FROM employees WHERE login = ?", (login,)).fetchone()
    return dict(row)


def reissue_code(connection: sqlite3.Connection, employee_id: int) -> dict:
    if connection.execute("SELECT 1 FROM employees WHERE id = ?", (employee_id,)).fetchone() is None:
        raise AdminError("Проводник не найден")
    code = _fresh_code(connection)
    connection.execute("UPDATE employees SET access_code = ? WHERE id = ?", (code, employee_id))
    row = connection.execute(
        "SELECT id, login, display_name, position, brigade, depot, access_code FROM employees WHERE id = ?",
        (employee_id,),
    ).fetchone()
    return dict(row)
