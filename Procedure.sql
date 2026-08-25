-- для заполнения справочника растений из файла
CREATE OR REPLACE PROCEDURE load_plants_from_csv(
    p_file_path TEXT,
    p_delimiter CHAR DEFAULT ';'
)
LANGUAGE plpgsql AS $$
DECLARE
    v_plant_record RECORD;
    v_inserted INT := 0;
    v_updated INT := 0;
    v_errors INT := 0;
BEGIN
    -- Временная таблица для сырых данных из CSV
    CREATE TEMP TABLE temp_plant_import (
        name VARCHAR(200),
        official_name TEXT,
        family VARCHAR(200),
        genus VARCHAR(100),
        description TEXT,
        conservation_status VARCHAR(50),
        endemic BOOLEAN
    );

    -- Загружаем данные из CSV-файла
    EXECUTE format('
        COPY temp_plant_import (
            name,
            official_name,
            family,
            genus,
            description,
            conservation_status,
            endemic
        )
        FROM %L
        DELIMITER %L
        CSV HEADER
    ', p_file_path, p_delimiter);

    -- Обрабатываем каждую строку
    FOR v_plant_record IN
        SELECT * FROM temp_plant_import
    LOOP
        BEGIN
            IF EXISTS (
                SELECT 1 FROM Plant_directory
                WHERE Name = v_plant_record.name
                   OR Official_name = v_plant_record.official_name
            ) THEN
                -- Обновление существующего растения
                UPDATE Plant_directory
                SET
                    Family = COALESCE(v_plant_record.family, Family),
                    Genus = COALESCE(v_plant_record.genus, Genus),
                    Description = COALESCE(v_plant_record.description, Description),
                    Conservation_status = COALESCE(
                        v_plant_record.conservation_status::conservation_status_enum,
                        Conservation_status
                    ),
                    Endemic = COALESCE(v_plant_record.endemic, Endemic)
                WHERE Name = v_plant_record.name
                   OR Official_name = v_plant_record.official_name;

                v_updated := v_updated + 1;
            ELSE
                -- Вставка нового растения
                INSERT INTO Plant_directory (
                    Name,
                    Official_name,
                    Family,
                    Genus,
                    Description,
                    Conservation_status,
                    Endemic
                ) VALUES (
                    v_plant_record.name,
                    v_plant_record.official_name,
                    v_plant_record.family,
                    v_plant_record.genus,
                    v_plant_record.description,
                    v_plant_record.conservation_status::conservation_status_enum,
                    v_plant_record.endemic
                );

                v_inserted := v_inserted + 1;
            END IF;

        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            RAISE NOTICE 'Ошибка %: %', v_plant_record.name, SQLERRM;
        END;
    END LOOP;

    -- Очистка
    DROP TABLE temp_plant_import;

END;
$$;


-- для заполнения справочника сотрудников
CREATE OR REPLACE PROCEDURE load_employees_from_csv(
    p_file_path TEXT,
    p_delimiter CHAR DEFAULT ';'
)
LANGUAGE plpgsql AS $$
DECLARE
    v_employee_record RECORD;
    v_inserted INT := 0;
    v_updated INT := 0;
    v_errors INT := 0;
BEGIN
    -- Временная таблица для импорта
    CREATE TEMP TABLE temp_employee_import (
        full_name TEXT,
        phone VARCHAR(20),
        position TEXT,
        specialization TEXT,
        email VARCHAR(150),
        salary NUMERIC(12,2),
        hire_date DATE,
        available BOOLEAN
    );

    -- Загружаем данные из CSV
    EXECUTE format('
        COPY temp_employee_import (
            full_name,
            phone,
            position,
            specialization,
            email,
            salary,
            hire_date,
            available
        )
        FROM %L
        DELIMITER %L
        CSV HEADER
    ', p_file_path, p_delimiter);

    -- Обрабатываем каждую строку
    FOR v_employee_record IN
        SELECT * FROM temp_employee_import
    LOOP
        BEGIN
            -- Проверяем, есть ли сотрудник с таким email
            IF EXISTS (
                SELECT 1 FROM Employees
                WHERE Email = v_employee_record.email
            ) THEN
                -- Обновление существующего сотрудника
                UPDATE Employees
                SET
                    Full_name = v_employee_record.full_name,
                    Phone = v_employee_record.phone,
                    Position = v_employee_record.position,
                    Specialization = v_employee_record.specialization,
                    Salary = v_employee_record.salary,
                    Hire_date = v_employee_record.hire_date,
                    Available = v_employee_record.available
                WHERE Email = v_employee_record.email;

                v_updated := v_updated + 1;
            ELSE
                -- Вставка нового сотрудника
                INSERT INTO Employees (
                    Full_name,
                    Phone,
                    Position,
                    Specialization,
                    Email,
                    Salary,
                    Hire_date,
                    Available
                ) VALUES (
                    v_employee_record.full_name,
                    v_employee_record.phone,
                    v_employee_record.position,
                    v_employee_record.specialization,
                    v_employee_record.email,
                    v_employee_record.salary,
                    v_employee_record.hire_date,
                    v_employee_record.available
                );

                v_inserted := v_inserted + 1;
            END IF;

        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            RAISE NOTICE 'Ошибка при обработке сотрудника "%": %',
                v_employee_record.full_name, SQLERRM;
        END;
    END LOOP;

    -- Очистка
    DROP TABLE temp_employee_import;

END;
$$;

-- для заполнения справочника покупателей

CREATE OR REPLACE PROCEDURE load_customers_from_csv(
    p_file_path TEXT,
    p_delimiter CHAR DEFAULT ';'
)
LANGUAGE plpgsql AS $$
DECLARE
    v_customer_record RECORD;
    v_inserted INT := 0;
    v_updated INT := 0;
    v_errors INT := 0;
    v_log_id BIGINT;
BEGIN
    -- Временная таблица для импорта
    CREATE TEMP TABLE temp_customer_import (
        email VARCHAR(150),
        phone VARCHAR(20),
        delivery_address TEXT,
        full_name TEXT,
        inn INT,
        discount NUMERIC(5,2),
        registration_date DATE,
        active BOOLEAN
    );

    -- Загружаем данные из CSV
    EXECUTE format('
        COPY temp_customer_import (
            email,
            phone,
            delivery_address,
            full_name,
            inn,
            discount,
            registration_date,
            active
        )
        FROM %L
        DELIMITER %L
        CSV HEADER
    ', p_file_path, p_delimiter);

    -- Обрабатываем каждую строку
    FOR v_customer_record IN
        SELECT * FROM temp_customer_import
    LOOP
        BEGIN
            -- Проверяем, есть ли клиент с таким email или ИНН
            IF EXISTS (
                SELECT 1 FROM Customers
                WHERE Email = v_customer_record.email
                   OR INN = v_customer_record.inn
            ) THEN
                -- Обновление существующего клиента
                UPDATE Customers
                SET
                    Phone = v_customer_record.phone,
                    Delivery_address = v_customer_record.delivery_address,
                    Full_name = v_customer_record.full_name,
                    INN = v_customer_record.inn,
                    Discount = v_customer_record.discount,
                    Registration_date = v_customer_record.registration_date,
                    Active = v_customer_record.active
                WHERE Email = v_customer_record.email
                   OR INN = v_customer_record.inn;

                v_updated := v_updated + 1;
            ELSE
                -- Вставка нового клиента
                INSERT INTO Customers (
                    Email,
                    Phone,
                    Delivery_address,
                    Full_name,
                    INN,
                    Discount,
                    Registration_date,
                    Active
                ) VALUES (
                    v_customer_record.email,
                    v_customer_record.phone,
                    v_customer_record.delivery_address,
                    v_customer_record.full_name,
                    v_customer_record.inn,
                    v_customer_record.discount,
                    v_customer_record.registration_date,
                    v_customer_record.active
                );

                v_inserted := v_inserted + 1;
            END IF;

        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            RAISE NOTICE 'Ошибка при обработке клиента "%": %',
                v_customer_record.full_name, SQLERRM;
        END;
    END LOOP;

    -- Очистка
    DROP TABLE temp_customer_import;
END;
$$;

-- внесений изменений в таблицу заказов
CREATE OR REPLACE PROCEDURE update_order(
    p_order_id BIGINT,
    p_status VARCHAR(100) DEFAULT NULL,
    p_delivery_id BIGINT DEFAULT NULL,
    p_delivery_address TEXT DEFAULT NULL,
    p_preferred_delivery_date TIMESTAMP DEFAULT NULL,
    p_assigned_employee_id BIGINT DEFAULT NULL,
    p_payment_completed BOOLEAN DEFAULT NULL,
    p_comment TEXT DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_old_status VARCHAR(100);
    v_old_delivery_id BIGINT;
    v_old_delivery_address TEXT;
    v_old_preferred_delivery_date TIMESTAMP;
    v_old_assigned_employee_id BIGINT;
    v_old_payment_completed BOOLEAN;
    v_old_comment TEXT;
    v_log_id BIGINT;
BEGIN
    -- Проверка: существует ли заказ
    IF NOT EXISTS (SELECT 1 FROM Orders WHERE Id = p_order_id) THEN
        RAISE EXCEPTION 'Заказ с ID % не найден', p_order_id;
    END IF;

    -- Проверка: если указан новый способ доставки, он должен существовать
    IF p_delivery_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM Delivery WHERE Id = p_delivery_id AND Available = TRUE) THEN
            RAISE EXCEPTION 'Способ доставки с ID % не найден или недоступен', p_delivery_id;
        END IF;
    END IF;

    -- Проверка: если указан новый сотрудник, он должен быть доступен
    IF p_assigned_employee_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM Employees WHERE Id = p_assigned_employee_id AND Available = TRUE) THEN
            RAISE EXCEPTION 'Сотрудник с ID % не найден или недоступен', p_assigned_employee_id;
        END IF;
    END IF;

    -- Получаем текущие данные заказа
    SELECT
        Status,
        Delivery_id,
        Delivery_address,
        Preferred_delivery_date,
        Assigned_employee_id,
        Payment_completed,
        Comment
    INTO
        v_old_status,
        v_old_delivery_id,
        v_old_delivery_address,
        v_old_preferred_delivery_date,
        v_old_assigned_employee_id,
        v_old_payment_completed,
        v_old_comment
    FROM Orders
    WHERE Id = p_order_id;


    -- Выполняем обновление заказа
    UPDATE Orders
    SET
        Status = COALESCE(p_status, Status),
        Delivery_id = COALESCE(p_delivery_id, Delivery_id),
        Delivery_address = COALESCE(p_delivery_address, Delivery_address),
        Preferred_delivery_date = COALESCE(p_preferred_delivery_date, Preferred_delivery_date),
        Assigned_employee_id = COALESCE(p_assigned_employee_id, Assigned_employee_id),
        Payment_completed = COALESCE(p_payment_completed, Payment_completed),
        Comment = COALESCE(p_comment, Comment)
    WHERE Id = p_order_id;

    -- Дополнительная бизнес-логика: если статус стал 'delivered', обновляем дату доставки
    IF p_status = 'delivered' THEN
        UPDATE Orders
        SET Delivery_days = EXTRACT(DAY FROM (NOW() - Order_date))::INT
        WHERE Id = p_order_id;
    END IF;
END;
$$;

-- Которая автоматически рассчитывает конечную стоимость в таблице Orders в зависимости от цены продуктов в заказе и стоимости доставки

CREATE OR REPLACE PROCEDURE proc_recalc_order_total(p_order_id BIGINT)
LANGUAGE plpgsql AS $$
DECLARE
    v_products_total NUMERIC(12,2);
    v_delivery_price NUMERIC(12,2);
BEGIN
    SELECT COALESCE(SUM(p.Price), 0)
    INTO v_products_total
    FROM Orders_Products op
    JOIN Products p ON op.Products_id = p.Id
    WHERE op.Orders_id = p_order_id;

    SELECT COALESCE(d.Price, 0)
    INTO v_delivery_price
    FROM Orders o
    LEFT JOIN Delivery d ON o.Delivery_id = d.Id
    WHERE o.Id = p_order_id;

    UPDATE Orders
    SET Final_amount = v_products_total + v_delivery_price
    WHERE Id = p_order_id;
END;
$$;