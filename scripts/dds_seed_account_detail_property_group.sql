-- DDS-слой (silver). Детальные таблицы групп свойств и доп. свойств счетов + пересборка
-- core.account_detail с полем account_property_group_id.
-- Предпосылка: во внешней схеме dds.ext_ods уже созданы (CREATE FOREIGN TABLE ... SERVER ods_server)
-- ext_ods.abs_account, ext_ods.abs_contract, ext_ods.crm_client,
-- ext_ods.abs_account_property_group, ext_ods.abs_account_property.
-- Запускать в БД dds ролью-владельцем схемы core.

-- ============================================================
-- 1. abs_account_property_group -> core.account_property_group_detail
--    Ключи: account_id -> core.account_detail(account_id)
-- ============================================================
DROP TABLE IF EXISTS core.account_property_group_detail;
CREATE TABLE core.account_property_group_detail AS
SELECT
    account_property_group_id,
    account_id,
    group_cd,
    group_name,
    group_desc_txt,
    priority_num,
    valid_from,
    valid_to,
    source_system,
    load_dttm
FROM ext_ods.abs_account_property_group;

ALTER TABLE core.account_property_group_detail
    ADD PRIMARY KEY (account_property_group_id);

CREATE INDEX account_property_group_detail_account_ix
    ON core.account_property_group_detail (account_id);

COMMENT ON TABLE core.account_property_group_detail IS
    'Детальная информация по группам свойств банковских счетов (тарифы, сервисы, параметры вклада/карты, риск-флаги). Детальный слой (DDS).';
COMMENT ON COLUMN core.account_property_group_detail.account_property_group_id IS 'Уникальный идентификатор группы свойств счёта';
COMMENT ON COLUMN core.account_property_group_detail.account_id IS 'Уникальный идентификатор счёта, к которому относится группа свойств';
COMMENT ON COLUMN core.account_property_group_detail.group_cd IS 'Код группы свойств (tariff_package, digital_service, deposit_params, card_params, rko_package, risk_flags)';
COMMENT ON COLUMN core.account_property_group_detail.group_name IS 'Наименование группы свойств';
COMMENT ON COLUMN core.account_property_group_detail.group_desc_txt IS 'Описание группы свойств';
COMMENT ON COLUMN core.account_property_group_detail.priority_num IS 'Приоритет группы свойств (1 = основная группа счёта)';
COMMENT ON COLUMN core.account_property_group_detail.valid_from IS 'Дата начала действия группы свойств';
COMMENT ON COLUMN core.account_property_group_detail.valid_to IS 'Дата окончания действия группы свойств (NULL = бессрочно)';
COMMENT ON COLUMN core.account_property_group_detail.source_system IS 'Система-источник данных';
COMMENT ON COLUMN core.account_property_group_detail.load_dttm IS 'Дата-время загрузки данных в хранилище';

-- ============================================================
-- 2. abs_account_property -> core.account_property_detail
--    Ключи: account_property_group_id -> core.account_property_group_detail
-- ============================================================
DROP TABLE IF EXISTS core.account_property_detail;
CREATE TABLE core.account_property_detail AS
SELECT
    account_property_id,
    account_property_group_id,
    property_cd,
    property_name,
    property_value_txt,
    property_value_num,
    value_type_cd,
    unit_cd,
    valid_from,
    valid_to,
    source_system,
    load_dttm
FROM ext_ods.abs_account_property;

ALTER TABLE core.account_property_detail
    ADD PRIMARY KEY (account_property_id);

CREATE INDEX account_property_detail_group_ix
    ON core.account_property_detail (account_property_group_id);

COMMENT ON TABLE core.account_property_detail IS
    'Детальная информация по доп. свойствам банковских счетов, объединённым в группы свойств. Детальный слой (DDS).';
COMMENT ON COLUMN core.account_property_detail.account_property_id IS 'Уникальный идентификатор доп. свойства счёта';
COMMENT ON COLUMN core.account_property_detail.account_property_group_id IS 'Группа свойств счёта. Ссылка на core.account_property_group_detail(account_property_group_id)';
COMMENT ON COLUMN core.account_property_detail.property_cd IS 'Код свойства (tariff_plan, service_fee, sms_notify, credit_limit и т.д.)';
COMMENT ON COLUMN core.account_property_detail.property_name IS 'Наименование свойства';
COMMENT ON COLUMN core.account_property_detail.property_value_txt IS 'Значение свойства в текстовом виде';
COMMENT ON COLUMN core.account_property_detail.property_value_num IS 'Значение свойства в числовом виде';
COMMENT ON COLUMN core.account_property_detail.value_type_cd IS 'Тип значения (text, number, boolean, date)';
COMMENT ON COLUMN core.account_property_detail.unit_cd IS 'Единица измерения значения (RUB, %, days)';
COMMENT ON COLUMN core.account_property_detail.valid_from IS 'Дата начала действия свойства';
COMMENT ON COLUMN core.account_property_detail.valid_to IS 'Дата окончания действия свойства (NULL = бессрочно)';
COMMENT ON COLUMN core.account_property_detail.source_system IS 'Система-источник данных';
COMMENT ON COLUMN core.account_property_detail.load_dttm IS 'Дата-время загрузки данных в хранилище';

-- ============================================================
-- 3. core.account_detail — детализация по счетам + ссылка на группу свойств
--    Новое поле: account_property_group_id -> core.account_property_group_detail
--    (источник — ODS: core.abs_account.account_property_group_id)
-- ============================================================
DROP TABLE IF EXISTS core.account_detail;
CREATE TABLE core.account_detail AS
SELECT
    a.account_id,
    a.account_number,
    a.account_type,
    a.currency_cd,
    a.open_date,
    a.close_date,
    a.balance_amt,
    a.account_status,
    g.account_property_group_id, -- Группа свойств счёта. Ссылка на core.account_property_group_detail
    c.contract_id,
    c.contract_number,
    c.contract_type,
    c.start_date AS contract_start_date,
    c.end_date AS contract_end_date,
    c.interest_rate,
    c.contract_status,
    cl.client_id,
    concat_ws(' ', cl.last_name, cl.first_name, cl.middle_name) AS client_full_name,
    cl.birth_date,
    cl.phone,
    cl.email,
    cl.status_cd AS client_status,
    current_date - a.open_date AS account_age_days,
    uuid_generate_v5(uuid_nil(), 0::text) AS source_system_id, -- ID системы-источника. Ссылка на dds.core.ref_source_system
    true AS is_active, -- Признак актуальности
    false AS is_deleted, -- Признак удаления записи в системе-источнике
    '1900-01-01 23:59:59.999'::timestamp AS dwh_start_date, -- Дата начала действия записи
    '9999-12-31 23:59:59.999'::timestamp AS dwh_end_date, -- Дата окончания действия записи
    uuid_generate_v5(uuid_nil(), 1::text) AS etl_process_id -- ID ETL процесса. Ссылка на справочник ref_etl_process
FROM ext_ods.abs_account a
JOIN ext_ods.abs_contract c
    ON c.contract_id = a.contract_id
JOIN ext_ods.crm_client cl
    ON cl.client_id = c.client_id
LEFT JOIN ext_ods.abs_account_property_group g
    ON g.account_property_group_id = a.account_property_group_id
   AND g.valid_from <= current_date
   AND (g.valid_to IS NULL OR g.valid_to >= current_date);

CREATE INDEX account_detail_property_group_ix
    ON core.account_detail (account_property_group_id);

COMMENT ON TABLE core.account_detail IS
    'Детальная информация по банковским счетам: реквизиты счёта, договор, клиент и основная группа свойств счёта. Детальный слой (DDS).';
COMMENT ON COLUMN core.account_detail.account_property_group_id IS
    'Уникальный идентификатор основной группы свойств счёта. Источник: ext_ods.abs_account_property_group (ODS: core.abs_account_property_group), ссылка на core.account_property_group_detail(account_property_group_id)';
