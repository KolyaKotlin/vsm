"""Подключение к SQLite и инициализация демо-базы."""

from __future__ import annotations

import os
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
SCHEMA_PATH = BASE_DIR / "schema.sql"
DEFAULT_DB_PATH = BASE_DIR.parent / "data" / "vsm.sqlite3"


def db_path() -> Path:
    """Путь к файлу базы. В Docker переопределяется переменной VSM_DB_PATH."""
    return Path(os.environ.get("VSM_DB_PATH", DEFAULT_DB_PATH))


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def parse_iso(value: str) -> datetime:
    return datetime.fromisoformat(value)


def connect() -> sqlite3.Connection:
    path = db_path()
    path.parent.mkdir(parents=True, exist_ok=True)

    connection = sqlite3.connect(path, isolation_level=None)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    connection.execute("PRAGMA journal_mode = WAL")
    return connection


def init_db() -> None:
    """Создаёт таблицы и, если база пустая, наполняет её синтетическими данными."""
    from . import seed

    with connect() as connection:
        connection.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))
        seed.ensure_reference_data(connection)
        if connection.execute("SELECT COUNT(*) FROM employees").fetchone()[0] == 0:
            seed.ensure_demo_employees(connection)
