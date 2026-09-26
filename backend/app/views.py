"""Модели ответов API.

Отдельный слой нужен по одной причине: проходящий сценарий не должен видеть
«правильность» вариантов. В движке у варианта есть quality и effects, а в
OptionView остаются только идентификатор и текст реплики. Эффекты и разбор
приходят уже после выбора.
"""

from __future__ import annotations

from pydantic import BaseModel

from .engine import Step


class OptionView(BaseModel):
    id: str
    text: str


class NodeView(BaseModel):
    id: str
    kind: str
    narration: str
    passenger: str | None = None
    options: list[OptionView] = []
    timer_seconds: int | None = None
    deadline_at: str | None = None


class ScenarioBrief(BaseModel):
    id: str
    title: str
    summary: str
    service_class: str
    car: str
    primary_competency: str


class CompetencyGain(BaseModel):
    competency: str
    title: str
    points: int


class UnlockedAchievement(BaseModel):
    code: str
    title: str
    description: str


class DebriefView(BaseModel):
    """Разбор попытки: что повлияло на шкалы и что можно было сделать лучше."""

    passed: bool
    verdict: str
    loyalty: int
    safety: int
    timeouts: int
    harmful_choices: int
    competency_gain: list[CompetencyGain]
    steps: list[Step]
    xp_awarded: int
    unlocked_achievements: list[UnlockedAchievement] = []


class AttemptView(BaseModel):
    attempt_id: int
    employee_id: int
    scenario: ScenarioBrief
    loyalty: int
    safety: int
    finished: bool
    steps_taken: int
    node: NodeView | None = None
    last_step: Step | None = None
    # Время сервера отдаётся вместе с дедлайном: клиент рисует таймер от него,
    # а решение об истечении времени всё равно принимает сервер.
    server_time: str
    debrief: DebriefView | None = None


class CompetencyProfile(BaseModel):
    competency: str
    title: str
    points: int


class ProfileView(BaseModel):
    employee_id: int
    login: str
    display_name: str
    position: str
    brigade: str
    depot: str
    xp: int
    level: int
    xp_to_next_level: int
    competencies: list[CompetencyProfile]
    achievements: list[UnlockedAchievement]
    attempts_finished: int
    unread_notifications: int


class EmployeeBrief(BaseModel):
    id: int
    login: str
    display_name: str
    position: str
    brigade: str
    depot: str
    xp: int
    level: int


class LeaderboardRow(BaseModel):
    place: int
    employee_id: int
    display_name: str
    brigade: str
    depot: str
    xp: int
    level: int


class NotificationView(BaseModel):
    id: int
    kind: str
    title: str
    body: str
    created_at: str
    read_at: str | None = None


class CompetencyAnalytics(BaseModel):
    competency: str
    title: str
    points: int
    share: float
    status: str


class AnalyticsView(BaseModel):
    employee_id: int
    attempts_finished: int
    attempts_passed: int
    timeouts: int
    harmful_choices: int
    average_loyalty: int | None
    average_safety: int | None
    competencies: list[CompetencyAnalytics]
    gaps: list[str]
    recommendations: list[str]
