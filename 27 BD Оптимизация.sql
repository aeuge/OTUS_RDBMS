-- посмотрим ресурсы. При нехватке памяти начинает расти swap
free -h
-- проц и память
top
-- CPU
htop -- load average
-- IO
sudo iotop
-- сеть
sudo iftop	
-- sudo apt install iftop -- установить
atop -- подкрасит проблемы через некоторе время

sysctl -a | grep swap
vm.swappiness = 60 -- процент свободной памяти, при которых система начинает скиыдвать в своп. на реальныз базах - 10-20%

-- sudo apt install mysqltuner -y


-- при слишком маленьком буферном пуле данные не помешаются в память и начинает постоянно дергаться диск
-- рекомендация до 80% памяти сервера
SHOW variables like '%pool_size%'
SHOW status like '%hit%'
SHOW status like '%miss%'


-- Например при связке php+mysql php при каждом запросе устанавливает соединение, выполняет запрос и рвет его. 
-- В mysql это очень дорогая операция. Лучше держать пул коннектов.
SHOW processlist;

-- EXPLAIN
desc purchasing.suppliers
SHOW WARNINGS

desc SELECT * FROM purchasing.suppliers

SET @StartDate = '2013-01-01';
SET @EndDate = NOW();
desc with RECURSIVE cte_month as (SELECT @StartDate as pMonth
				   UNION ALL
				   SELECT DATE_ADD(pMonth, INTERVAL 1 MONTH)
				   FROM cte_month
				   WHERE pMonth < @EndDate)
SELECT  cte_month.pMonth AS InvoiceMonth, 
		COALESCE(AVG(inlines.UnitPrice), 0) AS AVG_Price, 
        COALESCE(SUM(inlines.Quantity*inlines.UnitPrice),0) TotalSUM
FROM cte_month
LEFT JOIN Sales.Invoices inv ON cte_month.pMonth = inv.InvoiceDate 
LEFT JOIN Sales.InvoiceLines inlines on inv.InvoiceID = inlines.InvoiceID 
GROUP BY cte_month.pMonth
ORDER BY cte_month.pMonth

SHOW WARNINGS -- 1003 - конечный вид запроса, который был выполнен

-- Вывести сумму продаж, дату первой продажи и количество проданного по месяцам, по товарам, 
-- продажи которых менее 50 ед в месяц. Группировка по году и месяцу.
desc SELECT SQL_CALC_FOUND_ROWS inv.inv_Year, inv.inv_Month, invoice_Sum.First_Invoice AS First_Invoice,
       COALESCE(invoice_Sum.Description, '') as inv_Descr, 
       COALESCE(invoice_Sum.TotalSUM, 0) as TotalSUM, 
       COALESCE(invoice_Sum.TotalQ,0) as TotalQ
FROM (SELECT DISTINCT YEAR(InvoiceDate) as inv_Year, MONTH(InvoiceDate) as inv_Month
      FROM Sales.Invoices) as inv
LEFT JOIN (SELECT YEAR(inv_1.InvoiceDate) as inv1_Year, MONTH(inv_1.InvoiceDate) as Inv1_Month,  
		   MIN(inv_1.InvoiceDate) AS First_Invoice,
           inlines.Description, SUM(inlines.Quantity*inlines.UnitPrice) AS TotalSUM, SUM(inlines.Quantity) AS TotalQ
           FROM Sales.Invoices inv_1 
		   INNER JOIN Sales.InvoiceLines inlines ON inv_1.InvoiceID = inlines.InvoiceID
		   GROUP BY YEAR(inv_1.InvoiceDate), MONTH(inv_1.InvoiceDate), inlines.Description
		   HAVING SUM(inlines.Quantity) < 50 ) as invoice_Sum on invoice_Sum.inv1_Month = inv.inv_Month 
           and invoice_Sum.inv1_Year = inv.inv_Year

SHOW WARNINGS -- 1287 SQL_CALC_FOUND_ROWS deprecated

-- вывод в JSON
desc FORMAT=JSON SELECT SQL_CALC_FOUND_ROWS inv.inv_Year, inv.inv_Month, invoice_Sum.First_Invoice AS First_Invoice,
       COALESCE(invoice_Sum.Description, '') as inv_Descr, 
       COALESCE(invoice_Sum.TotalSUM, 0) as TotalSUM, 
       COALESCE(invoice_Sum.TotalQ,0) as TotalQ
FROM (SELECT DISTINCT YEAR(InvoiceDate) as inv_Year, MONTH(InvoiceDate) as inv_Month
      FROM Sales.Invoices) as inv
LEFT JOIN (SELECT YEAR(inv_1.InvoiceDate) as inv1_Year, MONTH(inv_1.InvoiceDate) as Inv1_Month,  
		   MIN(inv_1.InvoiceDate) AS First_Invoice,
           inlines.Description, SUM(inlines.Quantity*inlines.UnitPrice) AS TotalSUM, SUM(inlines.Quantity) AS TotalQ
           FROM Sales.Invoices inv_1 
		   INNER JOIN Sales.InvoiceLines inlines ON inv_1.InvoiceID = inlines.InvoiceID
		   GROUP BY YEAR(inv_1.InvoiceDate), MONTH(inv_1.InvoiceDate), inlines.Description
		   HAVING SUM(inlines.Quantity) < 50 ) as invoice_Sum on invoice_Sum.inv1_Month = inv.inv_Month 
           and invoice_Sum.inv1_Year = inv.inv_Year

-- вывод в TREE
desc FORMAT=TREE SELECT SQL_CALC_FOUND_ROWS inv.inv_Year, inv.inv_Month, invoice_Sum.First_Invoice AS First_Invoice,
       COALESCE(invoice_Sum.Description, '') as inv_Descr, 
       COALESCE(invoice_Sum.TotalSUM, 0) as TotalSUM, 
       COALESCE(invoice_Sum.TotalQ,0) as TotalQ
FROM (SELECT DISTINCT YEAR(InvoiceDate) as inv_Year, MONTH(InvoiceDate) as inv_Month
      FROM Sales.Invoices) as inv
LEFT JOIN (SELECT YEAR(inv_1.InvoiceDate) as inv1_Year, MONTH(inv_1.InvoiceDate) as Inv1_Month,  
		   MIN(inv_1.InvoiceDate) AS First_Invoice,
           inlines.Description, SUM(inlines.Quantity*inlines.UnitPrice) AS TotalSUM, SUM(inlines.Quantity) AS TotalQ
           FROM Sales.Invoices inv_1 
		   INNER JOIN Sales.InvoiceLines inlines ON inv_1.InvoiceID = inlines.InvoiceID
		   GROUP BY YEAR(inv_1.InvoiceDate), MONTH(inv_1.InvoiceDate), inlines.Description
		   HAVING SUM(inlines.Quantity) < 50 ) as invoice_Sum on invoice_Sum.inv1_Month = inv.inv_Month 
           and invoice_Sum.inv1_Year = inv.inv_Year

-- Посчитать общую сумму продажи по месяцам
desc SELECT  YEAR(inv.InvoiceDate) AS InvoiceYEAR, 
		MONTH(inv.InvoiceDate) AS InvoiceMonth, 
		SUM(inlines.Quantity*inlines.UnitPrice) TotalSUM
FROM Sales.InvoiceLines inlines
INNER JOIN Sales.Invoices inv ON inv.InvoiceID = inlines.InvoiceID
GROUP BY YEAR(inv.InvoiceDate),MONTH(inv.InvoiceDate);

desc FORMAT=TREE SELECT  YEAR(inv.InvoiceDate) AS InvoiceYEAR, 
		MONTH(inv.InvoiceDate) AS InvoiceMonth, 
		SUM(inlines.Quantity*inlines.UnitPrice) TotalSUM
FROM Sales.InvoiceLines inlines
INNER JOIN Sales.Invoices inv ON inv.InvoiceID = inlines.InvoiceID
GROUP BY YEAR(inv.InvoiceDate),MONTH(inv.InvoiceDate);

-- посмотрим разницу в планах для простых запросов с индексом и без
desc FORMAT=TREE SELECT * FROM Sales.InvoiceLines inlines WHERE InvoiceID = 1;
desc FORMAT=TREE SELECT * FROM Sales.InvoiceLines inlines WHERE Quantity = 10;

-- во 2 окне выполним и посмотрим EXPLAIN FOR CONNECTION
SELECT Invoices.InvoiceId, Invoices.InvoiceDate, Invoices.CustomerID, trans.TransactionAmount,
	(SELECT MAX(inr.TransactionAmount) -- коррелированный/зависимый подзапрос по таблице CustomerTransactions
	FROM Sales.CustomerTransactions AS inr
	JOIN Sales.Invoices AS InvoicesInner ON 
		InvoicesInner.InvoiceID = inr.InvoiceID
	WHERE inr.CustomerID = trans.CustomerId 
		AND InvoicesInner.InvoiceDate < '2014-01-01') AS MaxPerCustomer
FROM Sales.Invoices AS Invoices
JOIN Sales.CustomerTransactions AS trans
	ON Invoices.InvoiceID = trans.InvoiceID
WHERE Invoices.InvoiceDate < '2014-01-01'
ORDER BY Invoices.InvoiceId, Invoices.InvoiceDate
-- --
SHOW processlist
desc for connection 11;

-- EXPLAIN ANALYZE -- смотрим не только план, но и выполняем запрос и смотрим татистику по времени выполнения
EXPLAIN ANALYZE SELECT SQL_CALC_FOUND_ROWS inv.inv_Year, inv.inv_Month, invoice_Sum.First_Invoice AS First_Invoice,
       COALESCE(invoice_Sum.Description, '') as inv_Descr, 
       COALESCE(invoice_Sum.TotalSUM, 0) as TotalSUM, 
       COALESCE(invoice_Sum.TotalQ,0) as TotalQ
FROM (SELECT DISTINCT YEAR(InvoiceDate) as inv_Year, MONTH(InvoiceDate) as inv_Month
      FROM Sales.Invoices) as inv
LEFT JOIN (SELECT YEAR(inv_1.InvoiceDate) as inv1_Year, MONTH(inv_1.InvoiceDate) as Inv1_Month, 
		   MIN(inv_1.InvoiceDate) AS First_Invoice,
           inlines.Description, SUM(inlines.Quantity*inlines.UnitPrice) AS TotalSUM, SUM(inlines.Quantity) AS TotalQ
           FROM Sales.Invoices inv_1 
		   INNER JOIN Sales.InvoiceLines inlines ON inv_1.InvoiceID = inlines.InvoiceID
		   GROUP BY YEAR(inv_1.InvoiceDate), MONTH(inv_1.InvoiceDate), inlines.Description
		   HAVING SUM(inlines.Quantity) < 50 ) as invoice_Sum on invoice_Sum.inv1_Month = inv.inv_Month 
           and invoice_Sum.inv1_Year = inv.inv_Year

-- Выберите сотрудников, которые являются продажниками и еще не сделали ни одной продажи
-- DERIVED
DESC WITH SalesPerson as (SELECT DISTINCT SalespersonPersonID
				  FROM Sales.Orders)
SELECT FullName
FROM Application.People
WHERE IsSalesperson = 1 and PersonID not in (SELECT SalespersonPersonID
FROM SalesPerson)

-- SIMPLE - отработал оптимизатор
desc SELECT FullName
FROM  Application.People
WHERE IsSalesperson = 1 
	  and PersonID not in (SELECT DISTINCT SalespersonPersonID
						   FROM Sales.Orders)

-- посмотрим разницу по времени
EXPLAIN ANALYZE SELECT FullName
FROM  Application.People
WHERE IsSalesperson = 1 
	  and PersonID not in (SELECT DISTINCT SalespersonPersonID
						   FROM Sales.Orders);

EXPLAIN ANALYZE WITH SalesPerson as (SELECT DISTINCT SalespersonPersonID
				  FROM Sales.Orders)
SELECT FullName
FROM Application.People
WHERE IsSalesperson = 1 and PersonID not in (SELECT SalespersonPersonID
FROM SalesPerson);

-- ANALYZE сбор статистики
analyze TABLE Application.People;
analyze TABLE Application.countries;
use information_schema;
SELECT * FROM innodb_TABLEstats WHERE name like 'Application%';
-- сбор статистики происходит в моммент 1 обращения к таблице
SELECT * FROM Application.People;
SELECT * FROM innodb_TABLEstats WHERE name like 'Application%';
-- подробная статистика 
SELECT * FROM statistics WHERE TABLE_name = 'People';

analyze TABLE Application.People UPDATE HISTOGRAM ON FullName;
SELECT * FROM column_statistics WHERE TABLE_name = 'People'; -- гистограммы
SELECT JSON_PRETTY(HISTOGRAM) FROM column_statistics WHERE TABLE_name = 'People';

-- тюнинг оптимизатора
SELECT @@optimizer_switch;

-- трейс оптимизатора
SET optimizer_trace="enabled=on";
-- количество хранимых трейсов - только для текущей сессии
set optimizer_trace_limit = 2;
SELECT * FROM Application.People;
SELECT * FROM INFORMATION_SCHEMA.OPTIMIZER_TRACE;
SET optimizer_trace="enabled=off";

-- profiling

SET profiling = 1;
SELECT * FROM Application.People;
SHOW profiles;
SHOW profile;
SHOW profile for query 4;

SELECT SQL_CALC_FOUND_ROWS inv.inv_Year, inv.inv_Month, invoice_Sum.First_Invoice AS First_Invoice,
       COALESCE(invoice_Sum.Description, '') as inv_Descr, 
       COALESCE(invoice_Sum.TotalSUM, 0) as TotalSUM, 
       COALESCE(invoice_Sum.TotalQ,0) as TotalQ
FROM (SELECT DISTINCT YEAR(InvoiceDate) as inv_Year, MONTH(InvoiceDate) as inv_Month
      FROM Sales.Invoices) as inv
LEFT JOIN (SELECT YEAR(inv_1.InvoiceDate) as inv1_Year, MONTH(inv_1.InvoiceDate) as Inv1_Month, 
		   MIN(inv_1.InvoiceDate) AS First_Invoice,
           inlines.Description, SUM(inlines.Quantity*inlines.UnitPrice) AS TotalSUM, SUM(inlines.Quantity) AS TotalQ
           FROM Sales.Invoices inv_1 
		   INNER JOIN Sales.InvoiceLines inlines ON inv_1.InvoiceID = inlines.InvoiceID
		   GROUP BY YEAR(inv_1.InvoiceDate), MONTH(inv_1.InvoiceDate), inlines.Description
		   HAVING SUM(inlines.Quantity) < 50 ) as invoice_Sum on invoice_Sum.inv1_Month = inv.inv_Month 
           and invoice_Sum.inv1_Year = inv.inv_Year

SHOW profiles;
SHOW profile for query 5;
SHOW profile ALL for query 5;
SHOW profile BLOCK IO for query 5;
SET profiling = 0;

-- slow log
SET GLOBAL slow_query_log = 1;
SET GLOBAL slow_launch_time = 1;

SELECT Invoices.InvoiceId, Invoices.InvoiceDate, Invoices.CustomerID, trans.TransactionAmount,
	(SELECT MAX(inr.TransactionAmount) -- коррелированный/зависимый подзапрос по таблице CustomerTransactions
	FROM Sales.CustomerTransactions AS inr
	JOIN Sales.Invoices AS InvoicesInner ON 
		InvoicesInner.InvoiceID = inr.InvoiceID
	WHERE inr.CustomerID = trans.CustomerId 
		AND InvoicesInner.InvoiceDate < '2014-01-01') AS MaxPerCustomer
FROM Sales.Invoices AS Invoices
JOIN Sales.CustomerTransactions AS trans
	ON Invoices.InvoiceID = trans.InvoiceID
WHERE Invoices.InvoiceDate < '2014-01-01'
ORDER BY Invoices.InvoiceId, Invoices.InvoiceDate

SHOW variables like 'slow%';

?? netdata
?? dpa