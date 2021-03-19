use adventureworks2017;

desc salesterritoryhistory;
SHOW CREATE TABLE salesterritoryhistory;
-- PRIMARY KEY (`BusinessEntityID`,`TerritoryID`,`StartDate`),\n  UNIQUE KEY `AK_SalesTerritoryHistory_rowguid` (`rowguid`),\n  KEY `FK_SalesTerritoryHistory_SalesTerritory_TerritoryID` (`TerritoryID`),\n  CONSTRAINT `FK_SalesTerritoryHistory_SalesPerson_BusinessEntityID` FOREIGN KEY (`BusinessEntityID`) REFERENCES `salesperson` (`BusinessEntityID`),\n  CONSTRAINT `FK_SalesTerritoryHistory_SalesTerritory_TerritoryID` FOREIGN KEY (`TerritoryID`) REFERENCES `salesterritory` (`TerritoryID`)\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT=\'Sales representative transfers to other sales territories.\''

-- MUL - на поле несколько индексов
desc salesorderdetail;

SHOW index FROM salesorderdetail;

-- будет ли использоваться индекс при таком запросе?
SELECT * FROM salesorderdetail WHERE SalesOrderDetailID = 1;


-- нет, так как он на 2 месте и SalesOrderID в этом запросе не используется.
explain SELECT * FROM salesorderdetail WHERE SalesOrderDetailID = 1;

-- а в этом случае?
SELECT * FROM salesorderdetail WHERE SalesOrderID between 100 and 200 and SalesOrderDetailID = 1;

explain SELECT * FROM salesorderdetail WHERE SalesOrderID between 100 and 200 and SalesOrderDetailID = 1;

-- посмотрим теперь поиск с отрицанием
explain SELECT * FROM salesorderdetail WHERE ProductID = 1; -- key IX_SalesOrderDetail_ProductID
explain SELECT * FROM salesorderdetail WHERE ProductID != 1; -- key NULL

-- посмотрим на использование индексов и OR
explain SELECT * FROM salesorderdetail WHERE ProductID = 1 or SalesOrderID=1;
-- Using union(IX_SalesOrderDetail_ProductID,PRIMARY); Using where
explain SELECT * FROM salesorderdetail WHERE ProductID = 1 and SalesOrderID=1;
-- только 1 индекс а потом перебор filtered 5
-- разницы в очередности полей в WHERE нет
explain SELECT * FROM salesorderdetail WHERE SalesOrderID=1 and ProductID = 1;
-- индекс выбирается по наибольшей селективности
SHOW index FROM salesorderdetail;
-- SalesOrderID 30846 ProductID 257

-- но как обычно мы можем написать хинт
-- https://dev.mysql.com/doc/refman/8.0/en/index-hints.html
explain SELECT * FROM salesorderdetail USE INDEX(IX_SalesOrderDetail_ProductID) WHERE SalesOrderID=1 and ProductID = 1;

-- посмотрим на индекс по бинарному полю
drop TABLE if exists test_blob;
CREATE TABLE test_blob (b blob);
CREATE index idx_blob on test_blob(b(100));
SHOW index FROM test_blob;

-- ---------------------------
-- Functional Key Parts
CREATE TABLE t1 (
  col1 VARCHAR(10),
  col2 VARCHAR(20),
  INDEX (col1, col2(10))
);

-- MySQL 8.0.13 and higher supports functional key parts that index expression VALUES rather than column 
-- or column prefix values. Use of functional key parts enables indexing of VALUES not stored directly in the TABLE

CREATE TABLE t1 (col1 INT, col2 INT, INDEX func_index ((ABS(col1))));
CREATE INDEX idx1 ON t1 ((col1 + col2));
CREATE INDEX idx2 ON t1 ((col1 + col2), (col1 - col2), col1);
ALTER TABLE t1 ADD INDEX ((col1 * 40) DESC);


CREATE TABLE tbl (
  col1 LONGTEXT,
  INDEX idx1 ((SUBSTRING(col1, 1, 10)))
);
INSERT INTO tbl VALUES ('123456789'),('1234567890'),('12345678901');
-- увидим, что индекс по функции не используется
explain SELECT * FROM tbl WHERE col1 = '123';

-- теперь используем разные параметры у фукнции
SELECT * FROM tbl WHERE SUBSTRING(col1, 1, 9) = '123456789';
SELECT * FROM tbl WHERE SUBSTRING(col1, 1, 10) = '1234567890';
SELECT * FROM tbl WHERE SUBSTRING(col1, 1, 10) = '12345678901';

-- во 2 случае мы используем индекс
explain SELECT * FROM tbl WHERE SUBSTRING(col1, 1, 9) = '123456789';
explain SELECT * FROM tbl WHERE SUBSTRING(col1, 1, 10) = '1234567890';

-- --------------------
-- индекс по полю в JSON
drop TABLE if exists employees;
CREATE TABLE employees (
  data JSON,
  INDEX ((data->>'$.name'))
);

--  The syntax fails because:
-- The ->> operator translates INTO JSON_UNQUOTE(JSON_EXTRACT(...)).
-- JSON_UNQUOTE() returns a value with a data type of LONGTEXT, and the hidden generated column thus is assigned the same data type.
-- MySQL cannot index LONGTEXT columns specified without a prefix length on the key part, and prefix lengths are not permitted in functional key parts. 

-- правильно
CREATE TABLE employees (
  data JSON,
  INDEX ((CAST(data->>'$.name' AS CHAR(30))))
);
INSERT INTO employees VALUES
  ('{ "name": "james", "salary": 9000 }'),
  ('{ "name": "James", "salary": 10000 }'),
  ('{ "name": "Mary", "salary": 12000 }'),
  ('{ "name": "Peter", "salary": 8000 }');
SELECT * FROM employees WHERE data->>'$.name' = 'James';
SELECT * FROM employees WHERE CAST(data->>'$.name' AS CHAR(30)) = 'James';

-- посмотрим на использование индексов
explain SELECT * FROM employees WHERE data->>'$.name' = 'James';
explain SELECT * FROM employees WHERE CAST(data->>'$.name' AS CHAR(30)) = 'James';

-- cast use case insensitive charset
-- если все таки кейс важен
CREATE TABLE employees (
  data JSON,
  INDEX idx ((CAST(data->>"$.name" AS CHAR(30)) COLLATE utf8mb4_bin))
);

-- ------------------------
-- multi-valued Indexes
-- https://dev.mysql.com/doc/refman/8.0/en/CREATE-index.html#CREATE-index-multi-valued
-- {
--    "user":"Bob",
--    "user_id":31,
--    "zipcode":[94477,94536] -- предназначено для поиска в таких массивах
-- }

drop TABLE if exists customers;
CREATE TABLE customers (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    modified DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    custinfo JSON
--    ,INDEX zips( (CAST(custinfo->'$.zip' AS UNSIGNED ARRAY)) )
    );
INSERT INTO customers VALUES
    (NULL, NOW(), '{"user":"Jack","user_id":37,"zipcode":[94582,94536]}'),
    (NULL, NOW(), '{"user":"Jill","user_id":22,"zipcode":[94568,94507,94582]}'),
    (NULL, NOW(), '{"user":"Bob","user_id":31,"zipcode":[94477,94507]}'),
    (NULL, NOW(), '{"user":"Mary","user_id":72,"zipcode":[94536]}'),
    (NULL, NOW(), '{"user":"Ted","user_id":56,"zipcode":[94507,94582]}');
  
-- посмотрим на запросы
SELECT * FROM customers WHERE 94507 MEMBER OF(custinfo->'$.zipcode');
SELECT * FROM customers WHERE JSON_CONTAINS(custinfo->'$.zipcode', CAST('[94507,94582]' AS JSON));  
SELECT * FROM customers WHERE JSON_OVERLAPS(custinfo->'$.zipcode', CAST('[94507,94582]' AS JSON));

-- посмотрим на их explane
explain SELECT * FROM customers WHERE 94507 MEMBER OF(custinfo->'$.zipcode');
explain SELECT * FROM customers WHERE JSON_CONTAINS(custinfo->'$.zipcode', CAST('[94507,94582]' AS JSON));  
explain SELECT * FROM customers WHERE JSON_OVERLAPS(custinfo->'$.zipcode', CAST('[94507,94582]' AS JSON));

-- добавим индекс
ALTER TABLE customers ADD INDEX zips( (CAST(custinfo->'$.zipcode' AS UNSIGNED ARRAY)) );

-- посмотрим эксплейны
explain SELECT * FROM customers WHERE 94507 MEMBER OF(custinfo->'$.zipcode');
explain SELECT * FROM customers WHERE JSON_CONTAINS(custinfo->'$.zipcode', CAST('[94507,94582]' AS JSON));  
explain SELECT * FROM customers WHERE JSON_OVERLAPS(custinfo->'$.zipcode', CAST('[94507,94582]' AS JSON));

-- сделаем уникальный индекс по массиву
ALTER TABLE customers DROP INDEX zips;
ALTER TABLE customers ADD UNIQUE INDEX zips((CAST(custinfo->'$.zipcode' AS UNSIGNED ARRAY)));
-- вернем старый 
ALTER TABLE customers ADD INDEX zips((CAST(custinfo->'$.zipcode' AS UNSIGNED ARRAY)));



-- ------------------------
-- полнотекстовый поиск
 drop DATABASE if exists ind;
 CREATE DATABASE ind;
 use ind;
 
 -- Полнотекстовый поиск выполняется с помощью функции MATCH().

drop TABLE if exists articles;
CREATE TABLE articles (
        id INT UNSIGNED AUTO_INCREMENT NOT NULL PRIMARY KEY,
        title VARCHAR(200),
        body TEXT,
        FULLTEXT (title,body)
        );
INSERT INTO articles VALUES
        (0,'MySQL Tutorial', 'DBMS stands for DATABASE ...'),
        (0,'How To Use MySQL Efficiently', 'After you went through a ...'),
        (0,'Optimising MySQL','In this tutorial we will SHOW ...'),
        (0,'1001 MySQL Trick','1. Never run mysqld as root. 2. ...'),
        (0,'MySQL vs. YourSQL', 'In the following DATABASE comparison ...'),
        (0,'MySQL Security', 'When configured properly, MySQL ...');

SELECT * FROM articles WHERE MATCH (title,body) AGAINST ('database');

SELECT * FROM articles WHERE MATCH (title,body) AGAINST ('database' IN NATURAL LANGUAGE MODE);
SELECT * FROM articles WHERE MATCH (title,body) AGAINST ('database' WITH QUERY EXPANSION);

SELECT * FROM articles WHERE MATCH (title,body) AGAINST ('you go');
-- нашел you WENT

-- можем извлекать величины релевантности в явном виде. В случае отсутствия выражений WHERE и ORDER BY 
-- возвращаемые строки не упорядочиваются.

SELECT id,MATCH (title,body) AGAINST ('Tutorial') FROM articles;

-- Запрос возвращает значение релевантности и, кроме того, сортирует строки в порядке убывания релевантности. 
-- Чтобы получить такой результат, необходимо указать MATCH() дважды. Это не приведет к дополнительным издержкам, 
-- так как оптимизатор MySQL учтет, что эти два вызова MATCH() идентичны, и запустит код полнотекстового поиска только однажды.

SELECT id, title, body, MATCH (title,body) AGAINST
    ('Security implications of running MySQL as root') AS score
FROM articles WHERE MATCH (title,body) AGAINST
    ('Security implications of running MySQL as root');
    
 -- Для разбивки текста на слова MySQL использует очень простой синтаксический анализатор. 
 -- ``Словом'' является любая последовательность символов, состоящая из букв, чисел, знаков `'' и `_'. 
 -- Любое ``слово'', присутствующее в стоп-списке (stopword) или просто слишком короткое (3 символа или меньше), игнорируется.
  SHOW variables like 'innodb_ft_min_token_size';

-- Каждое правильное слово в наборе проверяемых текстов и в данном запросе оценивается в соответствии с его важностью 
-- в этом запросе или наборе текстов. Таким образом, слово, присутствующее во многих документах, будет иметь меньший вес 
-- (и даже, возможно, нулевой), как имеющее более низкое смысловое значение в данном конкретном наборе текстов. 
-- С другой стороны, редко встречающееся слово получит более высокий вес. Затем полученные значения весов слов 
-- объединяются для вычисления релевантности данной строки столбца. 

-- Описанная техника подсчета лучше всего работает для больших наборов текстов 
-- (фактически она именно для этого тщательно настраивалась). Для очень малых таблиц распределение слов 
-- не отражает адекватно их смысловое значение, и данная модель иногда может выдавать некорректные результаты.

SELECT * FROM articles WHERE MATCH (title,body) AGAINST ('MySQL');    
-- в myISAM запрос бы не вернул ни 1 строки, так как MySQL присутствует более в 50% запросов
-- для такого случая есть вариант
SELECT * FROM articles WHERE MATCH (title,body)
    AGAINST ('+MySQL -YourSQL' IN BOOLEAN MODE);
    
-- !!логический режим поиска не сортирует автоматически строки в порядке уменьшения релевантности
-- В логическом режиме полнотекстового поиска поддерживаются следующие операторы:
/*
+
    Предшествующий слову знак ``плюс'' показывает, что это слово должно присутствовать в каждой возвращенной строке. 
-
    Предшествующий слову знак ``минус'' означает, что это слово не должно присутствовать в какой-либо возвращенной строке. 
    По умолчанию (если ни плюс, ни минус не указаны) данное слово является не обязательным, но содержащие его строки будут оцениваться более высоко. Это имитирует поведение команды MATCH() ... AGAINST() без модификатора IN BOOLEAN MODE. 
< >
    Эти два оператора используются для того, чтобы изменить вклад слова в величину релевантности, которое приписывается строке. Оператор < уменьшает этот вклад, а оператор > - увеличивает его. См. пример ниже. 
( )
    Круглые скобки группируют слова в подвыражения. 
~
    Предшествующий слову знак ``тильда'' воздействует как оператор отрицания, обуславливая негативный вклад данного слова в релевантность строки. Им отмечают нежелательные слова. Строка, содержащая такое слово, будет оценена ниже других, но не будет исключена совершенно, как в случае оператора - ``минус''. 
*
    Звездочка является оператором усечения. В отличие от остальных операторов, она должна добавляться в конце слова, а не в начале. 
"
    Фраза, заключенная в двойные кавычки, соответствует только строкам, содержащим эту фразу, написанную буквально. 

Ниже приведен ряд примеров:

apple banana
    находит строки, содержащие по меньшей мере одно из этих слов. 
+apple +juice
    ... оба слова. 
+apple macintosh
    ... слово ``apple'', но ранг строки выше, если она также содержит слово ``macintosh''. 
+apple -macintosh
    ... слово ``apple'', но не ``macintosh''. 
+apple +(>pie <strudel)
    ... ``apple'' и ``pie'', или ``apple'' и ``strudel'' (в любом порядке), но ранг ``apple pie'' выше, чем ``apple strudel''. 
apple*
    ... ``apple'', ``apples'', ``applesauce'', и ``applet''. 
"some words"
    ... ``some words of wisdom'', но не ``some noise words''. 
*/
-- метаданные
SELECT * FROM INFORMATION_SCHEMA.INNODB_FT_CONFIG;
SELECT * FROM INFORMATION_SCHEMA.INNODB_FT_INDEX_CACHE;
SELECT * FROM INFORMATION_SCHEMA.INNODB_FT_INDEX_TABLE;
SELECT * FROM INFORMATION_SCHEMA.INNODB_FT_DEFAULT_STOPWORD;
SELECT * FROM INFORMATION_SCHEMA.INNODB_FT_DELETED;
SELECT * FROM INFORMATION_SCHEMA.INNODB_FT_BEING_DELETED;



-- --------------
-- Статистика
use information_schema;
SHOW TABLEs;
SELECT * FROM information_schema.innodb_TABLEstats;
SELECT * FROM mysql.innodb_TABLE_stats;
-- посмотреть всю информацию
SELECT * FROM information_schema.statistics;

SHOW variables like 'innodb_stats_auto_recalc';
SHOW variables like 'innodb_stats_persistent_sample_pages'; -- случайно выбирает количество страниц для анализа
SHOW variables like 'innodb_stats_persistent';

SELECT * FROM sys.schema_unused_indexes; -- неиспользуемые
SELECT * FROM sys.schema_redundant_indexes; -- избыточные
SELECT * FROM sys.schema_index_statistics;


use ind;
ANALYZE TABLE articles;

