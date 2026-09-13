# DWH Text-to-SQL

Проект Text-to-SQL: естественные вопросы на русском превращаются в SQL к
локальному PostgreSQL (банковский data warehouse). Репозиторий синхронизирован
с GitHub.

## Структура

```
opencode.json           конфигурация opencode (3 MCP-сервера PostgreSQL: ods/dds/dm)
.env.example            шаблон переменных окружения
requirements.txt        зависимости Python
src/dwh/config.py       чтение DATABASE_URL_{ODS,DDS,DM}
src/dwh/db.py           подключение к БД, запросы только на чтение
scripts/check_db.py     проверка подключения ко всем слоям хранилища
scripts/mcp-postgres.ps1  запуск MCP-сервера PostgreSQL (читает .env по имени слоя)
```

## 1. База данных

Используется **read-only роль** (вы её уже создали). Если нужна для
справочника, создать её можно так:

```sql
CREATE ROLE dwh_ro LOGIN PASSWORD '...';
GRANT USAGE ON SCHEMA public TO dwh_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO dwh_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO dwh_ro;
```

## 2. Настройка подключения

```powershell
Copy-Item .env.example .env
# отредактируйте .env: три строки подключения к слоям ods/dds/dm
# DATABASE_URL_ODS=postgresql://user:pass@localhost:5432/ods
# DATABASE_URL_DDS=postgresql://user:pass@localhost:5432/dds
# DATABASE_URL_DM=postgresql://user:pass@localhost:5432/dm
```

## 3. MCP-сервер PostgreSQL (для opencode)

Подключены **три** экземпляра официального reference-сервера
`@modelcontextprotocol/server-postgres` (запускаются через `npx`, нужен Node.js) —
по одному на слой `ods`, `dds`, `dm`. Они дают инструменты для инспекции
схемы и выполнения чтения: `query`, `list_schemas`, `list_tables`,
`describe_table`, `get_foreign_keys`, `get_primary_keys` — всё, что нужно для
генерации SQL из естественного языка.

Строки подключения берутся **прямо из `.env`** (пароль не попадает в git):
`opencode.json` запускает `scripts/mcp-postgres.ps1`, который читает
`DATABASE_URL_<СЛОЙ>` из файла `.env` и передаёт её серверу. Никаких `setx` и
переменных окружения процесса не нужно.

1. Убедитесь, что в `.env` записаны рабочие `DATABASE_URL_ODS/DDS/DM`.
2. Запустите (перезапустите) opencode в этой папке. Сервер `postgres`
   подключится автоматически, его инструменты появятся у агента.

Если `/mcp` показывает `failed` — запустите вручную для отладки:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\mcp-postgres.ps1
   ```

Альтернативный MCP (Python, активно поддерживается) — `postgres-mcp`
(Postgres MCP Pro): `uvx postgres-mcp`, конфигурация через env
`POSTGRES_CONNECTION_STRING`.

## 4. Проверка подключения

```powershell
python -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt
.venv\Scripts\python scripts/check_db.py
```

## 5. Кросс-слойные джойны и реестр DDL

Три слоя хранилища — три физические БД PostgreSQL без прямых связей. SQL
джойнит таблицы **только внутри одного слоя**. Чтобы соединить данные разных
слоёв, используются внешние таблицы-копии в схемах `ext_*` — данные из других
слоёв, уже доступные локально.

В `dds` и `dm` есть технические таблицы `public.sql_inventory` — журнал DDL.
Event-trigger `capture_ddl_sql_trigger_public` (события `CREATE TABLE AS`,
`SELECT INTO`, `CREATE VIEW`) автоматически записывает в них скрипт каждого
нового объекта: колонки `target_schema`, `target_table`, `query_text`,
`updated_at`. По реестру видно, из чего собрана каждая таблица (таблица →
скрипт → источники), т.е. откуда берутся данные.

## 6. Как пользоваться

Обращайтесь к агенту на русском, например:

> какие таблицы есть в схеме public?
> покажи топ-10 клиентов по обороту за последний квартал

## Безопасность

- `.env` и `.venv` в `.gitignore` — секреты не попадают в GitHub.
- Права только на чтение ограничиваются ролью в БД + кодом
  (`src/dwh/db.py` пропускает лишь `SELECT`/`WITH`/`TABLE`).