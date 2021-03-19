SELECT 1+1;
SELECT 1+1 FROM dual;
SELECT 1 + 1 as summ;

drop DATABASE if exists otus;
CREATE DATABASE if not exists otus;
-- что будет, если не указать if not exists 
CREATE DATABASE otus;
use otus;
CREATE TABLE if not exists items (itemname varchar(128) primary key, 
		price decimal(19,4), 
		quantity int);
		
CREATE TABLE if not exists sales (saleid serial primary key,
	itemname varchar(128), 
	quantity int, 
	price decimal(19,4), 
	salesdate timestamp);
truncate items;
truncate sales;

INSERT INTO items
(itemname, price, quantity)
VALUES 
('Яблоки', 50, 200),
('Груши', 100, 324),
('Сливы', 100, 121),
('Мандарины', 150, 350),
('Виноград', 200, 56);

INSERT INTO sales
(itemname, quantity, price, salesdate)
VALUES 
('Яблоки', 2, 100, '20190101'),
('Груши', 3, 300, '20190501'),
('Яблоки', 1, 100, '20190601'),
('Стул', 1, 1000, '20190607');

SELECT * FROM sales;
SELECT * FROM sales limit 1 offset 1;
SELECT FOUND_ROWS();

-- опции указываются через пробел
SELECT SQL_CALC_FOUND_ROWS SQL_BIG_RESULT * FROM sales limit 1 offset 1;
SELECT FOUND_ROWS();

-- SQL_CALC_FOUND_ROWS быстрее чем count
SELECT count(*) FROM sales;

-- интересный результат, если сразу включить в запрос
SELECT SQL_CALC_FOUND_ROWS *, FOUND_ROWS() FROM sales limit 1 offset 1;

SELECT SQL_CALC_FOUND_ROWS *, FOUND_ROWS() FROM sales;

-- пожем использовать подготовленные выражения
SET @a=1;
PREPARE STMT FROM 'SELECT * FROM sales LIMIT ?';
EXECUTE STMT USING @a;

SET @skip=1; SET @numrows=1;
PREPARE STMT FROM 'SELECT * FROM sales LIMIT ?, ?';
EXECUTE STMT USING @skip, @numrows;


-- insert
SELECT * FROM sales;
-- несмотря на то, что данный запрос отработает, лучше указывать конкретные поля, куда вставляем данные
-- порядок полей всегда может поменяться и у нас все поломается
INSERT INTO sales VALUES (5, 'Капуста', 1, 100, '20200723');
INSERT INTO sales (itemname, quantity, price, salesdate) VALUES ('Капуста', 10, 200, '20200724');

-- ошибка
INSERT INTO sales VALUES (5, 'Капуста', 1, 100, '20200723');
-- так все ок
INSERT INTO sales VALUES (5, 'Капуста', 1, 100, '20200723') on duplicate key UPDATE quantity = quantity + 1;

CREATE TABLE if not exists items2 (itemname varchar(128) primary key, 
		price decimal(19,4), 
		quantity int);
truncate items2;

SELECT * FROM items WHERE price > 100;

INSERT INTO items2
SELECT * FROM items WHERE price > 100;

SELECT * FROM items2;

-- не сработает, так как дубликат ключа
INSERT INTO items2 (itemname)
SELECT itemname FROM items WHERE price > 100;

truncate items2;

INSERT INTO items2 (itemname)
SELECT itemname FROM items WHERE price > 100;

-- можем в новую таблицу вставить данные, но при этом доп.структура не создается
CREATE TABLE items3
SELECT * FROM items WHERE price > 100;
ALTER TABLE items3 add constraint aaa check (price > 0);
INSERT INTO items3 (itemname, price) VALUES ('киви', -100);
INSERT IGNORE INTO items3 (itemname, price) VALUES ('киви', -100);

SELECT * FROM items3;
SHOW CREATE TABLE items3;

-- ошибка
INSERT INTO sales VALUES (5, 'Капуста', 1, 100, '20200723');
-- можем проигнорировать дубликаты. например при залитии большого обьема батчами
INSERT IGNORE INTO sales VALUES (5, 'Капуста', 100, 100, '20200723');

-- попытаемся заменить несуществующий ключ
replace INTO sales VALUES (7, 'Капуста', 100, 100, '20200723');
SELECT * FROM sales;
replace INTO sales(saleid, itemname) VALUES (5, 'Капуста');
SELECT * FROM sales;
replace INTO sales(saleid, itemname, quantity, price, salesdate) VALUES (5, 'Капуста', 1, 100, '20200723');
SELECT * FROM sales;

-- update
-- ошибка
-- наш item3 без primary key и остального
UPDATE items3 
set quantity = quantity + 1;

-- тоже ошибка
UPDATE items3
set quantity = quantity + 1
WHERE itemname='Виноград';

-- пройдет - почему?
UPDATE items2
set quantity = quantity + 1
WHERE itemname='Виноград';
SELECT * FROM items2;

SHOW CREATE TABLE items3;
SHOW CREATE TABLE items2;

-- отключим безопасную вставку
SET SQL_SAFE_UPDATES = 0;

UPDATE items3 
set quantity = quantity + 1;
SELECT * FROM items3;

UPDATE items3 
set quantity = quantity + 1
order by itemname
limit 1;
SELECT * FROM items3;

UPDATE items3 
set quantity = quantity + 1
order by itemname desc -- в обратном порядке
limit 1;
SELECT * FROM items3;

-- обновим 2 поля
UPDATE items3 
set quantity = quantity + 1, price = 160;

SET SQL_SAFE_UPDATES = 1;

-- ошибка
SELECT * FROM items;

UPDATE items 
set itemname = 'Яблоки' 
WHERE itemname = 'Виноград';

UPDATE IGNORE items 
set itemname = 'Яблоки' 
WHERE itemname = 'Виноград';

SELECT * FROM items;

-- UPDATE + ignore
SHOW CREATE TABLE sales;
SELECT * FROM sales;
SET SQL_SAFE_UPDATES = 0;
-- попытаемся увеличить наше автоинкрементное поле на 1
UPDATE sales
set saleid = saleid + 1;
-- добавим IGNORE. что произойдет?
UPDATE IGNORE sales
set saleid = saleid + 1;

SELECT * FROM sales;
UPDATE IGNORE sales
set saleid = saleid + 5;

-- как думаете с каким id вставится киви?
INSERT INTO sales (itemname, quantity, price, salesdate) VALUES ('Киви', 10, 200, '20200724');
SELECT * FROM sales;
SET SQL_SAFE_UPDATES = 1;



-- delete 
delete FROM items2 WHERE itemname='Виноград';
SELECT * FROM items2;
-- без условия удаляется все с выключенным safe_update
delete FROM items3;
SET SQL_SAFE_UPDATES = 0;
delete FROM items3;
SELECT * FROM items3;
SET SQL_SAFE_UPDATES = 1;
-- на транкейт safe_UPDATE не влияет
truncate items3;

-- JOIN
-- что будет?
SELECT *
FROM items, sales;

SELECT *
FROM items
	full JOIN sales;

SELECT *
FROM items
	cross JOIN sales;

SELECT *
FROM items
	JOIN sales;

-- inner join
SELECT * FROM items;
SELECT * FROM sales;
SELECT *
FROM items
JOIN sales on items.itemname = sales.itemname;

SELECT *
FROM items
inner JOIN sales on items.itemname = sales.itemname;

SELECT *
FROM items, sales WHERE items.itemname = sales.itemname;

-- left join
SELECT *
FROM items
left JOIN sales on items.itemname = sales.itemname;

SELECT *
FROM items
left outer JOIN sales on items.itemname = sales.itemname;

-- rigth join
SELECT *
FROM items
right JOIN sales on items.itemname = sales.itemname;

SELECT *
FROM items
right outer JOIN sales on items.itemname = sales.itemname;

-- можно использовать > < != И другие условия! Иногда это нужно, но используется это редко
SELECT * 
FROM otus.items as items
JOIN otus.sales as sales
	on sales.price > items.price;

-- стандартная ошибка
SELECT * 
FROM otus.items as items
JOIN otus.sales as sales
	on items.itemname = sales.itemname
WHERE quantity > 10;

SELECT * 
FROM otus.items as items
JOIN otus.sales as sales
	on items.itemname = sales.itemname
WHERE items.quantity > 10;

-- посмотрим все товары
SELECT * 
FROM otus.items as items
left JOIN otus.sales as sales
	on items.itemname = sales.itemname;

-- отберем все товары без продаж. почему пусто?
SELECT * 
FROM otus.items as items
left JOIN otus.sales as sales
	on items.itemname = sales.itemname
WHERE sales.itemname = NULL;



-- теперь правильно %)
SELECT * 
FROM otus.items as items
left JOIN otus.sales as sales
	on items.itemname = sales.itemname
WHERE sales.itemname is NULL;

-- подзапросы
SELECT * FROM (
  SELECT * FROM items i WHERE i.price > 100
) ttt;

-- зависимый подзапрос
SELECT s.itemname, (
  SELECT itemname FROM items i WHERE i.itemname = s.itemname
) ttt 
FROM sales s;

-- ошибка - есть 2 строки яблок в подзапросе
SELECT i.itemname, (
  SELECT itemname FROM sales s WHERE i.itemname = s.itemname
) ttt 
FROM items i;

-- одно из решений указать limit 1
SELECT i.itemname, (
  SELECT itemname FROM sales s WHERE i.itemname = s.itemname limit 1
) ttt 
FROM items i;

-- джойним запрос с подзапросом
SELECT ttt.*, s.* FROM (
  SELECT * FROM items i WHERE i.price > 10
) ttt
left JOIN sales s on ttt.itemname = s.itemname;

-- where
SELECT * 
FROM items
WHERE price > 100 and price < 200;

SELECT * 
FROM items
WHERE (price > 100) 
	and (price < 200);

SELECT * 
FROM items
WHERE price between 100 and 150;

SELECT * 
FROM items
WHERE price >= 100 and price <= 150;

SELECT * FROM items;
-- что нам вернут эти запросы?
SELECT * 
FROM items
WHERE (price between 100 and 150)
	and (itemname = 'Яблоки')
	or (itemname = 'Сливы');

SELECT * 
FROM items
WHERE (price between 50 and 150)
	and (itemname = 'Яблоки')
	or (itemname = 'Виноград');

-- даты можем писать в разном формате
SELECT * 
FROM sales
WHERE salesdate >= '2005-09-13'
	and salesdate < '2020-01-14';

SELECT * 
FROM sales
WHERE salesdate >= '20050913'
	and salesdate < '20200114';

SELECT *, extract(YEAR FROM salesdate)
FROM sales
WHERE extract(YEAR FROM salesdate) > 2006;

SELECT *
FROM sales
WHERE itemname like '%бл%';

SELECT itemname, price
FROM items
WHERE itemname in (SELECT itemname FROM sales WHERE quantity > 1);

CREATE TABLE if not exists pricelist (price decimal(19,4));
truncate pricelist;

INSERT INTO pricelist (price)
SELECT distinct price
FROM items
WHERE price < 200;

SELECT * 
FROM pricelist;

SELECT * 
FROM items
WHERE price = ANY (SELECT price FROM pricelist);

SELECT * 
FROM items
WHERE price > ALL (SELECT price FROM pricelist);

SELECT * 
FROM items
WHERE price > SOME (SELECT price FROM pricelist);

SELECT * 
FROM items
WHERE price = (SELECT MIN(price) FROM pricelist);

SELECT * 
FROM items i
WHERE EXISTS (SELECT price FROM pricelist p WHERE i.price = p.price);

SELECT * FROM items;
-- что вернется в результате?
SELECT * 
FROM items
WHERE price > 50 AND price > 100 AND price > 150;

-- union
SELECT 1
union
SELECT 1
union
SELECT 1;

SELECT 1
union all
SELECT 1
union all
SELECT 1;

SELECT itemname FROM items
union
SELECT itemname FROM sales;

SELECT itemname FROM items
union all
SELECT itemname FROM sales;

-- можем миксовать union all и DISTINCT
SELECT itemname FROM items
union all
SELECT DISTINCT itemname FROM sales;


SELECT * FROM items WHERE price = 50
union all
SELECT * FROM items WHERE price = 100
order by itemname;

-- можем запрос выгружать в файл
-- в данном случае ошибка
SELECT * FROM items WHERE price = 50
union all
SELECT * INTO OUTFILE 'file_name.txt' FROM items WHERE price = 100
order by itemname;

SHOW VARIABLES LIKE "secure_file_priv";
SELECT @@GLOBAL.secure_file_priv;

SELECT * FROM items WHERE price = 50
union all
SELECT * INTO OUTFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\file_name.txt' FROM items WHERE price = 100
order by itemname;
-- cd c:\ProgramData\MySQL\MySQL Server 8.0\Uploads\
-- или править файл c:\ProgramData\MySQL\MySQL Server 8.0\my.ini
-- # Secure File Priv.
-- secure-file-priv="C:/ProgramData/MySQL/MySQL Server 8.0/Uploads"


SELECT 1/0;
SELECT 1 - 0;