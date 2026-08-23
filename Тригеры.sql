-- Создадим 3 тригера на основе имеющийся процедуры - proc_recalc_order_total, которая пересчитывает конечную стоимость всего заказа
-- Функция-обёртка для процедуры, что-бы можно было использовать её в тригерах
CREATE OR REPLACE FUNCTION recalc_order_total()
RETURNS TRIGGER AS $$
DECLARE
    v_order_id BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_order_id := OLD.Orders_id;
    ELSE
        v_order_id := NEW.Orders_id;
    END IF;

    -- Вызываем процедуру
    CALL proc_recalc_order_total(v_order_id);

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Триггеры
CREATE TRIGGER trg_recalc_after_insert
AFTER INSERT ON Orders_Products
FOR EACH ROW EXECUTE FUNCTION recalc_order_total();

CREATE TRIGGER trg_recalc_after_delete
AFTER DELETE ON Orders_Products
FOR EACH ROW EXECUTE FUNCTION recalc_order_total();

CREATE TRIGGER trg_recalc_on_delivery_change
AFTER UPDATE OF Delivery_id ON Orders
FOR EACH ROW
EXECUTE FUNCTION recalc_order_total();