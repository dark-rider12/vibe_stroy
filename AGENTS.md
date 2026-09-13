# AGENTS.md

Проект **DWH Text-to-SQL**: русские вопросы превращаются в SQL по банковскому
data warehouse. Читайте README.md для полной инструкции.

## Архитектура

Три слоя хранилища, каждый — отдельная БД PostgreSQL с отдельным MCP-сервером:

| Слой | БД | MCP-сервер | Содержимое |
|------|----|------------|-----------|
| ods  | ods  | `postgres_ods` | сырые данные из АБС/CRM (`core.abs_*`, `core.crm_*`, `core.1C_leasing`) |
| dds  | dds  | `postgres_dds` | детальные измерения (`core.*_detail`), расчёты (`calc.*`) |
| dm   | dm   | `postgres_dm`  | витрины данных (`core.*_overview/risk_analysis/datamart_*`) |

Ключевые домены: клиенты, счета, карты, договоры, транзакции, лизинг, риск.

Стандартные схемы: `core` (основные), `calc` (расчётные), `ext_*` (копии из
других слоёв), `sandbox_*` (черновики — игнорировать), `public` (служебное).

Три слоя — три физические БД без прямых связей, поэтому **SQL джойнит
таблицы только внутри одного слоя**. Кросс-слойное соединение выполняется
исключительно через внешние таблицы-копии в схемах `ext_*`.

**Реестр DDL.** В `dds.public.sql_inventory` и `dm.public.sql_inventory`
event-trigger `capture_ddl_sql_trigger_public` (события `CREATE TABLE AS`,
`SELECT INTO`, `CREATE VIEW`) записывает скрипт каждого нового объекта.
Колонки: `target_schema`, `target_table`, `query_text`, `updated_at`.
По ним видно, из чего собрана каждая таблица и откуда берутся данные.

## Правила работы

- Подключение только на чтение (роль `ai_reader` + guard в коде).
- Запросы — только `SELECT` / `WITH` / `TABLE`.
- Джойны — только в пределах одного слоя; между слоями — только через `ext_*`.
- Схему конкретного слоя смотрите через его MCP-сервер; для кросскультурного
  поиска можно использовать `src/dwh/db.py`.
- При неоднозначности вопроса — переспрашивайте или уточните слой.

## Инструменты

- Запуск Python: `.venv\Scripts\python` (windows).
- Код: `src/dwh/config.py` (DSN всех слоёв), `src/dwh/db.py`
  (`query(sql, layer="dds")`).
- Проверка подключений: `.venv\Scripts\python scripts/check_db.py`.
- Конфигурация MCP: `opencode.json` + `scripts/mcp-postgres.ps1`.