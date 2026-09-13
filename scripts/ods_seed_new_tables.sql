-- Создание 5 новых банковских таблиц в слое ODS + заполнение тестовыми данными.
-- Слой ods: сырые данные из АБС/CRM/1С. Таблицы стыкуются с существующими по ключам.

-- ============================================================
-- 1. crm_client_manager — закрепление клиентов за менеджерами
--    JOIN: client_id -> crm_client(client_id); branch_cd -> abs_corp_credit(branch_cd)
-- ============================================================
DROP TABLE IF EXISTS core.crm_client_manager;
CREATE TABLE core.crm_client_manager (
    manager_id         bigint       NOT NULL,
    client_id          bigint       NOT NULL,
    manager_full_name  text         NOT NULL,
    manager_role       text         NOT NULL,
    branch_cd          text         NOT NULL,
    assignment_date    date         NOT NULL,
    source_system      text         NOT NULL DEFAULT 'crm',
    load_dttm          timestamp    NOT NULL DEFAULT now(),
    PRIMARY KEY (manager_id, client_id)
);

INSERT INTO core.crm_client_manager (manager_id, client_id, manager_full_name, manager_role, branch_cd, assignment_date) VALUES
    (901, 1, 'Иванова Ольга Петровна',   'relationship_manager', 'MSK001', '2024-01-15'),
    (901, 2, 'Иванова Ольга Петровна',   'relationship_manager', 'MSK001', '2024-02-20'),
    (902, 3, 'Соколов Дмитрий Андреевич','relationship_manager', 'SPB001', '2024-03-05'),
    (902, 4, 'Соколов Дмитрий Андреевич','relationship_manager', 'SPB001', '2024-04-10'),
    (903, 1, 'Козлова Мария Сергеевна',  'premium_manager',      'MSK002', '2024-06-01');

-- ============================================================
-- 2. abs_account_balance_history — история остатков по счетам
--    JOIN: account_id -> abs_account(account_id)
-- ============================================================
DROP TABLE IF EXISTS core.abs_account_balance_history;
CREATE TABLE core.abs_account_balance_history (
    balance_id     bigint    NOT NULL,
    account_id     bigint    NOT NULL,
    balance_date   date      NOT NULL,
    balance_amt    numeric(18,2) NOT NULL,
    available_amt  numeric(18,2) NOT NULL,
    currency_cd    text      NOT NULL,
    source_system  text      NOT NULL DEFAULT 'core_bank',
    load_dttm      timestamp NOT NULL DEFAULT now(),
    PRIMARY KEY (balance_id)
);

INSERT INTO core.abs_account_balance_history (balance_id, account_id, balance_date, balance_amt, available_amt, currency_cd) VALUES
    (1, 10001, '2024-06-30', 125000.50, 125000.50, 'RUB'),
    (2, 10001, '2024-07-31', 110000.00, 107500.00, 'RUB'),
    (3, 10002, '2024-06-30', 300000.00, 300000.00, 'RUB'),
    (4, 10004, '2024-07-31', 25000.75,  25000.75,  'RUB'),
    (5, 10003, '2024-07-31', 15000.75,  12000.00,  'RUB');

-- ============================================================
-- 3. abs_card_payment — платежи по картам (погашение, задолженность)
--    JOIN: card_id -> abs_card(card_id); account_id -> abs_account(account_id)
-- ============================================================
DROP TABLE IF EXISTS core.abs_card_payment;
CREATE TABLE core.abs_card_payment (
    payment_id        bigint NOT NULL,
    card_id           bigint NOT NULL,
    account_id        bigint NOT NULL,
    payment_date      date   NOT NULL,
    payment_amt       numeric(18,2) NOT NULL,
    principal_amt     numeric(18,2) NOT NULL,
    interest_amt      numeric(18,2) NOT NULL,
    debt_amt          numeric(18,2) NOT NULL,
    payment_type_cd   text   NOT NULL,
    source_system     text   NOT NULL DEFAULT 'card_system',
    load_dttm         timestamp NOT NULL DEFAULT now(),
    PRIMARY KEY (payment_id)
);

INSERT INTO core.abs_card_payment (payment_id, card_id, account_id, payment_date, payment_amt, principal_amt, interest_amt, debt_amt, payment_type_cd) VALUES
    (6001, 701, 10001, '2024-06-01', 5000.00,  3000.00,  2000.00,  25000.00,  'scheduled'),
    (6002, 701, 10001, '2024-07-01', 5000.00,  3000.00,  2000.00,  20000.00,  'scheduled'),
    (6003, 702, 10003, '2024-06-10', 10000.00, 8000.00,  2000.00,  40000.00,  'early'),
    (6004, 702, 10003, '2024-07-10', 10000.00, 8000.00,  2000.00,  32000.00,  'scheduled'),
    (6005, 703, 10003, '2024-07-15', 3000.00,  2000.00,  1000.00,  0.00,      'final');

-- ============================================================
-- 4. crm_client_contact_log — журнал обращений/контактов с клиентами
--    JOIN: client_id -> crm_client(client_id); manager_id -> crm_client_manager(manager_id)
-- ============================================================
DROP TABLE IF EXISTS core.crm_client_contact_log;
CREATE TABLE core.crm_client_contact_log (
    contact_id      bigint      NOT NULL,
    client_id       bigint      NOT NULL,
    contact_ts      timestamp   NOT NULL,
    contact_type_cd text        NOT NULL,
    channel_cd      text        NOT NULL,
    subject_txt     text        NOT NULL,
    result_txt      text,
    manager_id      bigint      NOT NULL,
    source_system   text        NOT NULL DEFAULT 'crm',
    load_dttm       timestamp   NOT NULL DEFAULT now(),
    PRIMARY KEY (contact_id)
);

INSERT INTO core.crm_client_contact_log (contact_id, client_id, contact_ts, contact_type_cd, channel_cd, subject_txt, result_txt, manager_id) VALUES
    (8001, 1, '2024-06-10 11:30:00', 'incoming_call', 'phone', 'Запрос по депозитной ставке', 'Проконсультирован', 901),
    (8002, 2, '2024-06-12 15:00:00', 'outgoing_call', 'phone', 'Предложение кредитной карты', 'Согласована встреча', 901),
    (8003, 3, '2024-06-15 09:20:00', 'email',          'email', 'Уведомление о льготном периоде','Отправлено', 902),
    (8004, 4, '2024-06-18 14:45:00', 'branch_visit',   'office','Открытие расчетного счета',   'Договор подписан', 902),
    (8005, 1, '2024-07-02 10:00:00', 'messenger',      'chat',  'Смена номера телефона',       'Данные обновлены', 903);

-- ============================================================
-- 5. abs_collateral — залоговое обеспечение по корпоративным кредитам
--    JOIN: credit_id -> abs_corp_credit(credit_id); branch_cd -> abs_corp_credit(branch_cd)
-- ============================================================
DROP TABLE IF EXISTS core.abs_collateral;
CREATE TABLE core.abs_collateral (
    collateral_id        bigint NOT NULL,
    credit_id            bigint NOT NULL,
    collateral_type_cd   text   NOT NULL,
    collateral_name_txt  text   NOT NULL,
    collateral_value_amt numeric(18,2) NOT NULL,
    appraisal_date       date   NOT NULL,
    insured_flg          boolean NOT NULL DEFAULT false,
    source_system        text   NOT NULL DEFAULT 'core_bank',
    load_dttm            timestamp NOT NULL DEFAULT now(),
    PRIMARY KEY (collateral_id)
);

INSERT INTO core.abs_collateral (collateral_id, credit_id, collateral_type_cd, collateral_name_txt, collateral_value_amt, appraisal_date, insured_flg) VALUES
    (7001, 1, 'real_estate', 'Офисное здание, Москва',         5000000.00, '2024-01-20', true),
    (7002, 2, 'equipment',   'Промышленное оборудование',      3000000.00, '2024-02-15', false),
    (7003, 3, 'vehicle',     'Грузовой автопарк (10 ед.)',     2500000.00, '2024-03-10', true),
    (7004, 4, 'real_estate', 'Производственный цех, МО',       8000000.00, '2024-04-05', true),
    (7005, 5, 'equipment',   'Лизинговая техника под залог',   1500000.00, '2023-12-01', false);