-- Функция: get_delivery_details_by_order, которая возвращает детали доставки по id заказа (возвращаемые значения: стоимость доставки, ответ-го сотрудника, завершение оплаты, детали логистики)
CREATE OR REPLACE FUNCTION get_delivery_details_by_order(p_order_id BIGINT)
RETURNS TABLE (
    order_id BIGINT,
    order_status VARCHAR(100),
    order_date TIMESTAMP,
    final_amount NUMERIC(12,2),
    payment_completed BOOLEAN,
    delivery_id BIGINT,
    delivery_name VARCHAR(200),
    delivery_price NUMERIC(12,2),
    delivery_contactless TEXT,
    delivery_address TEXT,
    preferred_delivery_date TIMESTAMP,
    delivery_days INT,
    employee_id BIGINT,
    employee_full_name TEXT,
    employee_phone VARCHAR(20),
    employee_position TEXT,
    logistics_id BIGINT,
    logistics_route_name VARCHAR(150),
    logistics_status TEXT,
    logistics_distance_km NUMERIC(10,2),
    logistics_start_point TEXT,
    logistics_end_point TEXT,
    logistics_route_geometry TEXT
) AS $$
BEGIN
    -- Проверка существования заказа
    IF NOT EXISTS (SELECT 1 FROM Orders WHERE Id = p_order_id) THEN
        RAISE EXCEPTION 'Заказ с ID % не найден', p_order_id;
    END IF;

    RETURN QUERY
    SELECT 
        o.Id AS order_id,
        o.Status AS order_status,
        o.Order_date,
        o.Final_amount,
        o.Payment_completed,
        d.Id AS delivery_id,
        d.Name AS delivery_name,
        d.Price AS delivery_price,
        d.Contactless AS delivery_contactless,
        o.Delivery_address,
        o.Preferred_delivery_date,
        o.Delivery_days,
        e.Id AS employee_id,
        e.Full_name AS employee_full_name,
        e.Phone AS employee_phone,
        e.Position AS employee_position,
        l.Id AS logistics_id,
        l.Route_name AS logistics_route_name,
        l.Status AS logistics_status,
        l.Distance_km AS logistics_distance_km,
        ST_AsText(l.Start_point) AS logistics_start_point,
        ST_AsText(l.End_point) AS logistics_end_point,
        ST_AsText(l.Route_geometry) AS logistics_route_geometry
    FROM Orders o
    LEFT JOIN Delivery d ON o.Delivery_id = d.Id
    LEFT JOIN Employees e ON o.Assigned_employee_id = e.Id
    LEFT JOIN Logistics l ON o.Id = l.Order_id
    WHERE o.Id = p_order_id;
END;
$$ LANGUAGE plpgsql;

-- Функция: get_company_budget, которая возвращает бюджет компании потраченный на зарплаты сотрудников и отдельно затраты на доставку
CREATE OR REPLACE FUNCTION get_company_budget(
    p_date_from DATE DEFAULT NULL,
    p_date_to DATE DEFAULT NULL
)
RETURNS TABLE (
    period_start DATE,
    period_end DATE,
    total_salary_cost NUMERIC(15,2),
    total_delivery_cost NUMERIC(15,2),
    total_budget NUMERIC(15,2),
    active_employees_count BIGINT,
    total_deliveries_count BIGINT,
    avg_salary_per_employee NUMERIC(12,2),
    avg_delivery_cost NUMERIC(12,2)
) AS $$
BEGIN
    RETURN QUERY
    WITH 
    -- 1. Затраты на зарплаты сотрудников за период
    salary_costs AS (
        SELECT 
            COALESCE(SUM(e.Salary), 0) AS total_salary,
            COUNT(DISTINCT e.Id) AS employee_count
        FROM Employees e
        WHERE e.Available = TRUE
          AND (p_date_from IS NULL OR e.Hire_date >= p_date_from)
          AND (p_date_to IS NULL OR e.Hire_date <= p_date_to)
    ),
    -- 2. Затраты на доставку за период
    delivery_costs AS (
        SELECT 
            COALESCE(SUM(d.Price), 0) AS total_delivery,
            COUNT(DISTINCT o.Id) AS delivery_count,
            COALESCE(AVG(d.Price), 0) AS avg_delivery
        FROM Orders o
        JOIN Delivery d ON o.Delivery_id = d.Id
        WHERE (p_date_from IS NULL OR o.Order_date >= p_date_from)
          AND (p_date_to IS NULL OR o.Order_date <= p_date_to)
          AND o.Payment_completed = TRUE
    )
    SELECT 
        COALESCE(p_date_from, '1970-01-01') AS period_start,
        COALESCE(p_date_to, CURRENT_DATE) AS period_end,
        sc.total_salary AS total_salary_cost,
        dc.total_delivery AS total_delivery_cost,
        sc.total_salary + dc.total_delivery AS total_budget,
        sc.employee_count AS active_employees_count,
        dc.delivery_count AS total_deliveries_count,
        CASE 
            WHEN sc.employee_count > 0 THEN sc.total_salary / sc.employee_count 
            ELSE 0 
        END AS avg_salary_per_employee,
        CASE 
            WHEN dc.delivery_count > 0 THEN dc.total_delivery / dc.delivery_count 
            ELSE 0 
        END AS avg_delivery_cost
    FROM salary_costs sc
    CROSS JOIN delivery_costs dc;
END;
$$ LANGUAGE plpgsql;

-- Функция: get_plant_detailed_report, которая возвращает полную информацию по растению из Plant_directory
CREATE OR REPLACE FUNCTION get_plant_detailed_report(p_plant_id BIGINT)
RETURNS TABLE (
    -- Основная информация
    pl_id BIGINT,
    pl_name VARCHAR(200),
    off_name TEXT,
    family VARCHAR(200),
    genus VARCHAR(100),
    description TEXT,
    endemic BOOLEAN,

    -- Характеристики (агрегированные в одну строку)
    characteristics_text TEXT,

    -- Уход (агрегированный в одну строку)
    care_text TEXT
) AS $$
BEGIN
    -- Проверка существования
    IF NOT EXISTS (SELECT 1 FROM Plant_directory WHERE Id = p_plant_id) THEN
        RAISE EXCEPTION 'Растение с ID % не найдено', p_plant_id;
    END IF;

    RETURN QUERY
    SELECT 
        pd.Id,
        pd.Name,
        COALESCE(pd.Official_name, 'не указано'),
        COALESCE(pd.Family, 'не указано'),
        COALESCE(pd.Genus, 'не указано'),
        COALESCE(pd.Description, 'нет описания'),
        pd.Endemic,

        -- Характеристики → одна строка
        COALESCE(
            (SELECT STRING_AGG(
                Characteristic_type || ': ' || COALESCE(Value, '') ||
                CASE WHEN Unit IS NOT NULL THEN ' (' || Unit || ')' ELSE '' END ||
                CASE WHEN Max_height_m IS NOT NULL THEN ', max высота: ' || Max_height_m::TEXT || ' м' ELSE '' END ||
                CASE WHEN Growth_rate IS NOT NULL THEN ', скорость роста: ' || Growth_rate::TEXT ELSE '' END,
                '; '
             )
             FROM Plant_characteristics
             WHERE Plant_id = pd.Id
            ),
            'характеристики не указаны'
        ) AS characteristics_text,

        -- Уход → одна строка
        COALESCE(
            (SELECT
                'освещение: ' || COALESCE(Light_requirements, 'не указано') ||
                ' | полив: ' || COALESCE(Watering_schedule, 'не указано') ||
                ' | удобрения: ' || COALESCE(Fertilizing, 'не указано') ||
                ' | температура: ' || COALESCE(Temperature_range, 'не указано') ||
                ' | влажность: ' || COALESCE(Humidity_requirements, 'не указано') ||
                ' | борьба с вредителями: ' || COALESCE(Pest_control, 'не указано') ||
                ' | особые указания: ' || COALESCE(Special_instructions, 'не указано')
             FROM Instructions_care
             WHERE Plant_id = pd.Id
             LIMIT 1
            ),
            'инструкции по уходу отсутствуют'
        ) AS care_text

    FROM Plant_directory pd
    WHERE pd.Id = p_plant_id;
END;
$$ LANGUAGE plpgsql;


-- Примеры
SELECT get_delivery_details_by_order(16);
SELECT * FROM get_company_budget('2024-01-01', '2024-12-31');
SELECT get_plant_detailed_report(34);