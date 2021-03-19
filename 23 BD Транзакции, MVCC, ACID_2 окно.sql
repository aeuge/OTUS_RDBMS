use billing;

SET SQL_SAFE_UPDATES = 0;
SELECT * FROM saldo;
-- увидели запись %( есть идеи почему?









-- нужно открыть новое соединение к БД. все окна относятся к 1 сессии
SELECT CONNECTION_ID();

-- 2 пример
set autocommit = 0;
start transaction;
SELECT * FROM saldo;
rollback;





-- почему получилось фантомное чтение?
-- несмотря на start transaction, работать со снимком данных мы начнем в момент 1 sql запроса
-- SELECT 1 не сработает %) любой запрос к этой БД подойдет
-- если хотим использовать снимок на момент начала транакции нужно указать WITH CONSISTENT SNAPSHOT
start transaction WITH CONSISTENT SNAPSHOT;
SELECT * FROM saldo;
rollback;


-- 3 пример
SELECT * FROM saldo;

SHOW processlist;
SHOW engine innodb status;

rollback;

-- 5 пример

kill 21;


-- 6 пример
-- serializable 
SELECT @@transaction_isolation;
rollback;
set SESSION transaction isolation level serializable;
begin;
SELECT * FROM ser;
SELECT SUM(sum) FROM ser WHERE id = 2;
INSERT INTO ser VALUES (1, 300);
commit;


-- пример 10
set SESSION transaction isolation level REPEATABLE READ;
SET SQL_SAFE_UPDATES = 0;
UPDATE saldo set saldo_type = 33 WHERE account_id = 1; 


-- пример 11
rollback;
INSERT INTO saldo (account_id, saldo_type) values(6,1);



