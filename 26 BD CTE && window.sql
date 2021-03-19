-- https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
-- импортировал без создания БД и получил эффект, что для каждой схемы своя бд
-- а в adventureworks2017 - все схемы исчезли

-- табличка инвойс с нумерацией по кастомеру
SELECT  InvoiceId, CustomerID, 
		ROW_NUMBER() OVER (ORDER BY CustomerID)
FROM Sales.Invoices;

-- с разделением по катомерам
SELECT  InvoiceId, CustomerID, 
		ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY CustomerID)
FROM Sales.Invoices;

-- но при этом не гарантирована сортировка по полю InvoiceID, поэтому
SELECT  InvoiceId, CustomerID, 
		ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY CustomerID, InvoiceID)
FROM Sales.Invoices;

-- табличка инвойс с ранжированием по кастомеру
SELECT  InvoiceId, CustomerID, 
		RANK() OVER (ORDER BY CustomerID)
FROM Sales.Invoices;

-- табличка инвойс с ранжированием по кастомеру
SELECT  InvoiceId, CustomerID, 
		dense_rank() OVER (ORDER BY CustomerID)
FROM Sales.Invoices;

-- разобьем по дате, отсортируем по покупателю, при этом не будет сортировки по InvoiceID
SELECT  InvoiceId, InvoiceDate, CustomerID, 
		RANK() OVER (ORDER BY CustomerID)
FROM Sales.Invoices;

-- теперь посмотрим все это вместе
SELECT  InvoiceId, CustomerID, 
		ROW_NUMBER() OVER (ORDER BY CustomerID),
		RANK() OVER (ORDER BY CustomerID),
		dense_rank() OVER (ORDER BY CustomerID)
FROM Sales.Invoices;

-- Ntile - разбивает на примерно равные группы
SELECT UnitPrice, SupplierID, StockItemID, StockItemName, ColorId,
	ROW_NUMBER() OVER (ORDER BY UnitPrice) AS Rn,
	RANK() OVER (ORDER BY UnitPrice) AS Rnk,
	DENSE_RANK() OVER (PARTITION BY SupplierId ORDER BY UnitPrice) AS DenseRnk,
	NTILE(50) OVER (ORDER BY UnitPrice) AS GroupNumber
FROM Warehouse.StockItems
WHERE SupplierID in (5, 7)
ORDER By NTILE(50) OVER (ORDER BY UnitPrice);

-- сколько всего строк
SELECT count(*) FROM Warehouse.StockItems
WHERE SupplierID in (5, 7);

-- !!! обязательно указывайте одинаковое окно !!! 
SELECT  InvoiceId, CustomerID, 
		ROW_NUMBER() OVER (ORDER BY CustomerID),
		RANK() OVER (ORDER BY CustomerID desc),
		dense_rank() OVER (ORDER BY CustomerID)
FROM Sales.Invoices;

-- !!! и также указывайте сортировку в самом запросе !!!
-- если не хотите сайд эффектов
SELECT  InvoiceId, CustomerID, 
		ROW_NUMBER() OVER (ORDER BY CustomerID),
		RANK() OVER (ORDER BY CustomerID desc),
		dense_rank() OVER (ORDER BY CustomerID)
FROM Sales.Invoices
ORDER BY CustomerID;

-- заказы и оплаты по заказам через джойн
SELECT Invoices.InvoiceId, Invoices.InvoiceDate, Invoices.CustomerID, trans.TransactionAmount
FROM Sales.Invoices AS Invoices
JOIN Sales.CustomerTransactions AS trans
	ON Invoices.InvoiceID = trans.InvoiceID
WHERE Invoices.InvoiceDate < '2014-01-01'
ORDER BY Invoices.InvoiceId, Invoices.InvoiceDate;

-- заказы и оплаты по заказам с максимальной суммой заказа за год
SELECT Invoices.InvoiceId, Invoices.InvoiceDate, Invoices.CustomerID, trans.TransactionAmount,
	(SELECT MAX(inr.TransactionAmount) -- коррелированный/зависимый подзапрос по таблице CustomerTransactions
	FROM Sales.CustomerTransactions AS inr
	JOIN Sales.Invoices AS InvoicesInner ON 
		InvoicesInner.InvoiceID = inr.InvoiceID
	WHERE inr.CustomerID = trans.CustomerId -- поле по которому следует разбить на окна
		AND InvoicesInner.InvoiceDate < '2014-01-01') AS MaxPerCustomer
FROM Sales.Invoices AS Invoices
JOIN Sales.CustomerTransactions AS trans
	ON Invoices.InvoiceID = trans.InvoiceID
WHERE Invoices.InvoiceDate < '2014-01-01'
ORDER BY Invoices.InvoiceId, Invoices.InvoiceDate;
-- 40 секунд + фетч 20 сек 
-- или через 30 секунд
-- Error Code: 2013. Lost connection to MySQL server during query
SHOW variables like '%timeout%';
SET GLOBAL net_read_timeout=360;
-- Также
-- New versions of MySQL WorkBench have an option to change specific timeouts.
-- For me it was under Edit → Preferences → SQL Editor → DBMS connection read time out (in seconds): 600
-- посмотрим аналогичный запрос в MSSQL - 1 секунда

-- заказы и оплаты по заказам с максимальной суммой покупки за год
SELECT Invoices.InvoiceId, Invoices.InvoiceDate, Invoices.CustomerID, trans.TransactionAmount,
	-- без сортировки, т.к.max
	MAX(trans.TransactionAmount) OVER (PARTITION BY trans.CustomerId) AS MaxPerCustomer 
FROM Sales.Invoices AS Invoices
JOIN Sales.CustomerTransactions AS trans
	ON Invoices.InvoiceID = trans.InvoiceID
WHERE Invoices.InvoiceDate < '2014-01-01'
ORDER BY Invoices.InvoiceId, Invoices.InvoiceDate;


-- partition отсортирован DESC, а итоговый результат ASC
-- например можем отобрать 3 минимальных или максимальных заказа в зависимости от сортировки
SELECT Invoices.InvoiceId, Invoices.InvoiceDate, Invoices.CustomerID, trans.TransactionAmount,
	--	MAX(trans.TransactionAmount) OVER (PARTITION BY trans.CustomerId) AS MaxPerCustomer,
	ROW_NUMBER() OVER (PARTITION BY Invoices.CustomerId 
						ORDER BY trans.TransactionAmount DESC) AS RowNumberByPaymentAmount
FROM Sales.Invoices as Invoices
	JOIN Sales.CustomerTransactions as trans
		ON Invoices.InvoiceID = trans.InvoiceID
WHERE Invoices.InvoiceDate < '2014-01-01'
and Invoices.CustomerID IN ( 121, 126)
-- ORDER BY Invoices.InvoiceID; -- получим ерунду
-- ORDER BY Invoices.CustomerId, trans.TransactionAmount DESC;
ORDER BY Invoices.CustomerId, trans.TransactionAmount ASC;

-- заказы и оплаты по заказам с максимальной суммой за год
-- с сортировкой по сумме
-- сумма по кастомеру с партицией и без
SELECT Invoices.InvoiceId, Invoices.InvoiceDate, Invoices.CustomerID, trans.CustomerId, trans.TransactionAmount,
	MAX(trans.TransactionAmount) OVER (PARTITION BY trans.CustomerId) as max1,
	ROW_NUMBER() OVER (PARTITION BY Invoices.CustomerId ORDER BY trans.TransactionAmount DESC) as max2,
	SUM(trans.TransactionAmount) OVER () as sum1, -- по всей выборке сразу
	SUM(trans.TransactionAmount) OVER (PARTITION BY trans.CustomerId) as sumPart
FROM Sales.Invoices as Invoices
	JOIN Sales.CustomerTransactions as trans
		ON Invoices.InvoiceID = trans.InvoiceID
WHERE Invoices.InvoiceDate < '2014-01-01'
and Invoices.CustomerID IN ( 958, 121)
ORDER BY Invoices.CustomerID, trans.TransactionAmount DESC;

-- ошибка - почему?
SELECT Invoices.CustomerID,SUM(trans.TransactionAmount), SUM(trans.TransactionAmount) OVER ()
FROM Sales.Invoices as Invoices
	JOIN Sales.CustomerTransactions as trans
		ON Invoices.InvoiceID = trans.InvoiceID
WHERE Invoices.InvoiceDate < '2014-01-01'
and Invoices.CustomerID IN ( 958, 121)
GROUP BY Invoices.CustomerID, SUM(trans.TransactionAmount) OVER ();



-- ошибка - Оконные функции могут использоваться только в предложениях SELECT или ORDER BY

-- посмотрим транзакции для кастомеров с предудыщими и последующими строками
SELECT Invoices.InvoiceId, Invoices.InvoiceDate, Invoices.CustomerID, trans.TransactionAmount,
	LAG(trans.TransactionAmount) OVER (ORDER BY Invoices.InvoiceId, Invoices.InvoiceDate) as prev,
	-- так как мы не указали количество смещения - по умолчанию 1, NULL т.к.default не указали
	LEAD(trans.TransactionAmount) OVER (ORDER BY Invoices.InvoiceId, Invoices.InvoiceDate) as Follow ,
	MAX(trans.TransactionAmount) OVER (PARTITION BY trans.CustomerId),
	ROW_NUMBER() OVER (PARTITION BY Invoices.CustomerId ORDER BY trans.TransactionAmount DESC) -- номер при сортировке по продаже
FROM Sales.Invoices as Invoices
	JOIN Sales.CustomerTransactions as trans
		ON Invoices.InvoiceID = trans.InvoiceID
WHERE Invoices.InvoiceDate < '2014-01-01'
and Invoices.CustomerID IN (958, 121)
ORDER BY Invoices.InvoiceId, Invoices.InvoiceDate;

-- то же самое, но с партиционированием, но сортировкой отличной от сортировки смещения
SELECT Invoices.InvoiceId, Invoices.InvoiceDate, Invoices.CustomerID,Invoices.BillToCustomerID, trans.TransactionAmount,
	LAG(trans.TransactionAmount) OVER (PARTITION BY Invoices.CustomerId ORDER BY Invoices.InvoiceId, Invoices.InvoiceDate) as prev,
	LEAD(trans.TransactionAmount) OVER (PARTITION BY Invoices.CustomerId ORDER BY Invoices.InvoiceId, Invoices.InvoiceDate) as Follow ,
	MAX(trans.TransactionAmount) OVER (PARTITION BY trans.CustomerId) as max1,
	ROW_NUMBER() OVER (PARTITION BY Invoices.CustomerId ORDER BY trans.TransactionAmount DESC) as rowNumber
-- ROW_NUMBER() OVER (PARTITION BY Invoices.CustomerId ORDER BY Invoices.InvoiceId, Invoices.InvoiceDate)
FROM Sales.Invoices as Invoices
	JOIN Sales.CustomerTransactions as trans
		ON Invoices.InvoiceID = trans.InvoiceID
WHERE Invoices.InvoiceDate < '2014-01-01'
and Invoices.CustomerID in (958, 884)
ORDER BY trans.TransactionAmount DESC;
-- ORDER BY Invoices.InvoiceId, Invoices.InvoiceDate;

-- выведем топ 3 заказа для каждого кастомера
-- очень просто, но очень ДОРОГО, так как сначала мы все пронумеруем, а потом выберем только 3
SELECT *
FROM 
	(SELECT Invoices.InvoiceId, Invoices.InvoiceDate, Invoices.CustomerID, trans.TransactionAmount,
			ROW_NUMBER() OVER (PARTITION BY Invoices.CustomerId ORDER BY trans.TransactionAmount DESC) AS CustomerTransRank
		FROM Sales.Invoices as Invoices
			JOIN Sales.CustomerTransactions as trans
				ON Invoices.InvoiceID = trans.InvoiceID
	) AS tbl
WHERE CustomerTransRank <= 3
order by CustomerID, TransactionAmount desc;

-- реализуем аналог оффсета
SET @pages = 2;
SET @pageSize = 20;

WITH InvoiceLinePage AS
(
	SELECT I.InvoiceID, 
		I.InvoiceDate, 
		I.SalespersonPersonID, 
		L.Quantity, 
		L.UnitPrice,
		ROW_NUMBER() OVER (Order by InvoiceLineID) AS rowNumber
	FROM Sales.Invoices AS I
		JOIN Sales.InvoiceLines AS L 
			ON I.InvoiceID = L.InvoiceID
)
SELECT *
FROM InvoiceLinePage
WHERE rowNumber Between (@pages-1)*@pageSize + 1 
	AND @pages*@pageSize;

-- запрос по списку товаров, отсортировано по цене товара
SELECT SupplierID, StockItemID, StockItemName,UnitPrice,
	LAG(UnitPrice) OVER (ORDER BY UnitPrice) AS lagv,
	LEAD(UnitPrice) OVER (ORDER BY UnitPrice) AS leadv,
    NTH_VALUE(UnitPrice,3) OVER (ORDER BY UnitPrice) AS nth, -- в первых 2 записях NULL, так как внутренняя сортировка и их еще нет
    NTH_VALUE(UnitPrice,3) OVER () AS nth, -- имеет смысл указать полное окно, если сразу хотим получить значение
	FIRST_VALUE(UnitPrice) OVER (ORDER BY UnitPrice) AS f,
	-- ограничим фрейм
    LAST_VALUE(UnitPrice) OVER (ORDER BY UnitPrice) AS l_f, -- видим последнюю строчку из набора. с каждой строчкой набор увеличиватся
	LAST_VALUE(UnitPrice) OVER (ORDER BY UnitPrice ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) AS l,
	-- последнее значение на каждом наборе от 1 до текущей строки
	LAST_VALUE(UnitPrice) OVER () AS l_f2, -- если указываем без сортировки, то окно целиком
	LAST_VALUE(UnitPrice) OVER (ORDER BY NULL) AS l_test,
	LAST_VALUE(UnitPrice) OVER (ORDER BY 1/0) AS l2 -- чтобы получить окно целиком
FROM Warehouse.StockItems
WHERE SupplierID = 7
ORDER By UnitPrice;

-- аггрегатные фукнции
SELECT SupplierID, ColorId, StockItemID, StockItemName,
	UnitPrice,
	SUM(UnitPrice) OVER() AS Total,
	SUM(UnitPrice) OVER(ORDER BY UnitPrice) AS RunningTotal, -- range, включает все записи из диапазона
    -- важный кейс для бухгалтерских отчетов
	-- если одинковые юнитпрайс по разному ведут
	SUM(UnitPrice) OVER(ORDER BY UnitPrice, StockItemID) AS RunningTotalSort, -- чтобы считал для каждой записи
	SUM(UnitPrice) OVER(ORDER BY StockItemID) AS RunningTotalSortBySID,
	AVG(UnitPrice) OVER() AS Total, -- range
	AVG(UnitPrice) OVER(ORDER BY UnitPrice) AS RunningAvg,
	AVG(UnitPrice) OVER(ORDER BY UnitPrice, StockItemID) AS RunningAvgSort,
	COUNT(UnitPrice) OVER() AS Total, -- range
	COUNT(UnitPrice) OVER(ORDER BY UnitPrice) AS RunningTotal,
	COUNT(UnitPrice) OVER(ORDER BY UnitPrice, StockItemID) AS RunningTotalSort
FROM Warehouse.StockItems
WHERE SupplierID in (5, 7)
ORDER By UnitPrice, StockItemID;

-- посмотрим с партиционированием
SELECT SupplierID, ColorId, StockItemID, StockItemName,
	UnitPrice,
	SUM(UnitPrice) OVER() AS Total,
	SUM(UnitPrice) OVER(ORDER BY UnitPrice) AS RunningTotal,
	SUM(UnitPrice) OVER(ORDER BY UnitPrice, StockItemID) AS RunningTotalSort,
    -- почему значения не для NULL одинаковые?
	SUM(UnitPrice) OVER(Partition BY ColorId ORDER BY UnitPrice) AS RunningTotalByColor, 
	SUM(UnitPrice) OVER(ORDER BY UnitPrice, StockItemID ROWS UNBOUNDED PRECEDING) AS TotalBoundP,
	SUM(UnitPrice) OVER(ORDER BY UnitPrice, StockItemID ROWS BETWEEN CURRENT row AND UNBOUNDED Following) AS TotalBoundF,
	SUM(UnitPrice) OVER(ORDER BY UnitPrice DESC, StockItemID DESC) AS TotalBoundF2,
	SUM(UnitPrice) OVER(ORDER BY UnitPrice, StockItemID ROWS 2 PRECEDING) AS TotalBound2,
	SUM(UnitPrice) OVER(ORDER BY UnitPrice, StockItemID ROWS BETWEEN 2 PRECEDING AND 3 Following) AS TotalBound4,
	SUM(UnitPrice) OVER(ORDER BY UnitPrice RANGE UNBOUNDED PRECEDING) AS TotalBoundRange,
	SUM(UnitPrice) OVER(ORDER BY UnitPrice RANGE BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) AS TotalBoundRange,
    -- не включая текущую строчку
	SUM(UnitPrice) OVER(ORDER BY UnitPrice, StockItemID ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING) AS TotalBoundPrec
FROM Warehouse.StockItems
WHERE SupplierID in (5, 7)
ORDER By UnitPrice, StockItemID;

-- можно задать единое окно для всего запроса, в отличии от того же MSSQL
SELECT SupplierID, ColorId, StockItemID, StockItemName,
	UnitPrice,
	SUM(UnitPrice) OVER w AS Total,
	AVG(UnitPrice) OVER w AS Average
FROM Warehouse.StockItems
WHERE SupplierID in (5, 7)
WINDOW w AS (Partition BY ColorId ORDER BY UnitPrice) -- нельзя указать в order by %(
ORDER By UnitPrice, StockItemID;

-- поиск пропуска в последовательности
SELECT StockItemID + 1
FROM (
	SELECT  StockItemID, LEAD(StockItemID) over (order by StockItemID) LAST_NUM
	FROM Warehouse.StockItems
) a1
WHERE StockItemID + 1 != LAST_NUM;

SELECT max(StockItemID) FROM Warehouse.StockItems;

INSERT INTO Warehouse.StockItems(StockItemID, StockItemName, SupplierID, UnitPackageID, OuterPackageID, LeadTimeDays, 
	QuantityPerOuter, IsChillerStock, TaxRate, UnitPrice,TypicalWeightPerUnit, SearchDetails, LastEditedBy, ValidFROM, ValidTo) 
VALUES (229, 'test', 1, 1, 1, 1, 1, true, 0, 1, 0, '', 1, now(), now());

INSERT INTO Warehouse.StockItems(StockItemID, StockItemName, SupplierID, UnitPackageID, OuterPackageID, LeadTimeDays, 
	QuantityPerOuter, IsChillerStock, TaxRate, UnitPrice,TypicalWeightPerUnit, SearchDetails, LastEditedBy, ValidFROM, ValidTo) 
VALUES (232, 'test2', 1, 1, 1, 1, 1, true, 0, 1, 0, '', 1, now(), now());

delete FROM Warehouse.StockItems WHERE StockItemID = 229 or StockItemID = 232;

-- CTE
with cte as (
  SELECT 1 as col1, 2 as col2
  )
SELECT * FROM cte;

-- можем задать имена возвращаемых значений
with cte(col1, col2) as (
  SELECT 1, 2
  )
SELECT * FROM cte;

-- union с самим собой
with cte as (
  SELECT 1 as col1, 2 as col2
  union
  SELECT 3 as col1, 4 as col2
)
SELECT * FROM cte
union all
SELECT * FROM cte;

-- посмотрим сложный запрос с вложенным подзапросом
SELECT P.PersonID, P.FullName, I.SalesCount
FROM Application.People AS P
	JOIN
	(SELECT SalespersonPersonID, Count(InvoiceId) AS SalesCount
	FROM Sales.Invoices
	WHERE InvoiceDate >= '20140101'
		AND InvoiceDate < '20150101' 
	GROUP BY SalespersonPersonID) AS I
		ON P.PersonID = I.SalespersonPersonID;
		
WITH InvoicesCTE (SalespersonPersonID, SalesCount) AS 
(
	SELECT SalespersonPersonID, Count(InvoiceId) 
	FROM Sales.Invoices
	WHERE InvoiceDate >= '20140101'
		AND InvoiceDate < '20150101' 
	GROUP BY SalespersonPersonID
)
SELECT P.PersonID, P.FullName, I.SalesCount
FROM Application.People AS P
JOIN InvoicesCTE AS I
	ON P.PersonID = I.SalespersonPersonID;

-- запрос с подсчетом количества и продаж по менеджерам
WITH InvoicesCTE AS 
(
	SELECT SalespersonPersonID, Count(InvoiceId) AS SalesCount
	FROM Sales.Invoices
	WHERE InvoiceDate >= '20140101'
		AND InvoiceDate < '20150101' 
	GROUP BY SalespersonPersonID
),
InvoicesLinesCTE AS 
(
	SELECT Invoices.SalespersonPersonID, SUM(L.Quantity) AS TotalQuantity, SUM(L.Quantity*L.UnitPrice) AS TotalSumm
	FROM Sales.Invoices	
	JOIN Sales.InvoiceLines AS L
		ON Invoices.InvoiceID = L.InvoiceID
	GROUP BY Invoices.SalespersonPersonID
)
SELECT P.PersonID, P.FullName, I.SalesCount, L.TotalQuantity, L.TotalSumm
FROM Application.People AS P
JOIN InvoicesCTE AS I
	ON P.PersonID = I.SalespersonPersonID
JOIN InvoicesLinesCTE AS L
	ON P.PersonID = L.SalespersonPersonID
ORDER BY L.TotalSumm DESC, I.SalesCount DESC;

-- delete CTE
DROP TABLE IF EXISTS Sales.Invoices_DeleteDemo;

CREATE TABLE Sales.Invoices_DeleteDemo SELECT * FROM Sales.Invoices limit 300;

SELECT *
FROM Sales.Invoices_DeleteDemo
ORDER BY InvoiceID
LIMIT 100;

WITH OrdDelete AS
(	
	SELECT InvoiceId
	FROM Sales.Invoices_DeleteDemo
)
DELETE FROM OrdDelete;

-- рекурсивные СТЕ
WITH RECURSIVE cte (n) AS -- обязательно указывать рекурсию
(
  SELECT 1
  UNION ALL
  SELECT n + 1 FROM cte WHERE n < 50
)
SELECT * FROM cte;

-- ошибка без указания RECURSIVE
WITH cte AS
(
  SELECT 1 as n
  UNION ALL
  SELECT n + 1 FROM cte WHERE n < 5
)
SELECT * FROM cte;

-- ограничим максимальный уровень рекурсии
-- https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_cte_max_recursion_depth
SET SESSION cte_max_recursion_depth = 3;

-- ошибка, так как установлен максимальный уровень рекурсии 3
WITH RECURSIVE cte (n) AS
(
  SELECT 1
  UNION ALL
  SELECT n + 1 FROM cte WHERE n < 5
)
SELECT * FROM cte;

SET SESSION cte_max_recursion_depth = 1000;

-- заполним таблицу месяцами
SET @StartDate = '2013-01-01';
SET @EndDate = NOW();
with RECURSIVE cte_month as (SELECT @StartDate as pMonth
				   UNION ALL
				   SELECT DATE_ADD(pMonth, INTERVAL 1 MONTH)
				   FROM cte_month
				   WHERE pMonth < @EndDate)
SELECT * FROM cte_month;

-- продажи по месяцам
SET @StartDate = '2013-01-01';
SET @EndDate = NOW();
with RECURSIVE cte_month as (SELECT @StartDate as pMonth
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
ORDER BY cte_month.pMonth;

-- первая строка получилась 3 символа и остальные тоже будут обрезаны
WITH RECURSIVE cte AS
(
  SELECT 1 AS n, 'abc' AS str
  UNION ALL
  SELECT n + 1, CONCAT(str, str) FROM cte WHERE n < 3
)
SELECT * FROM cte;

SHOW VARIABLES LIKE 'sql_mode';
SET sql_mode = '';

-- можем сразу задать размер поля
WITH RECURSIVE cte AS
(
  SELECT 1 AS n, CAST('abc' AS CHAR(20)) AS str
  UNION ALL
  SELECT n + 1, CONCAT(str, str) FROM cte WHERE n < 3
)
SELECT * FROM cte;

-- можно указать хинты оптимизатору рекурсий
-- ошибки по выходу за лимиты
WITH RECURSIVE cte (n) AS
(
  SELECT 1
  UNION ALL
  SELECT n + 1 FROM cte
)
SELECT /*+ SET_VAR(cte_max_recursion_depth = 1M) */ * FROM cte;

WITH RECURSIVE cte (n) AS
(
  SELECT 1
  UNION ALL
  SELECT n + 1 FROM cte
)
SELECT /*+ MAX_EXECUTION_TIME(1000) */ * FROM cte;

-- примеры рекурсий из документации
-- https://dev.mysql.com/doc/refman/8.0/en/with.html#common-TABLE-expressions-recursive-examples
