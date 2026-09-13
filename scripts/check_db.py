"""Проверка подключения ко всем слоям хранилища под read-only ролью."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from dwh.config import LAYERS  # noqa: E402
from dwh.db import query  # noqa: E402


def main() -> None:
    for layer in LAYERS:
        print(f"\n=== {layer.upper()} ===")
        tables = query(
            "SELECT schemaname, tablename FROM pg_tables "
            "WHERE schemaname NOT IN ('pg_catalog', 'information_schema') "
            "ORDER BY schemaname, tablename LIMIT 20",
            layer=layer,
        )
        print(f"Connected, user tables (sample, {len(tables)}):")
        for row in tables:
            print(f"  {row['schemaname']}.{row['tablename']}")


if __name__ == "__main__":
    main()