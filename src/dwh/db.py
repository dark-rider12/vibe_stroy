"""Доступ к PostgreSQL data warehouse.

Дополнительная защита «только чтение» на уровне кода: разрешены только
SELECT / WITH / TABLE запросы. Основная защита — read-only роль в БД.
"""
from __future__ import annotations

from typing import Any

import psycopg

from .config import DATABASE_URL

_ALLOWED_PREFIXES = ("SELECT", "WITH", "TABLE")


def connect() -> psycopg.Connection:
    return psycopg.connect(DATABASE_URL)


def query(sql: str, params: tuple | None = None) -> list[dict[str, Any]]:
    guard = sql.lstrip().upper()
    if not guard.startswith(_ALLOWED_PREFIXES):
        raise ValueError("Разрешены только запросы на чтение (SELECT/WITH/TABLE).")

    with connect() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
        if cur.description is None:
            return []
        columns = [desc.name for desc in cur.description]
        rows = cur.fetchall()
    return [dict(zip(columns, row)) for row in rows]