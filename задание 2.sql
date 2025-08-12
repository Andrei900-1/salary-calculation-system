CREATE OR REPLACE PROCEDURE sp_employee_absences_report(
    m_x INT, 
    y_x INT
)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE  
    cnt_shift INT := 1;
BEGIN
    -- Расчет количества рабочих дней в месяце
    SELECT COUNT(date_x)
    INTO cnt_shift
    FROM t_date_work
    WHERE date_part('month', date_x) = m_x AND
          date_part('year', date_x) = y_x;

    DROP TABLE IF EXISTS t_temp;
    
    -- Создание временной таблицы с данными о работе
    CREATE TEMP TABLE t_temp ON COMMIT DROP AS
    SELECT 
        d.date_x, 
        w.id_people, 
        w.id_status,
        px.id_post, 
        px.id_place,
        w.value_x, 
        w.defect_x, 
        w.price_x,
        ROUND(po.post_salary * pl.k_place * st.k_status / cnt_shift, 2) AS day_salary, 
        date_part('month', d.date_x) AS month_x,
        date_part('year', d.date_x) AS year_x,
        pl.place AS workshop
    FROM 
        t_date_work AS d
        JOIN t_work AS w ON d.id = w.id_date
        JOIN t_status AS st ON st.id = w.id_status
        JOIN t_ppp AS px ON w.id_people = px.id_people
        JOIN t_post AS po ON px.id_post = po.id
        JOIN t_place AS pl ON px.id_place = pl.id
    WHERE 
        px.date_decree = (
            SELECT MAX(q.date_decree)
            FROM t_ppp AS q
            WHERE px.id_people = q.id_people AND q.date_decree <= d.date_x
        ) AND
        date_part('month', d.date_x) = m_x AND
        date_part('year', d.date_x) = y_x;

    -- Создание или обновление таблицы отчетности
    IF NOT EXISTS (
        SELECT *
        FROM information_schema.tables
        WHERE table_name = 't_employee_absences'
        AND table_schema = 'public'
    ) THEN
        -- Создание таблицы отчетности, если она не существует
        CREATE TABLE t_employee_absences AS
        SELECT 
            t.workshop,
            t.month_x,
            t.year_x AS year_x,
            COUNT(CASE WHEN t.id_status = 2 THEN 1 END) AS days_business_trip,
            COUNT(CASE WHEN t.id_status = 3 THEN 1 END) AS days_sick_leave,
            COUNT(CASE WHEN t.id_status = 4 THEN 1 END) AS days_vacation,
            COUNT(CASE WHEN t.id_status > 1 THEN 1 END) AS total_days_absence,
            COALESCE(SUM(CASE WHEN t.id_status = 2 THEN t.day_salary END), 0) AS salary_business_trip,
            COALESCE(SUM(CASE WHEN t.id_status = 3 THEN t.day_salary END), 0) AS salary_sick_leave,
            COALESCE(SUM(CASE WHEN t.id_status = 4 THEN t.day_salary END), 0) AS salary_vacation,
            COALESCE(SUM(CASE WHEN t.id_status > 1 THEN t.day_salary END), 0) AS total_salary_absences
        FROM 
            t_temp t
        GROUP BY 
            t.workshop, t.month_x, t.year_x;
    ELSE
        -- Проверка, существуют ли уже данные за указанный период
        IF NOT EXISTS (
            SELECT * 
            FROM t_employee_absences
            WHERE month_x = m_x AND year_x = y_x
        ) THEN
            -- Вставка новых данных
            INSERT INTO t_employee_absences (
                workshop,
                month_x,
                year_x,
                days_business_trip,
                days_sick_leave,
                days_vacation,
                total_days_absence,
                salary_business_trip,
                salary_sick_leave,
                salary_vacation,
                total_salary_absences
            )
            SELECT 
                t.workshop,
                t.month_x,
                t.year_x,
                COUNT(CASE WHEN t.id_status = 2 THEN 1 END) AS days_business_trip,
                COUNT(CASE WHEN t.id_status = 3 THEN 1 END) AS days_sick_leave,
                COUNT(CASE WHEN t.id_status = 4 THEN 1 END) AS days_vacation,
                COUNT(CASE WHEN t.id_status > 1 THEN 1 END) AS total_days_absence,
                COALESCE(SUM(CASE WHEN t.id_status = 2 THEN t.day_salary END), 0) AS salary_business_trip,COALESCE(SUM(CASE WHEN t.id_status = 3 THEN t.day_salary END), 0) AS salary_sick_leave,
                COALESCE(SUM(CASE WHEN t.id_status = 4 THEN t.day_salary END), 0) AS salary_vacation,
                COALESCE(SUM(CASE WHEN t.id_status > 1 THEN t.day_salary END), 0) AS total_salary_absences
            FROM 
             t_temp t
            GROUP BY 
                t.workshop, t.month_x, t.year_x;
        ELSE
            RAISE NOTICE 'Данные за указанный период уже существуют!';
        END IF;
    END IF;
    
    -- Вывод результатов
    RAISE NOTICE 'Отчет по отсутствиям сотрудников за %/%:', m_x, y_x;
END;
$BODY$;
--Расчет и добавление данных
CALL sp_employee_absences_report(1, 2025);
CALL sp_employee_absences_report(2, 2025);
CALL sp_employee_absences_report(3, 2025);
CALL sp_employee_absences_report(4, 2025);
CALL sp_employee_absences_report(5, 2025);
--Просмотр данных 
SELECT *
	FROM public.t_employee_absences;
