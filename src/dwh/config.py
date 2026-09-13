"""Настройки проекта. Читает DATABASE_URL_* из окружения или из .env в корне репозитория."""
from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[2] / ".env")

LAYERS = ("ods", "dds", "dm")


def database_urls() -> dict[str, str]:
    """Строки подключения ко всем слоям хранилища: ods, dds, dm."""
    urls: dict[str, str] = {}
    for layer in LAYERS:
        url = os.getenv(f"DATABASE_URL_{layer.upper()}")
        if not url:
            raise RuntimeError(
                f"Переменная DATABASE_URL_{layer.upper()} не задана. "
                "Скопируйте .env.example в .env и укажите строку подключения к слою " + layer + "."
            )
        urls[layer] = url
    return urls


DATABASE_URL = database_urls()["dds"]