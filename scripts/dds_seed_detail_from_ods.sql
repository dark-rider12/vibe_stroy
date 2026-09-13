-- DDS-слой (medallion: silver). Протягиваем 5 новых ODS-таблиц из ext_ods в детальные
-- таблицы dds.core.*_detail без сложных преобразований (простой перенос колонок).
-- Запускать в БД dds с ролью, имеющей маппинг на FDW-сервер ods_server.

-- ============================================================
-- 1. crm_client_manager -> core.manager_detail
--    Ключи: client_id -> crm_client; branch_cd -> отделение
-- ============================================================
DROP TABLE IF EXISTS core.manager_detail;
CREATE TABLE core.manager_detail AS
SELECT
    manager_id,
    client_id,
    manager_full_name,
    manager_role,
    branch_cd,
    assignment_date,
    source_system,
    load_dttm
FROM dds.ext_ods.crm_client_manager;

COMMENT ON TABLE core.manager_detail IS
    'Детальная информация о закреплении клиентов за банковскими менеджерами. Детальный слой (DDS).';
COMMENT ON COLUMN core.manager_detail.manager_id IS 'Уникальный идентификатор менеджера';
COMMENT ON COLUMN core.manager_detail.client_id IS 'Уникальный идентификатор клиента, закреплённого за менеджером';
COMMENT ON COLUMN core.manager_detail.manager_full_name IS 'Полное ФИО менеджера';
COMMENT ON COLUMN core.manager_detail.manager_role IS 'Роль менеджера (relationship_manager, premium_manager и т.д.)';
COMMENT ON COLUMN core.manager_detail.branch_cd IS 'Код отделения банка';
COMMENT ON COLUMN core.manager_detail.assignment_date IS 'Дата закрепления клиента за менеджером';
COMMENT ON COLUMN core.manager_detail.source_system IS 'Система-источник данных';
COMMENT ON COLUMN core.manager_detail.load_dttm IS 'Дата-время загрузки данных в хранилище';

-- ============================================================
-- 2. abs_account_balance_history -> core.account_balance_detail
--    Ключи: account_id -> abs_account
-- ============================================================
DROP TABLE IF EXISTS core.account_balance_detail;
CREATE TABLE core.account_balance_detail AS
SELECT
    balance_id,
    account_id,
    balance_date,
    balance_amt,
    available_amt,
    currency_cd,
    source_system,
    load_dttm
FROM dds.ext_ods.abs_account_balance_history;

COMMENT ON TABLE core.account_balance_detail IS
    'Детальная информация по истории остатков банковских счетов. Детальный слой (DDS).';
COMMENT ON COLUMN core.account_balance_detail.balance_id IS 'Уникальный идентификатор записи остатка';
COMMENT ON COLUMN core.account_balance_detail.account_id IS 'Уникальный идентификатор счёта, к которому относится остаток';
COMMENT ON COLUMN core.account_balance_detail.balance_date IS 'Дата, на которую зафиксирован остаток';
COMMENT ON COLUMN core.account_balance_detail.balance_amt IS 'Баланс средств на счёте на дату';
COMMENT ON COLUMN core.account_balance_detail.available_amt IS 'Доступная сумма (с учётом заморозок и лимитов)';
COMMENT ON COLUMN core.account_balance_detail.currency_cd IS 'Код валюты в формате ISO 4217';
COMMENT ON COLUMN core.account_balance_detail.source_system IS 'Система-источник данных';
COMMENT ON COLUMN core.account_balance_detail.load_dttm IS 'Дата-время загрузки данных в хранилище';

-- ============================================================
-- 3. abs_card_payment -> core.card_payment_detail
--    Ключи: card_id -> abs_card; account_id -> abs_account
-- ============================================================
DROP TABLE IF EXISTS core.card_payment_detail;
CREATE TABLE core.card_payment_detail AS
SELECT
    payment_id,
    card_id,
    account_id,
    payment_date,
    payment_amt,
    principal_amt,
    interest_amt,
    debt_amt,
    payment_type_cd,
    source_system,
    load_dttm
FROM dds.ext_ods.abs_card_payment;

COMMENT ON TABLE core.card_payment_detail IS
    'Детальная информация по платежам по банковским картам. Детальный слой (DDS).';
COMMENT ON COLUMN core.card_payment_detail.payment_id IS 'Уникальный идентификатор платежа по карте';
COMMENT ON COLUMN core.card_payment_detail.card_id IS 'Уникальный идентификатор карты';
COMMENT ON COLUMN core.card_payment_detail.account_id IS 'Уникальный идентификатор счёта карты';
COMMENT ON COLUMN core.card_payment_detail.payment_date IS 'Дата совершения платежа';
COMMENT ON COLUMN core.card_payment_detail.payment_amt IS 'Сумма платежа';
COMMENT ON COLUMN core.card_payment_detail.principal_amt IS 'Сумма, направленная на погашение основного долга';
COMMENT ON COLUMN core.card_payment_detail.interest_amt IS 'Сумма, направленная на погашение процентов';
COMMENT ON COLUMN core.card_payment_detail.debt_amt IS 'Остаток задолженности после платежа';
COMMENT ON COLUMN core.card_payment_detail.payment_type_cd IS 'Тип платежа (scheduled, early, final и т.д.)';
COMMENT ON COLUMN core.card_payment_detail.source_system IS 'Система-источник данных';
COMMENT ON COLUMN core.card_payment_detail.load_dttm IS 'Дата-время загрузки данных в хранилище';

-- ============================================================
-- 4. crm_client_contact_log -> core.client_contact_detail
--    Ключи: client_id -> crm_client; manager_id -> crm_client_manager
-- ============================================================
DROP TABLE IF EXISTS core.client_contact_detail;
CREATE TABLE core.client_contact_detail AS
SELECT
    contact_id,
    client_id,
    contact_ts,
    contact_type_cd,
    channel_cd,
    subject_txt,
    result_txt,
    manager_id,
    source_system,
    load_dttm
FROM dds.ext_ods.crm_client_contact_log;

COMMENT ON TABLE core.client_contact_detail IS
    'Детальная информация по журналу контактов (обращений) с клиентами. Детальный слой (DDS).';
COMMENT ON COLUMN core.client_contact_detail.contact_id IS 'Уникальный идентификатор контакта';
COMMENT ON COLUMN core.client_contact_detail.client_id IS 'Уникальный идентификатор клиента';
COMMENT ON COLUMN core.client_contact_detail.contact_ts IS 'Дата-время контакта';
COMMENT ON COLUMN core.client_contact_detail.contact_type_cd IS 'Тип контакта (звонок, письмо, визит и т.д.)';
COMMENT ON COLUMN core.client_contact_detail.channel_cd IS 'Канал контакта (phone, email, office, chat и т.д.)';
COMMENT ON COLUMN core.client_contact_detail.subject_txt IS 'Тема/суть обращения';
COMMENT ON COLUMN core.client_contact_detail.result_txt IS 'Результат контакта';
COMMENT ON COLUMN core.client_contact_detail.manager_id IS 'Уникальный идентификатор менеджера, ведущего контакт';
COMMENT ON COLUMN core.client_contact_detail.source_system IS 'Система-источник данных';
COMMENT ON COLUMN core.client_contact_detail.load_dttm IS 'Дата-время загрузки данных в хранилище';

-- ============================================================
-- 5. abs_collateral -> core.collateral_detail
--    Ключи: credit_id -> abs_corp_credit
-- ============================================================
DROP TABLE IF EXISTS core.collateral_detail;
CREATE TABLE core.collateral_detail AS
SELECT
    collateral_id,
    credit_id,
    collateral_type_cd,
    collateral_name_txt,
    collateral_value_amt,
    appraisal_date,
    insured_flg,
    source_system,
    load_dttm
FROM dds.ext_ods.abs_collateral;

COMMENT ON TABLE core.collateral_detail IS
    'Детальная информация по залоговому обеспечению корпоративных кредитов. Детальный слой (DDS).';
COMMENT ON COLUMN core.collateral_detail.collateral_id IS 'Уникальный идентификатор залога';
COMMENT ON COLUMN core.collateral_detail.credit_id IS 'Уникальный идентификатор кредитного договора, к которому относится залог';
COMMENT ON COLUMN core.collateral_detail.collateral_type_cd IS 'Тип залога (real_estate, equipment, vehicle и т.д.)';
COMMENT ON COLUMN core.collateral_detail.collateral_name_txt IS 'Наименование/описание предмета залога';
COMMENT ON COLUMN core.collateral_detail.collateral_value_amt IS 'Оценочная стоимость предмета залога';
COMMENT ON COLUMN core.collateral_detail.appraisal_date IS 'Дата оценки залога';
COMMENT ON COLUMN core.collateral_detail.insured_flg IS 'Признак наличия страховки предмета залога';
COMMENT ON COLUMN core.collateral_detail.source_system IS 'Система-источник данных';
COMMENT ON COLUMN core.collateral_detail.load_dttm IS 'Дата-время загрузки данных в хранилище';