-- Эффективность продаж

CREATE OR REPLACE VIEW v_sales_performance AS
WITH sales_data AS (
    SELECT 
        p.Plant_id,
        pd.Name AS plant_name,
        pd.Family,
        COUNT(op.Orders_id) AS total_sold_units,
        SUM(p.Price) AS total_revenue,
        AVG(p.Price) AS avg_sale_price,
        MAX(p.Stock_quantity) AS current_stock
    FROM Products p
    JOIN Plant_directory pd ON p.Plant_id = pd.Id
    LEFT JOIN Orders_Products op ON p.Id = op.Products_id
    LEFT JOIN Orders o ON op.Orders_id = o.Id AND o.Payment_completed = TRUE
    GROUP BY p.Plant_id, pd.Name, pd.Family
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS rank,
    plant_name,
    family,
    total_sold_units,
    total_revenue,
    avg_sale_price,
    current_stock,
    CASE 
        WHEN current_stock < 5 AND total_sold_units > 10 THEN 'Требуется срочная дозакупка'
        WHEN current_stock < 3 THEN 'Заканчивается'
        ELSE 'В наличии'
    END AS stock_status
FROM sales_data
ORDER BY total_revenue DESC;

-- Активные клиенты

CREATE OR REPLACE VIEW v_active_customers AS
SELECT 
    c.Id AS customer_id,
    c.Full_name,
    c.Email,
    c.Phone,
    c.Delivery_address,
    c.Discount,
    COUNT(o.Id) AS total_orders,
    SUM(o.Final_amount) AS total_spent,
    MAX(o.Order_date) AS last_order_date,
    CASE 
        WHEN MAX(o.Order_date) > NOW() - INTERVAL '30 days' THEN 'Активный'
        WHEN MAX(o.Order_date) > NOW() - INTERVAL '90 days' THEN 'Требует возврата'
        ELSE 'Неактивный'
    END AS customer_status
FROM Customers c
JOIN Orders o ON c.Id = o.Customer_id
WHERE o.Payment_completed = TRUE
GROUP BY c.Id, c.Full_name, c.Email, c.Phone, c.Delivery_address, c.Discount
ORDER BY total_spent DESC;

-- Складской учет (для ботаников и агрономов)

CREATE OR REPLACE VIEW v_plant_inventory AS
SELECT 
    pd.Id AS plant_id,
    pd.Name AS plant_name,
    pd.Family,
    pd.Conservation_status,
    COUNT(p.Id) AS total_varieties,
    SUM(p.Stock_quantity) AS total_stock,
    MIN(p.Price) AS min_price,
    MAX(p.Price) AS max_price,
    BOOL_OR(p.Active) AS has_active_products,
    (SELECT string_agg(DISTINCT Characteristic_type, ', ') 
     FROM Plant_characteristics 
     WHERE Plant_id = pd.Id) AS characteristics_list,
    (SELECT COUNT(*) FROM Orders_Products op 
     JOIN Products p2 ON op.Products_id = p2.Id 
     WHERE p2.Plant_id = pd.Id) AS total_sold_all_time
FROM Plant_directory pd
LEFT JOIN Products p ON pd.Id = p.Plant_id
GROUP BY pd.Id, pd.Name, pd.Family, pd.Conservation_status
ORDER BY plant_name;


-- Дашборд компании

CREATE OR REPLACE VIEW v_company_dashboard AS
SELECT 
    (SELECT COUNT(*) FROM Customers WHERE Active = TRUE) AS total_active_customers,
    (SELECT COUNT(*) FROM Orders WHERE Payment_completed = TRUE) AS total_completed_orders,
    (SELECT SUM(Final_amount) FROM Orders WHERE Payment_completed = TRUE) AS total_revenue,
    (SELECT COUNT(*) FROM Products WHERE Active = TRUE AND Stock_quantity > 0) AS available_products,
    (SELECT COUNT(*) FROM Employees WHERE Available = TRUE) AS active_employees,
    NOW() AS report_generated_at;
	
	
-- Примеры

SELECT * FROM v_sales_performance LIMIT 10;
SELECT * FROM v_active_customers;
SELECT * FROM v_plant_inventory;
SELECT * FROM v_company_dashboard;