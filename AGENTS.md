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

## Соглашения по SQL-скриптам

**Перед написанием скрипта сначала посмотрите, как уже сделаны объекты этого слоя** —
не изобретайте свой стиль:

1. DDS/DM: `public.sql_inventory` — фактический DDL-эталон. Возьмите последние
   объекты и образец того же типа:
   ```sql
   select target_table, updated_at from public.sql_inventory order by updated_at desc limit 10;
   select query_text from public.sql_inventory where target_table = '<имя>';
   ```
2. ODS: реестра нет, эталон — `scripts/ods_seed_new_tables.sql`.
3. Готовые примеры по слоям — `scripts/dds_seed_detail_from_ods.sql`,
   `scripts/dm_seed_datamarts_from_dds.sql`.

Правила DDS/DM:

- объект создаётся только `CREATE TABLE core.<name> AS SELECT ... FROM ext_ods.<table>`
  (в dm — из `ext_dds.<table>`); **никаких** `ALTER TABLE`, `COMMENT ON`,
  `PRIMARY KEY`, `CREATE INDEX` — в реестре таких операторов нет;
- в конце выборки всегда идут технические поля в этом порядке и с этими
  комментариями: `source_system_id`, `is_active`, `is_deleted`,
  `dwh_start_date`, `dwh_end_date`, `etl_process_id`;
- view — `CREATE OR REPLACE VIEW core.v_<name> AS ...` (тоже одной строкой,
  без комментариев к колонкам);
- имена: dds — `<сущность>_detail`, dm — `*_overview` / `*_datamart_*` /
  `*_risk_analysis`, view — `v_*`;
- источники указываются с квалификатором слоя (`dds.ext_ods.abs_account`);
- стиль: ключевые слова в нижнем регистре, один столбец на строку,
  комментарии `--` по-русски.

Правила ODS: `DROP TABLE IF EXISTS` + `CREATE TABLE` с явными типами и `PRIMARY KEY`
+ `INSERT` тестовых строк; dwh-полей в ODS нет, есть `source_system`/`load_dttm`.

Перед сдачей сверьте свой скрипт с `query_text` аналогичного объекта в реестре:
структура, набор технических полей и отсутствие «лишних» операторов должны совпадать.

## Правила работы

- Подключение только на чтение (роль `ai_reader` + guard в коде).
- Запросы — только `SELECT` / `WITH` / `TABLE`.
- Джойны — только в пределах одного слоя; между слоями — только через `ext_*`.
- Схему конкретного слоя смотрите через его MCP-сервер; для кросскультурного
  поиска можно использовать `src/dwh/db.py`.
- При неоднозначности вопроса — переспрашивайте или уточните слой.
- Любой новый SQL-скрипт — по разделу «Соглашения по SQL-скриптам»
  (сначала эталон из `public.sql_inventory`, потом код).

## Инструменты

- Запуск Python: `.venv\Scripts\python` (windows).
- Код: `src/dwh/config.py` (DSN всех слоёв), `src/dwh/db.py`
  (`query(sql, layer="dds")`).
- Проверка подключений: `.venv\Scripts\python scripts/check_db.py`.
- Конфигурация MCP: `opencode.json` + `scripts/mcp-postgres.ps1`.