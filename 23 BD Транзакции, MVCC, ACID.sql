set autocommit = 1;
SHOW variables like '%commit%'; -- по умолчанию autocommit = ON
SELECT @@global.transaction_isolation;

-- prepare
drop DATABASE if exists billing;
CREATE DATABASE if not exists billing;
use billing;
CREATE TABLE if not exists saldo (account_id int, saldo_type int);
truncate TABLE saldo; -- неявно вызывает коммит
INSERT INTO saldo (account_id, saldo_type) values(1,1);
INSERT INTO saldo (account_id, saldo_type) values(2,1);

-- transaction example
set autocommit = 0;
start transaction;
INSERT INTO saldo (account_id, saldo_type) values(33,1);
SELECT * FROM saldo;
SET SQL_SAFE_UPDATES = 0;
delete FROM saldo;
-- появится ли запись в другом окне?
SELECT * FROM saldo;



SELECT CONNECTION_ID();
commit;
rollback;

-- 2 пример
-- отключим автокоммит и начнет транзакции в 2 окнах
-- после этого в этом окне закоммитим вставку
-- видно ли запись во 2 окне? напоминаю, уровень изоляции repeaTABLE read
-- т.е.работает со своим снимком данных
set autocommit = 0;
begin;
INSERT INTO saldo (account_id, saldo_type) values(11,1);
-- видно ли запись в другом окне?
SELECT * FROM saldo;
commit;
rollback;

SET SQL_SAFE_UPDATES = 0;
UPDATE saldo set saldo_type = 33 WHERE account_id = 11;
commit;

-- 3 пример - DDL неявно вызывает commit

start transaction;
SELECT @@transaction_isolation;
-- set SESSION transaction isolation level...
INSERT INTO saldo (account_id, saldo_type) values(2,1);
drop TABLE if exists saldo_test; 
CREATE TABLE saldo test(account_id int, saldo_type int); -- неявно вызвался коммит
SELECT * FROM saldo;
rollback;

-- 4 пример. запустим транзакцию в 2 окне и сделаем здесь транкейт
truncate saldo;
-- подождем 30 секунд и транзакция отроллбечится

-- 5 пример
-- также автоматически происходит rollback при обрыве соединения
-- SHOW processlist;
-- SHOW engine innodb status;
begin;
INSERT INTO saldo (account_id, saldo_type) values(1,1);
SELECT CONNECTION_ID();
-- kill 24; -- во втором окне


-- что быстрее коммит или роллбек?


-- savepoint
-- вложенные транзакции не поддерживаются
truncate saldo;
begin;
INSERT INTO saldo (account_id, saldo_type) values(1,1);
INSERT INTO saldo (account_id, saldo_type) values(2,1);
commit;
SELECT * FROM saldo;

SET SQL_SAFE_UPDATES = 0;
begin;
UPDATE saldo set saldo_type = 3 WHERE account_id = 1;
savepoint test;
UPDATE saldo set saldo_type = 5 WHERE account_id = 1;
savepoint test2;
UPDATE saldo set saldo_type = 7 WHERE account_id = 1;
SELECT * FROM saldo;
rollback to test;
SELECT * FROM saldo;
rollback;
SELECT * FROM saldo;

-- isolation
SELECT @@transaction_isolation;

--  read uncommited
set SESSION transaction isolation level READ UNCOMMITTED;
set SESSION transaction isolation level READ COMMITTED;
set SESSION transaction isolation level REPEATABLE READ;

-- 6 пример
-- serializable
CREATE TABLE if not exists ser (id int, sum int);
truncate TABLE ser; -- неявно вызывает коммит
set SESSION transaction isolation level serializable;
begin;
INSERT INTO ser (id, sum) values(1,10);
INSERT INTO ser (id, sum) values(1,20);
INSERT INTO ser (id, sum) values(2,100);
INSERT INTO ser (id, sum) values(2,200);
commit;
begin;
SELECT * FROM ser;
SELECT SUM(sum) FROM ser WHERE id = 1;
INSERT INTO ser VALUES (2, 30);
SET SQL_SAFE_UPDATES = 0;
UPDATE ser set sum = 33 WHERE id = 1;
commit;
delete FROM ser WHERE id = 2 and sum = 30;
rollback;



-- блокировки
-- пример 10
truncate saldo;
INSERT INTO saldo (account_id, saldo_type) values(1,1);
INSERT INTO saldo (account_id, saldo_type) values(2,1);
commit;
set SESSION transaction isolation level REPEATABLE READ;
SET SQL_SAFE_UPDATES = 0;
begin;
UPDATE saldo set saldo_type = 33 WHERE account_id = 1;
-- попробуем обновить в другой сессии
SHOW engine innodb status;
-- соответственно будет видно последний deadlock и чем все закончилось
commit;


SELECT * FROM saldo;
begin;
rollback;

-- 11 пример
-- gap блокировка по индексу по умолчанию и из другой сессии нет доступа
begin;
UPDATE saldo set saldo_type = 33 WHERE account_id between 1 and 10; 
USE performance_schema;
SELECT * FROM data_locks;
use billing;

SELECT * FROM saldo WHERE account_id = 1 for share;  
rollback;
begin;
SELECT * FROM saldo WHERE account_id > 5 for update;  
SELECT CONNECTION_ID();
SHOW VARIABLES LIKE 'performance_schema';
SELECT * FROM INFORMATION_SCHEMA.ENGINES
       WHERE ENGINE='PERFORMANCE_SCHEMA';
USE performance_schema;
SHOW TABLEs;
SELECT * FROM data_locks;
-- откатим блокировки и еще раз посомтрим блокировки
rollback;
-- SELECT * FROM innodb_trx; убрали в 8

use billing;
begin

-- next-key lock
begin
UPDATE saldo set saldo_type = 33 WHERE account_id >100;  -- 'supremum pseudo-record'
USE performance_schema;
SELECT * FROM data_locks;
SHOW variables like '%wait%';


-- протестим 1 транзакция на 1000 записей или по транзакции на каждую запись
use billing;
drop procedure if exists test_insert;
delimiter //
CREATE procedure  test_insert()
BEGIN
  SET @p1 = 100;
  label1: LOOP
    SET @p1 = @p1 + 1;
    INSERT INTO saldo (account_id, saldo_type) values(@p1,1);
    IF @p1 < 1000 THEN
      ITERATE label1;
    END IF;
    LEAVE label1;
  END LOOP label1;
END
//
delimiter ;
set autocommit = 1;
call test_insert();
-- отключим автокоммит и получим 1 ручной коммит в конце
set autocommit = 0;
begin;
call test_insert();
SELECT count(*) FROM saldo;
commit;


-- load data
SHOW variables like 'secure_file_priv';
SHOW variables like '%dead%';
-- bulk insert

drop TABLE if exists test_load;
CREATE TABLE if not exists test_load (
	itemname varchar(128), 
	price decimal(19,4), 
	quantity int, 
	CREATEd_at timestamp);
    
LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\file_name.txt'
	 INTO TABLE test_load
 	 LINES TERMINATED BY '\n'
 (itemname,price,quantity,@CREATEd_at)
 SET CREATEd_at = STR_TO_DATE(NOW(), '%Y-%m-%d %H:%i:%s')
;
SELECT * FROM test_load;

-- mysqlimport billing --ignore-lines=1 --lines-terminated-by="\n" --fields-terminated-by="," --fields-enclosed-by="\""  -c title,author,CREATEd_at "./articles.csv"

