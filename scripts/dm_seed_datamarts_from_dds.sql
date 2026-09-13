-- DM-слой (medallion: gold). Создание 5 новых витрин из новых DDS-таблиц (ext_dds)
-- с джойнами на существующие детальные/справочные таблицы.
-- Запускать в БД dm с ролью, имеющей маппинг на FDW-сервер dds_server.

-- ============================================================
-- 1. Мастер витрина по менеджерам: активность менеджеров по закреплённым клиентам
--    Источники: ext_dds.manager_detail (новая) + ext_dds.client_contact_detail (новая)
-- ============================================================
DROP TABLE IF EXISTS core.manager_activity_overview;
CREATE TABLE core.manager_activity_overview AS
SELECT
    m.manager_id,
    m.manager_full_name,
    m.manager_role,
    m.branch_cd,
    m.assignment_date,
    count(DISTINCT m.client_id) AS assigned_clients_cnt,
    count(c.contact_id) AS contacts_cnt,
    count(c.contact_id) FILTER (WHERE c.contact_ts >= current_date - INTERVAL '30 days') AS contacts_last_30_days_cnt,
    count(c.contact_id) FILTER (WHERE c.result_txt IS NOT NULL) AS contacts_with_result_cnt,
    min(c.contact_ts) AS first_contact_ts,
    max(c.contact_ts) AS last_contact_ts
FROM ext_dds.manager_detail m
LEFT JOIN ext_dds.client_contact_detail c
    ON c.client_id = m.client_id
GROUP BY
    m.manager_id,
    m.manager_full_name,
    m.manager_role,
    m.branch_cd,
    m.assignment_date;

COMMENT ON TABLE core.manager_activity_overview IS
    'Витрина активности менеджеров: сводка по закреплённым клиентам и контактам. Слой DataMart для оценки работы клиентских менеджеров и нагрузки по отделениям.';
COMMENT ON COLUMN core.manager_activity_overview.manager_id IS 'Уникальный идентификатор менеджера';
COMMENT ON COLUMN core.manager_activity_overview.manager_full_name IS 'Полное ФИО менеджера';
COMMENT ON COLUMN core.manager_activity_overview.manager_role IS 'Роль менеджера (relationship_manager, premium_manager и т.д.)';
COMMENT ON COLUMN core.manager_activity_overview.branch_cd IS 'Код отделения банка';
COMMENT ON COLUMN core.manager_activity_overview.assignment_date IS 'Дата первого закрепления клиента за менеджером';
COMMENT ON COLUMN core.manager_activity_overview.assigned_clients_cnt IS 'Количество закреплённых за менеджером клиентов';
COMMENT ON COLUMN core.manager_activity_overview.contacts_cnt IS 'Всего контактов по клиентам менеджера';
COMMENT ON COLUMN core.manager_activity_overview.contacts_last_30_days_cnt IS 'Контактов за последние 30 дней';
COMMENT ON COLUMN core.manager_activity_overview.contacts_with_result_cnt IS 'Контактов с зафиксированным результатом';
COMMENT ON COLUMN core.manager_activity_overview.first_contact_ts IS 'Дата-время первого зафиксированного контакта';
COMMENT ON COLUMN core.manager_activity_overview.last_contact_ts IS 'Дата-время последнего зафиксированного контакта';

-- ============================================================
-- 2. Витрина динамики и истории остатков по счетам
--    Источники: ext_dds.account_balance_detail (новая) + ext_dds.account_detail
-- ============================================================
DROP TABLE IF EXISTS core.account_balance_dynamics;
CREATE TABLE core.account_balance_dynamics AS
SELECT
    b.account_id,
    a.account_number,
    a.account_type,
    b.currency_cd,
    b.balance_date,
    b.balance_amt,
    b.available_amt,
    b.balance_amt - b.available_amt AS blocked_amt,
    lag(b.balance_amt) OVER (PARTITION BY b.account_id ORDER BY b.balance_date) AS prev_balance_amt,
    round(
        (b.balance_amt / NULLIF(lag(b.balance_amt) OVER (PARTITION BY b.account_id ORDER BY b.balance_date), 0) - 1) * 100,
        2
    ) AS balance_change_pct,
    a.client_id,
    a.client_full_name,
    a.client_status,
    a.contract_type,
    a.account_status,
    a.open_date AS account_open_date,
    a.close_date AS account_close_date,
    a.balance_amt AS current_balance_amt
FROM ext_dds.account_balance_detail b
JOIN ext_dds.account_detail a
    ON a.account_id = b.account_id;

COMMENT ON TABLE core.account_balance_dynamics IS
    'Витрина динамики остатков по счетам: история балансов с клиентской и договорной информацией, изменение остатка между датами. Слой DataMart для анализа ликвидности и time-series.';
COMMENT ON COLUMN core.account_balance_dynamics.account_id IS 'Уникальный идентификатор счёта';
COMMENT ON COLUMN core.account_balance_dynamics.account_number IS 'Номер банковского счёта';
COMMENT ON COLUMN core.account_balance_dynamics.account_type IS 'Тип счёта (депозитный, текущий, кредитный и т.д.)';
COMMENT ON COLUMN core.account_balance_dynamics.currency_cd IS 'Код валюты счёта в формате ISO 4217';
COMMENT ON COLUMN core.account_balance_dynamics.balance_date IS 'Дата, на которую зафиксирован остаток';
COMMENT ON COLUMN core.account_balance_dynamics.balance_amt IS 'Баланс средств на счёте на дату';
COMMENT ON COLUMN core.account_balance_dynamics.available_amt IS 'Доступная сумма (с учётом заморозок и лимитов)';
COMMENT ON COLUMN core.account_balance_dynamics.blocked_amt IS 'Заблокированная сумма (баланс минус доступно)';
COMMENT ON COLUMN core.account_balance_dynamics.prev_balance_amt IS 'Остаток на предыдущую дату среза по счёту';
COMMENT ON COLUMN core.account_balance_dynamics.balance_change_pct IS 'Изменение остатка к предыдущему срезу, в процентах';
COMMENT ON COLUMN core.account_balance_dynamics.client_id IS 'Уникальный идентификатор клиента-владельца счёта';
COMMENT ON COLUMN core.account_balance_dynamics.client_full_name IS 'Полное ФИО клиента';
COMMENT ON COLUMN core.account_balance_dynamics.client_status IS 'Статус клиента в CRM';
COMMENT ON COLUMN core.account_balance_dynamics.contract_type IS 'Тип договора, к которому относится счёт';
COMMENT ON COLUMN core.account_balance_dynamics.account_status IS 'Статус счёта (active, closed, blocked и т.д.)';
COMMENT ON COLUMN core.account_balance_dynamics.account_open_date IS 'Дата открытия счёта';
COMMENT ON COLUMN core.account_balance_dynamics.account_close_date IS 'Дата закрытия счёта (NULL, если счёт активен)';
COMMENT ON COLUMN core.account_balance_dynamics.current_balance_amt IS 'Текущий остаток по счёту в детальном слое';

-- ============================================================
-- 3. Витрина платежей по картам с карточной и счетной информацией
--    Источники: ext_dds.card_payment_detail (новая) + ext_dds.card_detail + ext_dds.account_detail
-- ============================================================
DROP TABLE IF EXISTS core.card_payment_performance;
CREATE TABLE core.card_payment_performance AS
SELECT
    p.card_id,
    cd.masked_card_number,
    cd.card_system,
    cd.card_status,
    cd.validity_status,
    cd.expiry_date,
    p.account_id,
    ad.account_number,
    ad.client_id,
    ad.client_full_name,
    p.payment_date,
    p.payment_amt,
    p.principal_amt,
    p.interest_amt,
    p.debt_amt,
    p.payment_type_cd,
    row_number() OVER (PARTITION BY p.card_id ORDER BY p.payment_date DESC) AS payment_seq
FROM ext_dds.card_payment_detail p
JOIN ext_dds.card_detail cd
    ON cd.card_id = p.card_id
JOIN ext_dds.account_detail ad
    ON ad.account_id = p.account_id;

COMMENT ON TABLE core.card_payment_performance IS
    'Витрина платежей по картам: каждый платёж карты с параметрами карты, счёта и клиента. Слой DataMart для анализа платёжной дисциплины и погашения задолженности.';
COMMENT ON COLUMN core.card_payment_performance.card_id IS 'Уникальный идентификатор карты';
COMMENT ON COLUMN core.card_payment_performance.masked_card_number IS 'Маскированный номер карты в формате 6******4';
COMMENT ON COLUMN core.card_payment_performance.card_system IS 'Платёжная система карты (Visa, Mastercard, МИР и т.д.)';
COMMENT ON COLUMN core.card_payment_performance.card_status IS 'Статус карты в учётной системе';
COMMENT ON COLUMN core.card_payment_performance.validity_status IS 'Вычисляемый статус валидности карты (expired, valid, invalid)';
COMMENT ON COLUMN core.card_payment_performance.expiry_date IS 'Дата окончания срока действия карты';
COMMENT ON COLUMN core.card_payment_performance.account_id IS 'Уникальный идентификатор счёта карты';
COMMENT ON COLUMN core.card_payment_performance.account_number IS 'Номер банковского счёта карты';
COMMENT ON COLUMN core.card_payment_performance.client_id IS 'Уникальный идентификатор клиента-держателя карты';
COMMENT ON COLUMN core.card_payment_performance.client_full_name IS 'Полное ФИО клиента';
COMMENT ON COLUMN core.card_payment_performance.payment_date IS 'Дата совершения платежа';
COMMENT ON COLUMN core.card_payment_performance.payment_amt IS 'Сумма платежа';
COMMENT ON COLUMN core.card_payment_performance.principal_amt IS 'Сумма в погашение основного долга';
COMMENT ON COLUMN core.card_payment_performance.interest_amt IS 'Сумма в погашение процентов';
COMMENT ON COLUMN core.card_payment_performance.debt_amt IS 'Остаток задолженности после платежа';
COMMENT ON COLUMN core.card_payment_performance.payment_type_cd IS 'Тип платежа (scheduled, early, final и т.д.)';
COMMENT ON COLUMN core.card_payment_performance.payment_seq IS 'Порядковый номер платежа карты от последнего (1 — самый свежий)';

-- ============================================================
-- 4. Витрина вовлечённости клиентов по контактам с профилем и менеджером
--    Источники: ext_dds.client_contact_detail (новая) + ext_dds.client_account_profile + ext_dds.manager_detail (новая)
-- ============================================================
DROP TABLE IF EXISTS core.client_contact_engagement;
CREATE TABLE core.client_contact_engagement AS
SELECT
    cc.client_id,
    p.client_full_name,
    p.client_status,
    p.client_city,
    m.manager_full_name,
    m.manager_role,
    count(cc.contact_id) AS total_contacts_cnt,
    count(cc.contact_id) FILTER (WHERE cc.contact_type_cd = 'incoming_call') AS incoming_calls_cnt,
    count(cc.contact_id) FILTER (WHERE cc.contact_type_cd = 'outgoing_call') AS outgoing_calls_cnt,
    count(DISTINCT cc.channel_cd) AS channels_cnt,
    min(cc.contact_ts) AS first_contact_ts,
    max(cc.contact_ts) AS last_contact_ts
FROM ext_dds.client_contact_detail cc
JOIN ext_dds.manager_detail m
    ON m.client_id = cc.client_id
LEFT JOIN LATERAL (
    SELECT
        client_full_name,
        client_status,
        client_city
    FROM ext_dds.client_account_profile
    WHERE client_id = cc.client_id
    LIMIT 1
) p ON TRUE
GROUP BY
    cc.client_id,
    p.client_full_name,
    p.client_status,
    p.client_city,
    m.manager_full_name,
    m.manager_role;

COMMENT ON TABLE core.client_contact_engagement IS
    'Витрина вовлечённости клиентов: агрегация контактов по клиенту с профилем и ведущим менеджером. Слой DataMart для анализа обслуживания и качества клиентского сервиса.';
COMMENT ON COLUMN core.client_contact_engagement.client_id IS 'Уникальный идентификатор клиента';
COMMENT ON COLUMN core.client_contact_engagement.client_full_name IS 'Полное ФИО клиента';
COMMENT ON COLUMN core.client_contact_engagement.client_status IS 'Статус клиента в CRM (active, inactive, blocked и т.д.)';
COMMENT ON COLUMN core.client_contact_engagement.client_city IS 'Город клиента по актуальному адресу';
COMMENT ON COLUMN core.client_contact_engagement.manager_full_name IS 'Полное ФИО менеджера клиента';
COMMENT ON COLUMN core.client_contact_engagement.manager_role IS 'Роль менеджера';
COMMENT ON COLUMN core.client_contact_engagement.total_contacts_cnt IS 'Всего контактов с клиентом';
COMMENT ON COLUMN core.client_contact_engagement.incoming_calls_cnt IS 'Количество входящих звонков от клиента';
COMMENT ON COLUMN core.client_contact_engagement.outgoing_calls_cnt IS 'Количество исходящих звонков клиенту';
COMMENT ON COLUMN core.client_contact_engagement.channels_cnt IS 'Количество использованных каналов контакта';
COMMENT ON COLUMN core.client_contact_engagement.first_contact_ts IS 'Дата-время первого контакта';
COMMENT ON COLUMN core.client_contact_engagement.last_contact_ts IS 'Дата-время последнего контакта';

-- ============================================================
-- 5. Витрина залогового обеспечения корпоративных кредитов (аналитика рисков)
--    Источник: ext_dds.collateral_detail (новая)
-- ============================================================
DROP TABLE IF EXISTS core.collateral_risk_analysis;
CREATE TABLE core.collateral_risk_analysis AS
SELECT
    collateral_type_cd,
    insured_flg,
    count(*) AS collateral_cnt,
    count(DISTINCT credit_id) AS credits_cnt,
    sum(collateral_value_amt) AS total_value_amt,
    round(avg(collateral_value_amt), 2) AS avg_value_amt,
    min(appraisal_date) AS first_appraisal_date,
    max(appraisal_date) AS last_appraisal_date
FROM ext_dds.collateral_detail
GROUP BY
    collateral_type_cd,
    insured_flg;

COMMENT ON TABLE core.collateral_risk_analysis IS
    'Витрина залогового обеспечения по корпоративным кредитам: агрегация залогов по типу и страховке. Слой DataMart для анализа обеспеченности кредитного портфеля.';
COMMENT ON COLUMN core.collateral_risk_analysis.collateral_type_cd IS 'Тип залога (real_estate, equipment, vehicle и т.д.)';
COMMENT ON COLUMN core.collateral_risk_analysis.insured_flg IS 'Признак наличия страховки предмета залога';
COMMENT ON COLUMN core.collateral_risk_analysis.collateral_cnt IS 'Количество залогов в группе';
COMMENT ON COLUMN core.collateral_risk_analysis.credits_cnt IS 'Количество кредитных договоров, обеспеченных залогами группы';
COMMENT ON COLUMN core.collateral_risk_analysis.total_value_amt IS 'Совокупная оценочная стоимость залогов';
COMMENT ON COLUMN core.collateral_risk_analysis.avg_value_amt IS 'Средняя оценочная стоимость залога в группе';
COMMENT ON COLUMN core.collateral_risk_analysis.first_appraisal_date IS 'Самая ранняя дата оценки залогов группы';
COMMENT ON COLUMN core.collateral_risk_analysis.last_appraisal_date IS 'Самая поздняя дата оценки залогов группы';