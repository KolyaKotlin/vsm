"""Общие фикстуры тестов: каждый тест работает на своей временной базе."""

from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import Iterator

import pytest
from fastapi.testclient import TestClient


@pytest.fixture()
def db_file(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    path = tmp_path / "vsm-test.sqlite3"
    monkeypatch.setenv("VSM_DB_PATH", str(path))
    return path


@pytest.fixture()
def client(db_file: Path) -> Iterator[TestClient]:
    from app.main import app

    # Контекстный менеджер запускает lifespan: создаются таблицы и демо-данные.
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture()
def raw_db(db_file: Path) -> Iterator[sqlite3.Connection]:
    connection = sqlite3.connect(db_file)
    connection.row_factory = sqlite3.Row
    try:
        yield connection
    finally:
        connection.close()


@pytest.fixture()
def trainee_id(client: TestClient) -> int:
    employees = client.get("/api/employees").json()
    return next(item["id"] for item in employees if item["login"] == "demo.trainee")
