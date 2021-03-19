use adventureworks2017;
-- продажи по годам
SELECT
	YEAR(OrderDate) AS OrderYear,
	SUM(SubTotal) AS Income
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate)
ORDER BY OrderYear;

-- продажи по годам + за сколько месяцев подсчет
-- COUNT(distinct)...
SELECT
	YEAR(OrderDate) AS OrderYear,
	SUM(SubTotal) AS Income,
    COUNT(distinct YEAR(OrderDate)) as years,
    COUNT(distinct month(OrderDate)) as months
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate)
ORDER BY OrderYear;

-- уберем дистинкт
-- получим стандартную ситуацию с неправильным подсчетом
SELECT
	YEAR(OrderDate) AS OrderYear,
	SUM(SubTotal) AS Income,
    COUNT(distinct YEAR(OrderDate)) as yearsD,
    COUNT(distinct month(OrderDate)) as monthsD,
    COUNT(YEAR(OrderDate)) as years, -- по факту количество строк, абсолютно бессмысленно
    COUNT(month(OrderDate)) as months,-- month и year дорогие операции и это аналог count(1)
    COUNT(1)
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate)
ORDER BY OrderYear;

-- продажи по годам и месяцам -- ошибка ???
-- в агрегатной функции должны быть указаны все поля !!
SELECT
	YEAR(OrderDate) AS OrderYear,
    OrderDate, 
	SUM(SubTotal) AS Income
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate)
ORDER BY OrderYear;

-- в GROUP BY можно использовать ALIAS
SELECT
	YEAR(OrderDate) AS OrderYear,
    OrderDate, 
	SUM(SubTotal) AS Income
FROM SalesOrderHeader
GROUP BY OrderYear
ORDER BY OrderYear;




-- OrderDate, -- скорее всего будет последняя строка, попавшаяся в выборку
-- добавлено в 8 версии



-- https://dev.mysql.com/doc/refman/8.0/en/sql-mode.html
SET sql_mode = 'ONLY_FULL_GROUP_BY';
SELECT
	YEAR(OrderDate) AS OrderYear,
    OrderDate,
	SUM(SubTotal) AS Income
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate)
ORDER BY OrderYear;

-- прям стандартный запрос по статистике
-- продажи по годам и месяцам
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Income
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
ORDER BY OrderYear, OrderMonth;

-- продажи по годам и месяцам
-- добавил COUNT(distinct), чтобы уведиться в уникальности подсчета
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Income,
    COUNT(distinct YEAR(OrderDate)) as years,
    COUNT(distinct month(OrderDate)) as months
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
ORDER BY OrderYear, OrderMonth;

-- продажи по годам и месяцам + год
-- делаем искусственный тотал
SELECT
	YEAR(OrderDate) AS OrderYear,
	NULL AS OrderMonth, -- Dummy Column
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate)
UNION ALL
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
ORDER BY OrderYear, OrderMonth;

-- то же самое, но через rollup
-- rollup идет по всем полям, указать нельзя
SELECT
	YEAR(S.OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader S
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP;

-- укажем ALIAS по другому - без AS - тоже работает
SELECT
	YEAR(S.OrderDate) OrderYear,
	MONTH(OrderDate) OrderMonth,
	SUM(SubTotal) Incomes
FROM SalesOrderHeader S
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP;

-- по хорошему конечно лучше писать с указанием таблицы
SELECT
	YEAR(S.OrderDate) AS OrderYear,
	MONTH(S.OrderDate) AS OrderMonth,
	SUM(S.SubTotal) AS Incomes
FROM SalesOrderHeader S
GROUP BY YEAR(S.OrderDate),MONTH(S.OrderDate) WITH ROLLUP;

-- в GROUP BY alias можно использовать
SELECT
	YEAR(S.OrderDate) AS OrderYear,
	MONTH(S.OrderDate) AS OrderMonth,
	SUM(S.SubTotal) AS Incomes
FROM SalesOrderHeader S
GROUP BY OrderYear, OrderMonth WITH ROLLUP;

-- в WHERE alias нельзя использовать
SELECT
	YEAR(S.OrderDate) AS OrderYear,
	MONTH(S.OrderDate) AS OrderMonth,
	SUM(S.SubTotal) AS Incomes
FROM SalesOrderHeader S
WHERE OrderYear = 2012
GROUP BY OrderYear, OrderMonth WITH ROLLUP;

-- то же самое, но через rollup и сделаем фильтр
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
GROUP BY OrderYear, OrderMonth WITH ROLLUP -- индексы участвуют
HAVING OrderYear > 2011; -- используем ALIAS, тотал по 2011 тоже отсутствует 
-- having индексов конечно нет, так как это результат
-- посмотрим план
-- посмотрим тоже самое в MSSQL
use AdventureWorks2017;
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate), MONTH(OrderDate) WITH ROLLUP
HAVING YEAR(OrderDate) > 2011;
-- ни в груп ни в хэвинге нельзя использовать алиасы


-- лучше сначал выборку, потом группировку
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
WHERE OrderYear > 2011 -- ошибка, здесь ALIAS невозможен
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP;

SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
WHERE YEAR(OrderDate) > 2011 -- все хорошо
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP;

SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
GROUP BY OrderYear, OrderMonth WITH ROLLUP -- индексы участвуют
HAVING OrderYear > 2011; -- используем ALIAS, тотал по 2011 тоже отсутствует 

-- сортировка
-- отключаем ONLY_FULL_GROUP_BY
-- сортируем с ORDER BY
SET sql_mode = '';
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
WHERE YEAR(OrderDate) > 2011 -- все хорошо
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP
ORDER BY OrderDate DESC;

-- сортируем без
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
WHERE YEAR(OrderDate) > 2011 -- все хорошо
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP;
-- ORDER BY OrderDate DESC; -- неявно все равно есть


-- скрипт не отработает при включении полной сортировки
SET sql_mode = 'ONLY_FULL_GROUP_BY';
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
WHERE YEAR(OrderDate) > 2011 -- все хорошо
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP
ORDER BY OrderDate DESC; 


-- сортировка по алиасу
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
WHERE YEAR(OrderDate) > 2011 -- все хорошо
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP
ORDER BY OrderMonth DESC; 

-- аналогично
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
WHERE YEAR(OrderDate) > 2011 -- все хорошо
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP
ORDER BY 1 DESC; 

-- сумма только тотала больше определенной суммы
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes,
	SUM(CASE 
			WHEN SubTotal > 10000 THEN SubTotal 
			ELSE 0
		END) AS IncomesBig
FROM SalesOrderHeader
WHERE YEAR(OrderDate) > 2011 -- все хорошо
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP;


-- rollup && grouping
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP;

-- посмотрим теорию про grouping
SET sql_mode = '';
SELECT
	IF(GROUPING(YEAR(OrderDate)), 'All years', YEAR(OrderDate)) AS OrderYear,
	IF(GROUPING(MONTH(OrderDate)), 'All months', MONTH(OrderDate)) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP;

SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
GROUP BY ROLLUP (YEAR(OrderDate)), MONTH(OrderDate); -- не работает, только по всем полям %(

-- итоги в начале
-- включим grouping в order by
SELECT
	IF(GROUPING(YEAR(OrderDate)), 'All years', YEAR(OrderDate)) AS OrderYear,
	IF(GROUPING(MONTH(OrderDate)), 'All months', MONTH(OrderDate)) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP
ORDER BY GROUPING(YEAR(OrderDate)) DESC, GROUPING(MONTH(OrderDate)) DESC;

-- оставим только итоги
SELECT
	IF(GROUPING(YEAR(OrderDate)), 'All years', YEAR(OrderDate)) AS OrderYear,
	IF(GROUPING(MONTH(OrderDate)), 'All months', MONTH(OrderDate)) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP
HAVING GROUPING(YEAR(OrderDate),MONTH(OrderDate)) <> 0 -- ошибка
ORDER BY GROUPING(YEAR(OrderDate)) DESC, GROUPING(MONTH(OrderDate)) DESC;

-- в группинге уже можем использовать только алиасы
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP
HAVING GROUPING(OrderYear,OrderMonth) <> 0; -- любая строчка итог не пустая
-- ORDER BY GROUPING(YEAR(OrderDate)) DESC, GROUPING(MONTH(OrderDate)) DESC;

-- rollup по 3 полям
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	DAY(OrderDate) AS OrderDay,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate),MONTH(OrderDate),DAY(OrderDate) WITH ROLLUP;

-- подпишем тоталы
SELECT
	IF(GROUPING(YEAR(OrderDate)), 'All years', YEAR(OrderDate)) AS OrderYear,
	IF(GROUPING(MONTH(OrderDate)), 'All months', MONTH(OrderDate)) AS OrderMonth,
	IF(GROUPING(DAY(OrderDate)), 'All days', DAY(OrderDate)) AS OrderDay,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate),MONTH(OrderDate),DAY(OrderDate) WITH ROLLUP;

-- order by
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP
order by OrderYear, OrderMonth;

-- отсортируем в разном порядке
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP
order by OrderYear asc, OrderMonth desc;

-- отсортируем в случайном порядке %)
SELECT
	YEAR(OrderDate) AS OrderYear,
	MONTH(OrderDate) AS OrderMonth,
	SUM(SubTotal) AS Incomes
FROM SalesOrderHeader
GROUP BY YEAR(OrderDate),MONTH(OrderDate) WITH ROLLUP
order by rand();

https://cdn.otus.ru/media/private/0f/0a/aggregation_160122113423_4560_0f0ae7_1-25239-0f0ae7.pdf?hash=_DR5Yt8RDuw6nNc6AC8bFg&expires=1612306244
      



-- Где можно уже использовать ALIAS - where, group by, having, order by?
SELECT SubTotal t FROM SalesOrderHeader group by t having t > 1 order by t limit 1;