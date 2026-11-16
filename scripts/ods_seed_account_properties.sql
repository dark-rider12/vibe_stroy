-- Создание 2 новых таблиц ODS для групп свойств счетов и самих доп. свойств + тестовые данные.
-- Слой ods (core). Связь: abs_account(account_id) 1->N abs_account_property_group
--                                         abs_account_property_group(account_property_group_id) 1->N abs_account_property.
-- Запускать в БД ods ролью-владельцем схемы core (ai_reader не имеет прав на DDL).

-- ============================================================
-- 1. abs_account_property_group — группы свойств счёта
--    Логические ключи: account_id -> abs_account(account_id)
--    Группа объединяет доп. свойства счёта; связь с ними —
--    через abs_account_property.account_property_group_id (1:N).
-- ============================================================
DROP TABLE IF EXISTS core.abs_account_property_group;
CREATE TABLE core.abs_account_property_group (
    account_property_group_id bigint    NOT NULL,  -- PK группы свойств счёта
    account_id                bigint    NOT NULL,  -- счёт: core.abs_account(account_id)
    group_cd                  text      NOT NULL,  -- код группы: tariff_package, digital_service, deposit_params, card_params, risk_flags, rko_package
    group_name                text      NOT NULL,  -- наименование группы свойств
    group_desc_txt            text,                -- описание группы
    priority_num              smallint  NOT NULL DEFAULT 1, -- приоритет группы (1 = основная группа счёта)
    valid_from                date      NOT NULL,  -- дата начала действия группы свойств
    valid_to                  date,                -- дата окончания действия (NULL = бессрочно)
    source_system             text      NOT NULL DEFAULT 'core_bank',
    load_dttm                 timestamp NOT NULL DEFAULT now(),
    CONSTRAINT abs_account_property_group_pk PRIMARY KEY (account_property_group_id),
    CONSTRAINT abs_account_property_group_uk UNIQUE (account_id, group_cd, valid_from)
);
CREATE INDEX abs_account_property_group_account_ix
    ON core.abs_account_property_group (account_id);

INSERT INTO core.abs_account_property_group
    (account_property_group_id, account_id, group_cd, group_name, group_desc_txt, priority_num, valid_from, valid_to) VALUES
    (501, 10001, 'tariff_package',  'Тарифный пакет',            'Условия расчётно-кассового обслуживания счёта', 1, '2024-01-01', NULL),
    (502, 10001, 'digital_service', 'Цифровые сервисы',          'Подключённые сервисы дистанционного обслуживания', 2, '2024-02-15', NULL),
    (503, 10002, 'deposit_params',  'Параметры вклада',          'Условия по депозитному счёту', 1, '2024-03-01', NULL),
    (504, 10003, 'card_params',     'Параметры карты',           'Лимиты и льготный период по карточному счёту', 1, '2024-04-10', NULL),
    (505, 10004, 'rko_package',     'Пакет РКО',                 'Пакет расчётно-кассового обслуживания юр. лица', 1, '2024-05-20', NULL),
    (506, 10003, 'risk_flags',      'Риск-флаги',                'Признаки риск-мониторинга по счёту', 3, '2024-06-01', NULL);

-- ============================================================
-- 2. abs_account_property — доп. свойства счетов, объединённые в группы
--    Логические ключи: account_property_group_id -> abs_account_property_group
-- ============================================================
DROP TABLE IF EXISTS core.abs_account_property;
CREATE TABLE core.abs_account_property (
    account_property_id       bigint    NOT NULL,  -- PK доп. свойства
    account_property_group_id bigint    NOT NULL,  -- группа: core.abs_account_property_group
    property_cd               text      NOT NULL,  -- код свойства: service_fee, sms_notify, credit_limit ...
    property_name             text      NOT NULL,  -- наименование свойства
    property_value_txt        text,                -- значение в текстовом виде
    property_value_num        numeric(18,2),       -- значение в числовом виде
    value_type_cd             text      NOT NULL DEFAULT 'text', -- text, number, boolean, date
    unit_cd                   text,                -- единица измерения (RUB, %, days, ...)
    valid_from                date      NOT NULL,
    valid_to                  date,
    source_system             text      NOT NULL DEFAULT 'core_bank',
    load_dttm                 timestamp NOT NULL DEFAULT now(),
    CONSTRAINT abs_account_property_pk PRIMARY KEY (account_property_id),
    CONSTRAINT abs_account_property_uk UNIQUE (account_property_group_id, property_cd, valid_from)
);
CREATE INDEX abs_account_property_group_ix
    ON core.abs_account_property (account_property_group_id);

INSERT INTO core.abs_account_property
    (account_property_id, account_property_group_id, property_cd, property_name, property_value_txt, property_value_num, value_type_cd, unit_cd, valid_from, valid_to) VALUES
    (9001, 501, 'tariff_plan',      'Тарифный план',              'Optimal',       NULL,      'text',    NULL,  '2024-01-01', NULL),
    (9002, 501, 'service_fee',      'Абонентская плата',          NULL,            0.00,      'number',  'RUB', '2024-01-01', NULL),
    (9003, 501, 'salary_project',   'Зарплатный проект',          'true',          NULL,      'boolean', NULL,  '2024-02-01', NULL),
    (9004, 502, 'sms_notify',       'SMS-информирование',         'true',          NULL,      'boolean', NULL,  '2024-02-15', NULL),
    (9005, 502, 'payment_limit',    'Лимит платежей в сутки',     NULL,            500000.00, 'number',  'RUB', '2024-02-15', NULL),
    (9006, 503, 'capitalization',   'Капитализация процентов',    'monthly',       NULL,      'text',    NULL,  '2024-03-01', NULL),
    (9007, 503, 'replenishment',    'Пополнение вклада',          'allowed',       NULL,      'text',    NULL,  '2024-03-01', NULL),
    (9008, 504, 'credit_limit',     'Кредитный лимит',            NULL,            150000.00, 'number',  'RUB', '2024-04-10', NULL),
    (9009, 504, 'grace_period',     'Льготный период',            NULL,            50.00,     'number',  'days','2024-04-10', NULL),
    (9010, 505, 'rko_package_cd',   'Код пакета РКО',             'standard',      NULL,      'text',    NULL,  '2024-05-20', NULL),
    (9011, 505, 'cash_limit',       'Лимит снятия наличных',      NULL,            3000000.00,'number',  'RUB', '2024-05-20', NULL),
    (9012, 506, 'risk_level',       'Уровень риска счёта',        'low',           NULL,      'text',    NULL,  '2024-06-01', NULL),
    (9013, 506, 'monitoring_flg',   'Мониторинг операций',        'true',          NULL,      'boolean', NULL,  '2024-06-01', NULL);
