"""Проверка подключения к хранилищу под read-only ролью."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from dwh.db import query  # noqa: E402


def main() -> None:
    version = query("SELECT version()")
    print("Connected:", version[0]["version"])

    tables = query(
        "SELECT schemaname, tablename FROM pg_tables "
        "WHERE schemaname NOT IN ('pg_catalog', 'information_schema') "
        "ORDER BY schemaname, tablename LIMIT 20"
    )
    print(f"User tables (sample, {len(tables)}):")
    for row in tables:
        print(f"  {row['schemaname']}.{row['tablename']}")


if __name__ == "__main__":
    main()