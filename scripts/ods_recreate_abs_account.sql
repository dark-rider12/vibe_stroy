-- ODS: пересоздание сырой таблицы core.abs_account с полем account_property_group_id,
-- чтобы dds.core.account_detail джойнился с группой свойств счёта
-- (core.abs_account_property_group) напрямую по этому полю.
-- Запускать в БД ods ролью-владельцем схемы core, после scripts/ods_seed_account_properties.sql.
-- ВНИМАНИЕ: таблица пересоздаётся (DROP), данные заливаются заново.

DROP TABLE IF EXISTS core.abs_account;
CREATE TABLE core.abs_account (
    account_id                bigint PRIMARY KEY,
    contract_id               bigint NOT NULL,
    account_number            text NOT NULL,
    account_type              text NOT NULL,
    currency_cd               text NOT NULL,
    open_date                 date NOT NULL,
    close_date                date,
    balance_amt               numeric(18,2),
    account_status            text,
    account_property_group_id bigint,  -- Основная группа свойств счёта: core.abs_account_property_group(account_property_group_id)
    source_system             text,
    load_dttm                 timestamp DEFAULT now()
);

COMMENT ON COLUMN core.abs_account.account_property_group_id IS
    'Уникальный идентификатор основной группы свойств счёта. Ссылка на core.abs_account_property_group(account_property_group_id)';

CREATE INDEX abs_account_property_group_ix
    ON core.abs_account (account_property_group_id);

INSERT INTO core.abs_account VALUES
(10001, 101, '40817810000000000001', 'current', 'RUB', '2024-01-10', null, 125000.50, 'active', 501, 'core_bank'),
(10002, 102, '42301810400000000002', 'deposit', 'RUB', '2024-02-15', null, 300000.00, 'active', 503, 'core_bank'),
(10003, 103, '40817810000000000003', 'card',    'RUB', '2024-03-01', null, 15000.75,  'active', 504, 'card_system'),
(10004, 104, '40702810900000000004', 'current', 'USD', '2024-03-20', null, 8200.00,   'active', 505, 'core_bank');
