-- DM-слой (medallion: gold). Master-витрина с большим количеством джойнов (18):
-- объединяет ключевые детальные, внешние и существующие витрины dm в одну широкую.
-- Запускать в БД dm после создания витрин из dm_seed_datamarts_from_dds.sql.
-- Роль должна иметь маппинг на FDW-сервер dds_server.

DROP TABLE IF EXISTS core.master_wide_join;
CREATE TABLE core.master_wide_join AS
SELECT
    -- базовая детальная информация по счёту
    ad.account_id,
    ad.account_number,
    ad.account_type,
    ad.currency_cd,
    ad.open_date,
    ad.close_date,
    ad.balance_amt AS current_balance_amt,
    ad.account_status,
    ad.contract_id,
    ad.contract_type,
    ad.interest_rate,
    ad.contract_status,
    ad.client_id,
    ad.client_full_name,
    ad.client_status,

    -- транзакции по счёту
    td.transaction_id,
    td.transaction_date,
    td.transaction_ts,
    td.transaction_type,
    td.amount_amt,
    td.channel_cd AS trx_channel_cd,
    td.transaction_status,
    td.operation_category,

    -- карта счёта
    cd.card_id,
    cd.masked_card_number,
    cd.card_system,
    cd.validity_status,
    cd.expiry_date,

    -- платежи по карте
    cpd.payment_id,
    cpd.payment_date,
    cpd.payment_amt,
    cpd.debt_amt,

    -- история остатков
    abd.balance_date,
    abd.balance_amt AS history_balance_amt,
    abd.available_amt,

    -- клиентский профиль
    cap.active_passport,
    cap.client_city,
    cap.address_type,

    -- менеджер и контакты
    mgr.manager_id,
    mgr.manager_full_name,
    mgr.manager_role,
    mgr.branch_cd,
    ccd.contact_id,
    ccd.contact_ts,
    ccd.contact_type_cd,
    ccd.subject_txt,

    -- индивидуальный и корпоративный профиль
    ind.full_name AS individual_full_name,
    ind.marital_status_cd,
    ind.monthly_income_amt,
    ind.income_level_cd,
    corp.inn AS corp_inn,
    corp.company_name,
    corp.industry_cd,
    corp.company_size_cd,

    -- лизинг (через ИНН корпоративного клиента)
    ld.leasing_id,
    ld.contract_number AS leasing_contract_number,
    ld.object_type_cd,
    ld.object_cost_amt,
    ld.contract_status_cd AS leasing_status,

    -- мастер-партия (связанные данные счёт/клиент/карта)
    map.party_type,
    map.total_trx_count AS map_trx_count,
    map.total_debit_amt AS map_debit_amt,
    map.total_credit_amt AS map_credit_amt,
    map2.total_trx_count AS map2_trx_count,

    -- карта+договор (ext_calc)
    acc.card_id AS acc_card_id,
    acc.card_system AS acc_card_system,
    acc.issue_date AS acc_card_issue_date,

    -- риск-аналитика по карте (dm.core)
    cra.risk_level,
    cra.trx_count_30d,
    cra.used_channels AS cra_channels,

    -- поведение клиента (dm.core)
    cbs.total_trx_count AS cbs_trx_count,
    cbs.total_credit_amt AS cbs_credit_amt,
    cbs.total_debit_amt AS cbs_debit_amt,
    cbs.last_transaction_date AS cbs_last_trx_date,

    -- ежедневные срезы по счёту (dm.core)
    das.report_date::date AS snapshot_report_date,
    das.is_active_on_date,
    das.date_type AS snapshot_date_type,

    -- сводка счёт+карта (dm.core)
    aco.account_tier,
    aco.product_bundle,
    aco.current_balance AS aco_current_balance,
    aco.days_to_expiry,

    -- дубль account_detail (для проверки связи витрин)
    v.account_age_days AS v_account_age_days

FROM ext_dds.account_detail ad
LEFT JOIN ext_dds.transaction_detail td        ON td.account_id = ad.account_id
LEFT JOIN ext_dds.card_detail cd               ON cd.account_id = ad.account_id
LEFT JOIN ext_dds.card_payment_detail cpd      ON cpd.card_id = cd.card_id
LEFT JOIN ext_dds.account_balance_detail abd   ON abd.account_id = ad.account_id
LEFT JOIN ext_dds.client_account_profile cap   ON cap.account_id = ad.account_id
LEFT JOIN ext_dds.manager_detail mgr           ON mgr.client_id = ad.client_id
LEFT JOIN ext_dds.client_contact_detail ccd    ON ccd.client_id = ad.client_id
LEFT JOIN ext_dds.individual_client_detail ind ON ind.client_id = ad.client_id::int
LEFT JOIN ext_dds.corporate_client_detail corp ON corp.client_id = ad.client_id::int
LEFT JOIN ext_dds.leasing_detail ld            ON ld.lessee_inn = corp.inn
LEFT JOIN ext_dds.master_account_party map     ON map.account_id = ad.account_id
LEFT JOIN ext_dds.master_account_party_2 map2  ON map2.account_id = ad.account_id
LEFT JOIN ext_calc.account_card_contract acc   ON acc.account_id = ad.account_id
LEFT JOIN core.card_risk_analysis cra          ON cra.card_id = cd.card_id
LEFT JOIN core.client_behavior_summary cbs     ON cbs.client_id = ad.client_id
LEFT JOIN core.daily_account_snapshot das      ON das.account_id = ad.account_id
LEFT JOIN core.account_card_overview aco       ON aco.account_id = ad.account_id AND aco.card_id = cd.card_id
LEFT JOIN ext_dds.v_test_account_detail v      ON v.account_id = ad.account_id;

COMMENT ON TABLE core.master_wide_join IS
    'Master-витрина с большим числом джойнов (18): счёт, транзакции, карты, платежи по картам, остатки, профиль клиента, менеджеры, контакты, индивидуальный/корпоративный профиль, лизинг, мастер-партии, карта+договор, риск-аналитика по картам, поведение клиента, ежедневные срезы и сводка счёт+карта. Слой DataMart для комплексного анализа клиента и счёта.';
COMMENT ON COLUMN core.master_wide_join.account_id IS 'Уникальный идентификатор счёта';
COMMENT ON COLUMN core.master_wide_join.account_number IS 'Номер банковского счёта';
COMMENT ON COLUMN core.master_wide_join.account_type IS 'Тип счёта (депозитный, текущий, кредитный и т.д.)';
COMMENT ON COLUMN core.master_wide_join.currency_cd IS 'Код валюты счёта в формате ISO 4217';
COMMENT ON COLUMN core.master_wide_join.open_date IS 'Дата открытия счёта';
COMMENT ON COLUMN core.master_wide_join.close_date IS 'Дата закрытия счёта (NULL, если счёт активен)';
COMMENT ON COLUMN core.master_wide_join.current_balance_amt IS 'Текущий остаток средств на счёте';
COMMENT ON COLUMN core.master_wide_join.account_status IS 'Статус счёта (active, closed, blocked и т.д.)';
COMMENT ON COLUMN core.master_wide_join.contract_id IS 'Идентификатор договора счёта';
COMMENT ON COLUMN core.master_wide_join.contract_type IS 'Тип договора';
COMMENT ON COLUMN core.master_wide_join.interest_rate IS 'Процентная ставка по договору (годовых)';
COMMENT ON COLUMN core.master_wide_join.contract_status IS 'Статус договора';
COMMENT ON COLUMN core.master_wide_join.client_id IS 'Уникальный идентификатор клиента-владельца счёта';
COMMENT ON COLUMN core.master_wide_join.client_full_name IS 'Полное ФИО клиента';
COMMENT ON COLUMN core.master_wide_join.client_status IS 'Статус клиента в CRM';
COMMENT ON COLUMN core.master_wide_join.transaction_id IS 'Уникальный идентификатор транзакции';
COMMENT ON COLUMN core.master_wide_join.transaction_date IS 'Дата транзакции';
COMMENT ON COLUMN core.master_wide_join.transaction_ts IS 'Дата-время транзакции';
COMMENT ON COLUMN core.master_wide_join.transaction_type IS 'Тип транзакции (credit, debit)';
COMMENT ON COLUMN core.master_wide_join.amount_amt IS 'Сумма транзакции';
COMMENT ON COLUMN core.master_wide_join.trx_channel_cd IS 'Канал совершения транзакции';
COMMENT ON COLUMN core.master_wide_join.transaction_status IS 'Статус транзакции';
COMMENT ON COLUMN core.master_wide_join.operation_category IS 'Категория операции';
COMMENT ON COLUMN core.master_wide_join.card_id IS 'Уникальный идентификатор карты';
COMMENT ON COLUMN core.master_wide_join.masked_card_number IS 'Маскированный номер карты 6******4';
COMMENT ON COLUMN core.master_wide_join.card_system IS 'Платёжная система карты';
COMMENT ON COLUMN core.master_wide_join.validity_status IS 'Статус валидности карты (expired, valid, invalid)';
COMMENT ON COLUMN core.master_wide_join.expiry_date IS 'Дата окончания действия карты';
COMMENT ON COLUMN core.master_wide_join.payment_id IS 'Идентификатор платежа по карте';
COMMENT ON COLUMN core.master_wide_join.payment_date IS 'Дата платежа по карте';
COMMENT ON COLUMN core.master_wide_join.payment_amt IS 'Сумма платежа по карте';
COMMENT ON COLUMN core.master_wide_join.debt_amt IS 'Остаток задолженности после платежа';
COMMENT ON COLUMN core.master_wide_join.balance_date IS 'Дата среза остатков';
COMMENT ON COLUMN core.master_wide_join.history_balance_amt IS 'Баланс на дату среза';
COMMENT ON COLUMN core.master_wide_join.available_amt IS 'Доступная сумма на дату среза';
COMMENT ON COLUMN core.master_wide_join.active_passport IS 'Активный паспорт клиента';
COMMENT ON COLUMN core.master_wide_join.client_city IS 'Город клиента';
COMMENT ON COLUMN core.master_wide_join.address_type IS 'Тип адреса клиента';
COMMENT ON COLUMN core.master_wide_join.manager_id IS 'Идентификатор менеджера клиента';
COMMENT ON COLUMN core.master_wide_join.manager_full_name IS 'Полное ФИО менеджера';
COMMENT ON COLUMN core.master_wide_join.manager_role IS 'Роль менеджера';
COMMENT ON COLUMN core.master_wide_join.branch_cd IS 'Код отделения банка';
COMMENT ON COLUMN core.master_wide_join.contact_id IS 'Идентификатор контакта с клиентом';
COMMENT ON COLUMN core.master_wide_join.contact_ts IS 'Дата-время контакта';
COMMENT ON COLUMN core.master_wide_join.contact_type_cd IS 'Тип контакта';
COMMENT ON COLUMN core.master_wide_join.subject_txt IS 'Тема/суть контакта';
COMMENT ON COLUMN core.master_wide_join.individual_full_name IS 'ФИО из индивидуального профиля';
COMMENT ON COLUMN core.master_wide_join.marital_status_cd IS 'Семейное положение';
COMMENT ON COLUMN core.master_wide_join.monthly_income_amt IS 'Ежемесячный доход клиента';
COMMENT ON COLUMN core.master_wide_join.income_level_cd IS 'Уровень дохода';
COMMENT ON COLUMN core.master_wide_join.corp_inn IS 'ИНН корпоративного клиента';
COMMENT ON COLUMN core.master_wide_join.company_name IS 'Наименование компании';
COMMENT ON COLUMN core.master_wide_join.industry_cd IS 'Отрасль компании';
COMMENT ON COLUMN core.master_wide_join.company_size_cd IS 'Размер компании';
COMMENT ON COLUMN core.master_wide_join.leasing_id IS 'Идентификатор лизингового договора';
COMMENT ON COLUMN core.master_wide_join.leasing_contract_number IS 'Номер лизингового договора';
COMMENT ON COLUMN core.master_wide_join.object_type_cd IS 'Тип предмета лизинга';
COMMENT ON COLUMN core.master_wide_join.object_cost_amt IS 'Стоимость предмета лизинга';
COMMENT ON COLUMN core.master_wide_join.leasing_status IS 'Статус лизингового договора';
COMMENT ON COLUMN core.master_wide_join.party_type IS 'Тип партии в мастер-документе';
COMMENT ON COLUMN core.master_wide_join.map_trx_count IS 'Число транзакций (мастер-партия)';
COMMENT ON COLUMN core.master_wide_join.map_debit_amt IS 'Обороты по дебету (мастер-партия)';
COMMENT ON COLUMN core.master_wide_join.map_credit_amt IS 'Обороты по кредиту (мастер-партия)';
COMMENT ON COLUMN core.master_wide_join.map2_trx_count IS 'Число транзакций (мастер-партия-2)';
COMMENT ON COLUMN core.master_wide_join.acc_card_id IS 'Идентификатор карты из витрины карта+договор';
COMMENT ON COLUMN core.master_wide_join.acc_card_system IS 'Платёжная система карты (карта+договор)';
COMMENT ON COLUMN core.master_wide_join.acc_card_issue_date IS 'Дата выпуска карты (карта+договор)';
COMMENT ON COLUMN core.master_wide_join.risk_level IS 'Уровень риска по карте';
COMMENT ON COLUMN core.master_wide_join.trx_count_30d IS 'Число транзакций за 30 дней';
COMMENT ON COLUMN core.master_wide_join.cra_channels IS 'Используемые каналы (риск-аналитика)';
COMMENT ON COLUMN core.master_wide_join.cbs_trx_count IS 'Всего транзакций клиента (поведение)';
COMMENT ON COLUMN core.master_wide_join.cbs_credit_amt IS 'Сумма поступлений клиента (поведение)';
COMMENT ON COLUMN core.master_wide_join.cbs_debit_amt IS 'Сумма списаний клиента (поведение)';
COMMENT ON COLUMN core.master_wide_join.cbs_last_trx_date IS 'Дата последней транзакции клиента (поведение)';
COMMENT ON COLUMN core.master_wide_join.snapshot_report_date IS 'Дата отчёта ежедневного среза';
COMMENT ON COLUMN core.master_wide_join.is_active_on_date IS 'Признак активности счёта на дату среза';
COMMENT ON COLUMN core.master_wide_join.snapshot_date_type IS 'Тип даты среза (календарный день)';
COMMENT ON COLUMN core.master_wide_join.account_tier IS 'Тир счёта (сводка счёт+карта)';
COMMENT ON COLUMN core.master_wide_join.product_bundle IS 'Продуктовый пакет счёта';
COMMENT ON COLUMN core.master_wide_join.aco_current_balance IS 'Текущий баланс счёта (сводка счёт+карта)';
COMMENT ON COLUMN core.master_wide_join.days_to_expiry IS 'Дней до истечения карты';
COMMENT ON COLUMN core.master_wide_join.v_account_age_days IS 'Возраст счёта в днях (из дубля account_detail)';