"""Зависимости FastAPI."""

from __future__ import annotations

import sqlite3
from typing import Iterator

from .db import connect


def get_connection() -> Iterator[sqlite3.Connection]:
    connection = connect()
    try:
        yield connection
    finally:
        connection.close()
