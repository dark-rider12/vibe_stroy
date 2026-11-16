-- DDS-view: счета + группы свойств счетов + доп. свойства.
-- Источники (все внутри dds): core.account_detail -> core.account_property_group_detail
--                              -> core.account_property_detail.
-- Одна строка = счёт + группа свойств + свойство; счета без групп и группы без
-- свойств тоже попадают в выборку (LEFT JOIN).
-- Запускать в БД dds. CREATE VIEW автоматически попадёт в public.sql_inventory.

CREATE OR REPLACE VIEW core.v_account_property_detail AS
SELECT
    a.account_id,
    a.account_number,
    a.account_type,
    a.account_status,
    a.currency_cd,
    a.balance_amt,
    a.open_date,
    a.contract_id,
    a.contract_number,
    a.client_id,
    a.client_full_name,
    a.client_status,
    a.account_property_group_id AS primary_account_property_group_id,
    g.account_property_group_id,
    g.group_cd,
    g.group_name,
    g.priority_num AS group_priority_num,
    g.valid_from AS group_valid_from,
    g.valid_to AS group_valid_to,
    p.account_property_id,
    p.property_cd,
    p.property_name,
    p.property_value_txt,
    p.property_value_num,
    p.value_type_cd,
    p.unit_cd,
    p.valid_from AS property_valid_from,
    p.valid_to AS property_valid_to
FROM core.account_detail a
LEFT JOIN core.account_property_group_detail g
    ON g.account_id = a.account_id
   AND g.valid_from <= current_date
   AND (g.valid_to IS NULL OR g.valid_to >= current_date)
LEFT JOIN core.account_property_detail p
    ON p.account_property_group_id = g.account_property_group_id
   AND p.valid_from <= current_date
   AND (p.valid_to IS NULL OR p.valid_to >= current_date);

COMMENT ON VIEW core.v_account_property_detail IS
    'Счета с группами свойств и доп. свойствами: одна строка — счёт + группа свойств + свойство. Слой DDS, аналитическое представление для разбора тарифов, лимитов и риск-флагов по счетам.';
COMMENT ON COLUMN core.v_account_property_detail.account_id IS 'Уникальный идентификатор счёта';
COMMENT ON COLUMN core.v_account_property_detail.account_number IS 'Номер счёта';
COMMENT ON COLUMN core.v_account_property_detail.primary_account_property_group_id IS 'Основная группа свойств счёта (account_detail.account_property_group_id)';
COMMENT ON COLUMN core.v_account_property_detail.account_property_group_id IS 'Уникальный идентификатор группы свойств счёта';
COMMENT ON COLUMN core.v_account_property_detail.group_cd IS 'Код группы свойств (tariff_package, digital_service и т.д.)';
COMMENT ON COLUMN core.v_account_property_detail.group_name IS 'Наименование группы свойств';
COMMENT ON COLUMN core.v_account_property_detail.account_property_id IS 'Уникальный идентификатор доп. свойства счёта';
COMMENT ON COLUMN core.v_account_property_detail.property_cd IS 'Код доп. свойства (service_fee, credit_limit и т.д.)';
COMMENT ON COLUMN core.v_account_property_detail.property_value_txt IS 'Значение свойства в текстовом виде';
COMMENT ON COLUMN core.v_account_property_detail.property_value_num IS 'Значение свойства в числовом виде';
COMMENT ON COLUMN core.v_account_property_detail.unit_cd IS 'Единица измерения значения свойства (RUB, %, days)';
