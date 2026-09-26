-- Схема демо-базы тренажёра. Все данные синтетические: реальные персональные
-- данные пассажиров и сотрудников в базу не попадают (152-ФЗ).

CREATE TABLE IF NOT EXISTS employees (
    id           INTEGER PRIMARY KEY,
    login        TEXT    NOT NULL UNIQUE,
    display_name TEXT    NOT NULL,
    position     TEXT    NOT NULL,
    brigade      TEXT    NOT NULL,
    depot        TEXT    NOT NULL,
    xp           INTEGER NOT NULL DEFAULT 0,
    hr_ref       TEXT
);

CREATE TABLE IF NOT EXISTS competency_points (
    employee_id INTEGER NOT NULL REFERENCES employees (id) ON DELETE CASCADE,
    competency  TEXT    NOT NULL,
    points      INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (employee_id, competency)
);

CREATE TABLE IF NOT EXISTS attempts (
    id          INTEGER PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees (id) ON DELETE CASCADE,
    scenario_id TEXT    NOT NULL,
    status      TEXT    NOT NULL CHECK (status IN ('in_progress', 'finished')),
    node_id     TEXT    NOT NULL,
    loyalty     INTEGER NOT NULL,
    safety      INTEGER NOT NULL,
    -- Дедлайн текущего узла считает сервер, поэтому перезагрузка страницы
    -- не продлевает время на решение.
    deadline_at TEXT,
    started_at  TEXT    NOT NULL,
    finished_at TEXT,
    passed      INTEGER,
    xp_awarded  INTEGER
);

CREATE INDEX IF NOT EXISTS idx_attempts_employee ON attempts (employee_id, started_at);

CREATE TABLE IF NOT EXISTS attempt_steps (
    id         INTEGER PRIMARY KEY,
    attempt_id INTEGER NOT NULL REFERENCES attempts (id) ON DELETE CASCADE,
    position   INTEGER NOT NULL,
    -- Шаг сохраняется в том виде, в котором его вернул движок: разбор попытки
    -- собирается из истории, а не пересчитывается заново.
    payload    TEXT    NOT NULL,
    UNIQUE (attempt_id, position)
);

CREATE TABLE IF NOT EXISTS achievements (
    code        TEXT PRIMARY KEY,
    title       TEXT NOT NULL,
    description TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS employee_achievements (
    employee_id INTEGER NOT NULL REFERENCES employees (id) ON DELETE CASCADE,
    code        TEXT    NOT NULL REFERENCES achievements (code) ON DELETE CASCADE,
    awarded_at  TEXT    NOT NULL,
    PRIMARY KEY (employee_id, code)
);

CREATE TABLE IF NOT EXISTS notifications (
    id          INTEGER PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees (id) ON DELETE CASCADE,
    kind        TEXT    NOT NULL,
    title       TEXT    NOT NULL,
    body        TEXT    NOT NULL,
    created_at  TEXT    NOT NULL,
    read_at     TEXT
);

CREATE INDEX IF NOT EXISTS idx_notifications_employee ON notifications (employee_id, created_at);
