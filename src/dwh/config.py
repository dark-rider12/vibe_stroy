"""Настройки проекта. Читает DATABASE_URL из окружения или из .env в корне репозитория."""
from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[2] / ".env")

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError(
        "Переменная DATABASE_URL не задана. Скопируйте .env.example в .env "
        "и укажите строку подключения к хранилищу."
    )