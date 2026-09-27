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

from pydantic import ValidationError

from . import scenarios, service
from .engine import COMPETENCY_TITLES, Scenario, ScenarioError, validate

ADMIN_CODE = os.environ.get("VSM_ADMIN_CODE", "mentor")


class AdminError(Exception):
    pass


def check_code(code: str) -> None:
    if code.strip() != ADMIN_CODE:
        raise AdminError("Нужен код методиста")


def _plain(text: str) -> str:
    """Убирает кавычки и лишние точки: фраза вставится в свою реплику."""
    return " ".join(text.replace("«", " ").replace("»", " ").split()).strip(" .")


def _sentence(text: str) -> str:
    clean = _plain(text)
    if not clean:
        return ""
    return clean[0].upper() + clean[1:]


def _spoken(text: str) -> str:
    return f"«{_sentence(text)}.»"


def _fit_lengths(options: list[dict], tails: list[str]) -> None:
    """Короткая реплика читается как ошибка. Добиваем длину разными фразами, не одной и той же."""
    if len(options) < 2:
        return
    for _ in range(len(tails)):
        longest = max(len(item["text"]) for item in options)
        pending = [item for item in options if longest - len(item["text"]) > 50]
        if not pending:
            return
        for item in pending:
            unused = next((tail for tail in tails if tail not in item["text"]), None)
            if unused is None:
                continue
            text = item["text"].rstrip()
            item["text"] = text[:-1].rstrip() + " " + unused + "»" if text.endswith("»") else text + " " + unused


def _debrief(text: str, better: str | None = None) -> str:
    body = " ".join(text.split())
    if better:
        body = f"{body} Лучше было так: {better}"
    if len(body) > 40:
        return body
    return f"{body} Пассажир должен услышать правило и понять, что делать дальше."


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
    """Собирает ситуацию из фактов методиста, а не из общего текста про «исключение».

    Правило и законный шаг звучат в репликах. Если промолчать или обойти правило,
    разговор уходит в другую сцену — как в остальных ситуациях журнала.
    """

    title = str(payload.get("title", "")).strip()
    summary = str(payload.get("summary", "")).strip()
    competency = str(payload.get("primary_competency", "")).strip()
    rule = str(payload.get("rule", "")).strip()
    refusal = str(payload.get("refusal", "")).strip()
    scene = str(payload.get("scene", "")).strip()
    passenger = str(payload.get("passenger", "")).strip()
    offer = str(payload.get("offer", "")).strip()
    missing = [
        label
        for label, value in (
            ("название", title),
            ("о чём ситуация", summary),
            ("что происходит", scene),
            ("реплика пассажира", passenger),
            ("правило", rule),
            ("ошибочная реплика", refusal),
        )
        if not value
    ]
    if missing:
        raise AdminError("Заполните поля: " + ", ".join(missing))
    if competency not in COMPETENCY_TITLES:
        raise AdminError("Неизвестная компетенция ситуации")
    if not offer:
        offer = "я подскажу законный следующий шаг и останусь рядом, пока вопрос не закроется"
    scenario_id = f"custom_{number}_{_slug(title)}"
    critical = bool(payload.get("critical"))
    bad_next = "o_bad" if critical else "s_slip"
    rule_clause = _plain(rule)
    offer_sentence = _sentence(offer)
    wrong = _spoken(refusal)

    def late(default_next: str) -> list[dict]:
        return [
            {
                "when": {"after_harmful": True},
                "next": "o_remembered",
                "note": "Последняя фраза верная, но раньше в этой попытке уже было вредное решение или молчание.",
            }
        ] if default_next != "o_remembered" else []

    def choices(opt_text: str, opt_why: str, opt_next: str, mid_text: str, mid_why: str, mid_next: str, bad_text: str, bad_why: str, bad_to: str) -> list[dict]:
        made = [
            _choice("opt", opt_text, "optimal", 5, 5, competency, 3, _debrief(opt_why), opt_next),
            _choice("mid", mid_text, "acceptable", -2, 3, competency, 1, _debrief(mid_why, opt_text), mid_next),
            _choice("bad", bad_text, "harmful", -8, -16, competency, 0, _debrief(bad_why, opt_text), bad_to),
        ]
        if opt_next in {"o_good", "s5"}:
            made[0]["branches"] = late(opt_next)
        return made

    def step(narration: str, line: str, timer: int, options: list[dict], timeout_next: str, silence: str) -> dict:
        better = options[0]["text"]
        return {
            "kind": "situation",
            "narration": narration,
            "passenger": line,
            "timer_seconds": timer,
            "options": options,
            "timeout": {
                "text": silence,
                "effects": {"loyalty": -8, "safety": -8, "competencies": {}},
                "debrief": _debrief("Молчание здесь читается как отказ помогать. Нужно ответить сразу.", better),
                "next": timeout_next,
            },
        }

    nodes = {
        "s1": step(
            scene,
            _spoken(passenger),
            25,
            choices(
                f"«Я вас понимаю. Обращаю ваше внимание: {rule_clause}. {offer_sentence}.»",
                f"Сначала признали человека и сразу назвали правило этой ситуации: {rule_clause}.",
                "s2",
                f"«{ _sentence(rule) }. Разбираться дольше не будем, проходите и не задерживайте салон.»",
                "Правило названо, но человека не услышали, и он начинает говорить громче.",
                "s_loud",
                wrong,
                f"Так обходят правило «{rule_clause}».",
                bad_next,
            ),
            "s_loud",
            "Проводник молчит, и пассажир повторяет требование так, чтобы слышали рядом.",
        ),
        "s2": step(
            f"Пассажир не принимает первый ответ и говорит громче. Суть спора та же: {summary}",
            "«Мне всё равно, как у вас принято. Сделайте, как я прошу, здесь никто не увидит.»",
            22,
            choices(
                f"«Понимаю, что это неудобно. Правило остаётся: {rule_clause}. {offer_sentence}. Я рядом, пока вопрос не закроется.»",
                "Отказ спокойный: правило на месте, и у человека есть понятный следующий шаг.",
                "s3",
                f"«Правило я уже назвал: {rule_clause}. Куда идти дальше, разбирайтесь сами, повторять не стану.»",
                "Рамка удержана, но человека оставили без шага, и он продолжает стоять.",
                "s_loud",
                "«Ладно, в этот раз закрою глаза. Только никому не говорите, что я отступил.»",
                f"Исключение шёпотом отменяет правило «{rule_clause}» и ещё скрывает это от бригады.",
                bad_next,
            ),
            "s_loud",
            "Проводник отворачивается к следующему пассажиру и не отвечает на повтор.",
        ),
        "s3": step(
            "Пассажир всё ещё ждёт, что для него сделают поблажку, и смотрит, отступите ли вы.",
            "«Ну так что, для меня-то можно? Один раз ничего не изменит.»",
            22,
            choices(
                f"«Для одного раза правила не отменяют. {offer_sentence}. Если станет сложнее, позовите меня.»",
                "Попытку выбить исключение закрыли спокойно и снова назвали, что будет дальше.",
                "s4",
                f"«Нельзя, и хватит спрашивать. { _sentence(rule) }.»",
                "Правило повторили, но тоном, из-за которого спор становится личным.",
                "s_loud",
                wrong,
                "В середине разговора правило снова обошли той же репликой.",
                bad_next,
            ),
            "s_loud",
            "Проводник смотрит в пустоту и ждёт, что пассажир сам отстанет.",
        ),
        "s4": step(
            f"Человек достаёт телефон и не отходит. Салон уже смотрит, чем кончится «{title}».",
            "«Я всё снимаю. Пусть будет видно, как вы мне отказываете.»",
            20,
            choices(
                f"«Снимайте, если нужно. Правило от этого не меняется: {rule_clause}. {offer_sentence}.»",
                "Съёмка не сбила с правила, и следующий шаг снова назван.",
                "s5",
                "«Уберите телефон, иначе разговора не будет. Я и так вам всё сказал.»",
                "Вместо правила разговор свернули на телефон, и человек остаётся без шага.",
                "s_loud",
                wrong,
                "Под камеру правило обошли. Это то же нарушение, только ещё и записанное.",
                bad_next,
            ),
            "s5",
            "Проводник замолкает, как только видит телефон.",
        ),
        "s5": step(
            "Нужно закрыть разговор: подтвердить, что будет дальше, и вернуть салон к работе.",
            "«И что мне теперь конкретно делать?»",
            20,
            choices(
                f"«Благодарю за понимание. {offer_sentence}. Я на связи, если станет хуже.»",
                "Разговор закрыт: человека поблагодарили и не бросили с нерешённым вопросом.",
                "o_good",
                "«Я всё сказал. Дальше сами, у меня другие пассажиры.»",
                "Формально ответ был раньше, но сейчас человека оставили одного.",
                "o_mixed",
                wrong,
                "В финале правило снова обошли. Закрыть ситуацию так нельзя.",
                "o_bad",
            ),
            "o_bad",
            "Проводник уходит по салону, не закрыв вопрос.",
        ),
        "s_loud": step(
            f"Голос уже на весь проход. Соседи ждут, кто уступит в ситуации «{title}».",
            "«Ну и где ваш сервис? Все слышат, как вы мне отказываете.»",
            18,
            choices(
                f"«Давайте тише, я вас слышу. Правило такое: {rule_clause}. {offer_sentence}.»",
                "Громкий спор вернули к правилу и к шагу, не отвечая тем же тоном.",
                "s5",
                f"«Не кричите на весь вагон. Правило я назвал: {rule_clause}.»",
                "Тон осадили, но следующий шаг снова не назвали.",
                "o_mixed",
                wrong,
                "Под взглядом салона правило обошли. Остальные это тоже видят.",
                "o_bad",
            ),
            "o_bad",
            "Проводник молчит, пока пассажир повторяет претензию на весь проход.",
        ),
        "o_good": {
            "kind": "outcome",
            "narration": f"Ситуация «{title}» закрыта: правило названо, и пассажир понял, что делать дальше. {offer_sentence}.",
            "verdict": f"Ситуация «{title}» закрыта по правилу.",
        },
        "o_mixed": {
            "kind": "outcome",
            "narration": f"Правило в «{title}» прозвучало, но человек так и не услышал, что ему делать.",
            "verdict": "Правило названо, следующий шаг пассажир не получил.",
        },
        "o_bad": {
            "kind": "outcome",
            "narration": f"В ситуации «{title}» правило обошли или промолчали. { _sentence(summary) }.",
            "verdict": f"Ситуация «{title}» закрыта с нарушением.",
            "critical_failure": critical,
        },
        "o_remembered": {
            "kind": "outcome",
            "narration": f"Финал по «{title}» верный, но раньше правило «{rule_clause}» уже нарушали.",
            "verdict": "Верная последняя фраза не отменяет прежнее нарушение.",
            "critical_failure": critical,
        },
    }
    if not critical:
        nodes["s_slip"] = step(
            f"Правило уже обошли. Пассажир это заметил и ждёт, что так и останется. Речь о «{title}».",
            "«Вот, сразу бы так. Теперь не отменяйте.»",
            18,
            choices(
                f"«Я поспешил и был неправ. Обращаю ваше внимание: {rule_clause}. {offer_sentence}.»",
                "Ошибку назвали вслух и вернули правило вместе со следующим шагом.",
                "o_remembered",
                "«Извините, если резко. Но сделанного уже не верну, давайте на этом закончим.»",
                "Извинение есть, а правило так и осталось обойденным.",
                "o_mixed",
                "«Раз уж сказал — значит, так и будет. Не переигрываем.»",
                "Ошибку закрепили второй раз. Вернуть правило после этого уже нечем.",
                "o_bad",
            ),
            "o_bad",
            "Проводник делает вид, что никакой уступки не было.",
        )

    document = {
        "id": scenario_id,
        "number": number,
        "section": str(payload.get("section", "Добавленные")).strip() or "Добавленные",
        "title": title,
        "summary": summary,
        "service_class": str(payload.get("service_class", "стандарт")).strip() or "стандарт",
        "car": str(payload.get("car", "Вагон 1")).strip() or "Вагон 1",
        "primary_competency": competency,
        "initial_loyalty": 70,
        "initial_safety": 80,
        "start": "s1",
        "nodes": nodes,
    }
    tails = [
        "Скажу это ровно так и ничего больше не добавлю.",
        "Даже если пассажир переспросит, вторую фразу я не произнесу.",
        "После этой реплики я жду, что человек сам отойдёт.",
        "Соседям я ничего отдельно объяснять не стану.",
        f"Ситуацию «{title}» я закрываю именно этой фразой.",
        "Дальше стою молча и жду, пока проход освободится.",
    ]
    for node in document["nodes"].values():
        options = node.get("options") or []
        _fit_lengths(options, tails)
    try:
        scenario = Scenario.model_validate(document)
    except ValidationError as error:
        raise ScenarioError(f"Ситуацию не удалось собрать: {error.error_count()} ошибок в структуре") from error
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
    try:
        path.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except OSError as error:
        raise AdminError("Не удалось записать ситуацию: папка каталога закрыта для записи") from error
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
