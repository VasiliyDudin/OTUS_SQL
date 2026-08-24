-- Мониторинг производительности БД будем осуществлять через - Prometheus + Grafana
-- Для этих целей нужно будет создать пользователя, ему и будем назначать права для сбора метрик

CREATE USER postgres_exporter WITH PASSWORD ******;
GRANT CONNECT ON DATABASE "DZ_OTUS_SQL" TO postgres_exporter;
GRANT pg_monitor TO postgres_exporter;

-- т.к. я создавал отдельную схему project для своего проекта, добавим еще права новому пользователю - postgres_exporter, на её чтение
GRANT USAGE ON SCHEMA project TO postgres_exporter;
GRANT SELECT ON ALL TABLES IN SCHEMA project TO postgres_exporter;

-- права на чтение представлений (VIEW) — чтобы видеть агрегированные данные
GRANT SELECT ON TABLE project.v_sales_performance TO postgres_exporter;
GRANT SELECT ON TABLE project.v_active_customers TO postgres_exporter;
GRANT SELECT ON TABLE project.v_plant_inventory TO postgres_exporter;
GRANT SELECT ON TABLE project.v_company_dashboard TO postgres_exporter;

-- Доступ к выполнению функций
GRANT EXECUTE ON FUNCTION project.get_plant_detailed_report TO postgres_exporter;
GRANT EXECUTE ON FUNCTION project.get_company_budget TO postgres_exporter;