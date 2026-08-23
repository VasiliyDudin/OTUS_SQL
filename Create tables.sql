-- ============================================
-- 1. Создание ENUM-типов
-- ============================================

CREATE TYPE conservation_status_enum AS ENUM ('LC', 'VU', 'EN', 'CR', 'EW', 'EX'); --Статус защиты (природоохранный)
CREATE TYPE growth_rate_enum AS ENUM ('slow', 'moderate', 'fast'); --Скорость роста
CREATE TYPE seasonal_availability_enum AS ENUM ('spring', 'summer', 'autumn', 'winter', 'year_round'); --Сезонность

-- ============================================
-- 2. Справочные таблицы (без внешних ключей)
-- ============================================

-- ---------------------------------------------------------------------
-- Таблица: Attraction (Достопримечательности/Локации)
-- ---------------------------------------------------------------------
CREATE TABLE Attraction (
    Id BIGSERIAL PRIMARY KEY,
    Name VARCHAR(200) NOT NULL,
    Description TEXT,
    Coordinates GEOMETRY(POLYGON, 4326),
    Center_point GEOGRAPHY(POINT, 4326),
    Cultural_significance TEXT,
    Protected_area BOOLEAN DEFAULT FALSE
);

COMMENT ON TABLE Attraction IS 'Уникальные географические локации (Амазонка, Мадагаскар)';
COMMENT ON COLUMN Attraction.Coordinates IS 'Полигон области на карте (PostGIS)';
COMMENT ON COLUMN Attraction.Center_point IS 'Центральная точка локации';

-- ---------------------------------------------------------------------
-- Таблица: Employees (Сотрудники)
-- ---------------------------------------------------------------------
CREATE TABLE Employees (
    Id BIGSERIAL PRIMARY KEY,
    Full_name TEXT NOT NULL,
    Phone VARCHAR(20),
    Position TEXT,
    Specialization TEXT,
    Email VARCHAR(150) UNIQUE,
    Salary NUMERIC(12,2) CHECK (Salary >= 0),
    Hire_date TIMESTAMP DEFAULT NOW(),
    Available BOOLEAN DEFAULT TRUE
);

COMMENT ON TABLE Employees IS 'Сотрудники компании (курьеры, ботаники, менеджеры)';

-- ---------------------------------------------------------------------
-- Таблица: Delivery (Способы доставки)
-- ---------------------------------------------------------------------
CREATE TABLE Delivery (
    Id BIGSERIAL PRIMARY KEY,
    Name VARCHAR(200) NOT NULL,
    Description TEXT,
    Price NUMERIC(12,2) CHECK (Price >= 0),
    Contactless TEXT,
    Available BOOLEAN DEFAULT TRUE
);

COMMENT ON TABLE Delivery IS 'Доступные способы доставки';

-- ---------------------------------------------------------------------
-- Таблица: Customers (Клиенты)
-- ---------------------------------------------------------------------
CREATE TABLE Customers (
    Id BIGSERIAL PRIMARY KEY,
    Email VARCHAR(150) UNIQUE NOT NULL,
    Phone VARCHAR(20) NOT NULL,
    Delivery_address TEXT,
    Full_name TEXT NOT NULL,
    INN INT UNIQUE,
    Discount NUMERIC(5,2) DEFAULT 0 CHECK (Discount >= 0 AND Discount <= 100),
    Registration_date TIMESTAMP DEFAULT NOW(),
    Active BOOLEAN DEFAULT TRUE
);

COMMENT ON TABLE Customers IS 'Клиенты (физические и юридические лица)';

-- ---------------------------------------------------------------------
-- Таблица: Plant_directory (Справочник растений)
-- ---------------------------------------------------------------------
CREATE TABLE Plant_directory (
    Id BIGSERIAL PRIMARY KEY,
    Name VARCHAR(200) NOT NULL,
    Official_name TEXT,
    Family VARCHAR(200),
    Genus VARCHAR(100),
    Description TEXT,
    Origin_location_id BIGINT,
    Conservation_status conservation_status_enum,
    Endemic BOOLEAN DEFAULT FALSE
);

COMMENT ON TABLE Plant_directory IS 'Ботанический справочник видов растений';
COMMENT ON COLUMN Plant_directory.Origin_location_id IS 'Ссылка на Location_address (место происхождения)';

-- ---------------------------------------------------------------------
-- Таблица: Location_address (Адреса локаций)
-- ---------------------------------------------------------------------
CREATE TABLE Location_address (
    Id BIGSERIAL PRIMARY KEY,
    Attraction_id BIGINT NOT NULL,
    Postal_code VARCHAR(20),
    Country VARCHAR(100),
    Region VARCHAR(100),
    Address TEXT,
    Point GEOGRAPHY(POINT, 4326)
);

COMMENT ON TABLE Location_address IS 'Детальные адреса локаций с географическими координатами';

-- ============================================
-- 3. Добавление внешних ключей
-- ============================================

ALTER TABLE Location_address
    ADD CONSTRAINT fk_location_address_attraction
    FOREIGN KEY (Attraction_id) REFERENCES Attraction(Id) ON DELETE RESTRICT;

ALTER TABLE Plant_directory
    ADD CONSTRAINT fk_plant_directory_origin_location
    FOREIGN KEY (Origin_location_id) REFERENCES Location_address(Id) ON DELETE SET NULL;

-- ============================================
-- 4. Таблицы, зависящие от Plant_directory
-- ============================================

-- ---------------------------------------------------------------------
-- Таблица: Plant_characteristics (Характеристики растений)
-- ---------------------------------------------------------------------
CREATE TABLE Plant_characteristics (
    Id BIGSERIAL PRIMARY KEY,
    Plant_id BIGINT NOT NULL REFERENCES Plant_directory(Id) ON DELETE CASCADE,
    Characteristic_type VARCHAR(50) NOT NULL,
    Value VARCHAR(100),
    Unit VARCHAR(20),
    Max_height_m NUMERIC(6,2) CHECK (Max_height_m >= 0),
    Growth_rate growth_rate_enum
);

COMMENT ON TABLE Plant_characteristics IS 'Расширенные параметры для видов растений';

-- ---------------------------------------------------------------------
-- Таблица: Instructions_care (Инструкции по уходу)
-- ---------------------------------------------------------------------
CREATE TABLE Instructions_care (
    Id BIGSERIAL PRIMARY KEY,
    Plant_id BIGINT NOT NULL REFERENCES Plant_directory(Id) ON DELETE CASCADE,
    Light_requirements TEXT,
    Watering_schedule TEXT,
    Fertilizing TEXT,
    Temperature_range VARCHAR(100),
    Humidity_requirements TEXT,
    Pest_control TEXT,
    Special_instructions TEXT
);

COMMENT ON TABLE Instructions_care IS 'Детальные гайды по выращиванию каждого вида';

-- ---------------------------------------------------------------------
-- Таблица: Products (Товарные позиции)
-- ---------------------------------------------------------------------
CREATE TABLE Products (
    Id BIGSERIAL PRIMARY KEY,
    Plant_id BIGINT NOT NULL REFERENCES Plant_directory(Id) ON DELETE RESTRICT,
    Variety VARCHAR(100),
    Age_months INT CHECK (Age_months >= 0),
    Height_cm NUMERIC(6,2) CHECK (Height_cm >= 0),
    Price NUMERIC(12,2) NOT NULL CHECK (Price >= 0),
    Stock_quantity INT NOT NULL DEFAULT 0 CHECK (Stock_quantity >= 0),
    Article_number VARCHAR(50) UNIQUE,
    Seasonal_availability seasonal_availability_enum DEFAULT 'year_round',
    Active BOOLEAN DEFAULT TRUE
);

COMMENT ON TABLE Products IS 'Конкретные товарные позиции с ценой и остатками';

-- ============================================
-- 5. Таблицы заказов
-- ============================================

-- ---------------------------------------------------------------------
-- Таблица: Orders (Заказы)
-- ---------------------------------------------------------------------
CREATE TABLE Orders (
    Id BIGSERIAL PRIMARY KEY,
    Customer_id BIGINT NOT NULL REFERENCES Customers(Id) ON DELETE RESTRICT,
    Order_date TIMESTAMP DEFAULT NOW(),
    Status VARCHAR(100) DEFAULT 'draft',
    Delivery_id BIGINT REFERENCES Delivery(Id) ON DELETE SET NULL,
    Delivery_address TEXT NOT NULL,
    Delivery_days INT,
    Preferred_delivery_date TIMESTAMP,
    Assigned_employee_id BIGINT REFERENCES Employees(Id) ON DELETE SET NULL,
    Final_amount NUMERIC(12,2) DEFAULT 0 CHECK (Final_amount >= 0),
    Payment_completed BOOLEAN DEFAULT FALSE,
    Comment TEXT
);

COMMENT ON TABLE Orders IS 'Основной документ заказа';

-- ---------------------------------------------------------------------
-- Таблица: Orders_Products (Связующая "многие ко многим")
-- ---------------------------------------------------------------------
CREATE TABLE Orders_Products (
    Orders_id BIGINT NOT NULL REFERENCES Orders(Id) ON DELETE CASCADE,
    Products_id BIGINT NOT NULL REFERENCES Products(Id) ON DELETE RESTRICT,
    PRIMARY KEY (Orders_id, Products_id)
);

COMMENT ON TABLE Orders_Products IS 'Связь заказов и товаров (многие ко многим)';

-- ---------------------------------------------------------------------
-- Таблица: Logistics (Логистика/Маршруты)
-- ---------------------------------------------------------------------
CREATE TABLE Logistics (
    Id BIGSERIAL PRIMARY KEY,
    Order_id BIGINT REFERENCES Orders(Id) ON DELETE CASCADE,
    Employee_id BIGINT REFERENCES Employees(Id) ON DELETE SET NULL,
    Route_name VARCHAR(150),
    Start_point GEOGRAPHY(POINT, 4326),
    End_point GEOGRAPHY(POINT, 4326),
    Route_geometry GEOGRAPHY(LINESTRING, 4326),
    Distance_km NUMERIC(10,2) CHECK (Distance_km >= 0),
    Status TEXT DEFAULT 'planned'
);

COMMENT ON TABLE Logistics IS 'Маршруты доставки и логистика (PostGIS)';

-- ============================================
-- 6. Индексы для производительности
-- ============================================

-- Индексы для внешних ключей
CREATE INDEX idx_location_address_attraction_id ON Location_address(Attraction_id);
CREATE INDEX idx_plant_directory_origin_location_id ON Plant_directory(Origin_location_id);
CREATE INDEX idx_plant_characteristics_plant_id ON Plant_characteristics(Plant_id);
CREATE INDEX idx_instructions_care_plant_id ON Instructions_care(Plant_id);
CREATE INDEX idx_products_plant_id ON Products(Plant_id);
CREATE INDEX idx_products_article_number ON Products(Article_number);
CREATE INDEX idx_orders_customer_id ON Orders(Customer_id);
CREATE INDEX idx_orders_delivery_id ON Orders(Delivery_id);
CREATE INDEX idx_orders_assigned_employee_id ON Orders(Assigned_employee_id);
CREATE INDEX idx_orders_products_orders_id ON Orders_Products(Orders_id);
CREATE INDEX idx_orders_products_products_id ON Orders_Products(Products_id);
CREATE INDEX idx_logistics_order_id ON Logistics(Order_id);
CREATE INDEX idx_logistics_employee_id ON Logistics(Employee_id);

-- GIST-индексы для PostGIS-полей
CREATE INDEX idx_attraction_coordinates ON Attraction USING GIST (Coordinates);
CREATE INDEX idx_attraction_center_point ON Attraction USING GIST (Center_point);
CREATE INDEX idx_location_address_point ON Location_address USING GIST (Point);
CREATE INDEX idx_logistics_start_point ON Logistics USING GIST (Start_point);
CREATE INDEX idx_logistics_end_point ON Logistics USING GIST (End_point);
CREATE INDEX idx_logistics_route_geometry ON Logistics USING GIST (Route_geometry);


-- ============================================
-- CTE и подзапрос
-- ============================================
--CTE, для получения данных по растением расположенным в указанной локации
with Address_Cte as
(
	Select
	pd.official_name, pd.family, pd.genus , pd.description, pd.conservation_status,
	pc.characteristic_type, pc.value, pc.max_height_m, pc.growth_rate,
	ic.light_requirements, ic.watering_schedule, ic.fertilizing, ic.temperature_range, ic.humidity_requirements, ic.pest_control, ic.special_instructions, 
	la.attraction_id, la.country, la.region, la.address,
	case when COUNT(p.Id) > 0 then true else false end as exist_in_products
	from Location_address la
	left join Plant_directory pd on pd.Origin_location_id = la.Id
	left join Instructions_care ic on ic.Plant_id = pd.Id
	left join Plant_characteristics pc on pc.Plant_id = pd.Id
	left join Products p on p.Plant_id = pd.Id
	group by pd.official_name, pd.family, pd.genus , pd.description, pd.conservation_status,
	pc.characteristic_type, pc.value, pc.max_height_m, pc.growth_rate,
	ic.light_requirements, ic.watering_schedule, ic.fertilizing, ic.temperature_range, ic.humidity_requirements, ic.pest_control, ic.special_instructions, 
	la.attraction_id, la.country, la.region, la.address
),

Attr_Cte as
(
	Select a.Id as Attr_ID, a.Name as Attr_Name, ac.* from Attraction a
	left join Address_Cte ac on ac.Attraction_id = a.Id
)


Select * from Attr_Cte ac where ac.Attr_ID = 11 



--Подзапрос для получения информации по заказу определенного покупателя с данными по сотруднику, ответственному за заказ.
select o.*,
(SELECT c.Full_name FROM Customers c WHERE c.Id = o.Customer_id) AS Customer_name,
(SELECT c.Phone FROM Customers c WHERE c.Id = o.Customer_id) AS Customer_phone,
(SELECT e.Full_name FROM Employees e WHERE e.Id = o.Assigned_employee_id) AS Employee_name,
(SELECT e.Position FROM Employees e WHERE e.Id = o.Assigned_employee_id) AS Employee_position,
(SELECT e.Phone FROM Employees e WHERE e.Id = o.Assigned_employee_id) AS Employee_phone,
(SELECT e.Email FROM Employees e WHERE e.Id = o.Assigned_employee_id) AS Employee_email
from Orders o
where o.Customer_id  in (SELECT c.Id FROM customers c where c.Full_name = 'Сергей Козлов') 
and o.Assigned_employee_id IS NOT NULL;
