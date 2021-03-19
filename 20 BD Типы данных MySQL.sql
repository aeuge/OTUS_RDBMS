-- развернем ВМ mysql в GCE
gcloud beta compute --project=celtic-house-266612 instances CREATE mysql --zone=us-central1-a --machine-type=e2-medium --subnet=default --network-tier=PREMIUM --maintenance-policy=MIGRATE --service-account=933982307116-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --image=ubuntu-2010-groovy-v20201210 --image-project=ubuntu-os-cloud --boot-disk-size=10GB --boot-disk-type=pd-ssd --boot-disk-device-name=mysql --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any
 
gcloud compute ssh mysql

-- Поставим 8 мускуль
sudo wget -c https://dev.mysql.com/get/mysql-apt-config_0.8.16-1_all.deb && sudo dpkg -i mysql-apt-config_0.8.16-1_all.deb && sudo apt-key adv --keyserver keys.gnupg.net --recv-keys 8C718D3B5072E1F5 && sudo apt UPDATE && sudo apt-get install mysql-server -y

-- зададим рутовый пароль Otus321
-- обязательно запустить скрипт начальной секурной установки
sudo mysql_secure_installation

sudo mysql_config_editor set --login-path=client --host=localhost --user=root --password

--sudo mysql -u root -p
sudo mysql

-- посмотрим какие у нас вообще есть кодировки
-- https://dev.mysql.com/doc/refman/8.0/en/charset-connection.html
SHOW CHARACTER SET;
SHOW CHARACTER SET LIKE 'utf%';
SHOW variables like '%char%';
-- текущая версия 9.0 utf8mb4_0900_ai_ci очень быстрая
-- чтобы явно сообщить, что вы будете отправлять данные в кодировке UTF8
-- https://dev.mysql.com/doc/refman/8.0/en/set-names.html
SET NAMES 'utf8mb4';
-- This statement sets the three session system variables
-- character_set_client, 
-- character_set_connection, 
-- character_set_results to the given character set. 
SHOW SESSION VARIABLES LIKE 'character\_set\_%';
SHOW SESSION VARIABLES LIKE 'collation\_%';

SHOW collation;


-- 1 операции со строками в разной кодировке
CREATE DATABASE otus;
USE otus;

CREATE TABLE t1 (
  c1 CHAR(1) CHARACTER SET latin1,
  c2 CHAR(1) CHARACTER SET ascii
);
INSERT INTO t1 VALUES ('a','b');
SELECT CONCAT(c1,c2) FROM t1;

-- как кдумаете, смодем ли мы теперь добавить русскую букву в поле ascii?
INSERT INTO t1 VALUES ('a','б');
SET NAMES 'ascii';
SHOW SESSION VARIABLES LIKE 'character\_set\_%';

-- а теперь добавим?
INSERT INTO t1 VALUES ('a','б');


CREATE TABLE t2 (
  c1 CHAR(1) CHARACTER SET latin1,
  c2 CHAR(2) CHARACTER SET ascii
);
INSERT INTO t2 VALUES ('a','б');
-- как думаете какой результат соединения будет?
SELECT CONCAT(c1,c2) FROM t2;

SET NAMES 'utf8mb4';
--  сравнение с учетом пробелов в конце
SELECT COLLATION_NAME, PAD_ATTRIBUTE
       FROM INFORMATION_SCHEMA.COLLATIONS
       WHERE COLLATION_NAME LIKE 'utf8mb4%bin';

SET NAMES utf8mb4 COLLATE utf8mb4_bin;
SELECT 'a ' = 'a';
SELECT 'a         ' = 'a';

SET NAMES utf8mb4 COLLATE utf8mb4_0900_bin;
SELECT 'a ' = 'a';


-- 2 округление
delimiter //
CREATE PROCEDURE p()
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE d DECIMAL(10,4) DEFAULT 0;
    DECLARE f FLOAT DEFAULT 0;
    WHILE i < 10000 DO
        SET d = d + 0.001;
        SET f = f + 0.001E0;
        SET i = i + 1;
    END WHILE;
    SELECT d,f;
END//
delimiter ;
-- как думаете, на выходе получим одинаковые значения?
call p();
--https://dev.mysql.com/doc/refman/8.0/en/CREATE-procedure.html
SELECT ceil(9.22), floor(9.22), round(9.22), round(9.4999), round(9.4999, 3), round(9.5);

-- 3 работа со строками
DELIMITER ;;
CREATE PROCEDURE `EXTRACT_VALUES`(in_value longtext, in_bound VARCHAR(255))
BEGIN
    DECLARE id INT DEFAULT 0;
    DECLARE value TEXT;
    DECLARE occurance INT DEFAULT 0;
    DECLARE i INT DEFAULT 0;
    DECLARE splitted_value VARCHAR(255);
    DECLARE done INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    DROP TEMPORARY TABLE IF EXISTS tmp_extracted_values;
    CREATE TEMPORARY TABLE tmp_extracted_values(`value` VARCHAR(256) NOT NULL) ENGINE=Memory;
    SET occurance = (SELECT CHAR_LENGTH(in_value)
                             - CHAR_LENGTH(REPLACE(in_value, in_bound, ''))
                             +1);
    SET i=1;
    WHILE i <= occurance DO
          SET splitted_value =
          (SELECT REPLACE(SUBSTRING(SUBSTRING_INDEX(in_value, in_bound, i),
          CHAR_LENGTH(SUBSTRING_INDEX(in_value, in_bound, i - 1)) + 1), ',', ''));

          INSERT INTO tmp_extracted_VALUES VALUES (splitted_value);
          SET i = i + 1;
    END WHILE;
  END ;;
DELIMITER ;
call EXTRACT_VALUES ('mysql,postgres,oracle',',');
SELECT * FROM tmp_extracted_values;

-- REGEXP
SET @in_account_number='30248787';
SELECT @in_account_number REGEXP '^302[[:digit:]]*$|^303[[:digit:]]*$|^474[[:digit:]]*$';

-- BLOB
SHOW variables like '%max_sort_length%';
SHOW variables like '%max_allowed_packet%';
SHOW variables like 'innodb_default_row_format';
SHOW TABLE status;



-- UUID
-- https://dev.mysql.com/doc/refman/8.0/en/miscellaneous-functions.html#function_uuid
-- https://mysqlserverteam.com/mysql-8-0-uuid-support/
SELECT UUID();
SELECT LENGTH(UUID());--36 byte
CREATE TABLE t_uuid (id binary(16) PRIMARY KEY);
INSERT INTO t_uuid VALUES(UUID_TO_BIN(UUID()));
SELECT * FROM t_uuid;
SELECT BIN_TO_UUID(id) FROM t_uuid;

--- uuid4 -?

-- 4 enum
CREATE TABLE shirts (
    name VARCHAR(40),
    size ENUM('x-small', 'small', 'medium', 'large', 'x-large')
 );
INSERT INTO shirts (name, size) VALUES ('dress shirt','large'), ('t-shirt','medium'),
  ('polo shirt','small');
SELECT name, size FROM shirts WHERE size = 'medium';
UPDATE shirts SET size = 'small' WHERE size = 'large';

-- при попытке использовать значение, которого нет в ENUM - ошибка. соответственно нужно ALTER TABLE ...
UPDATE shirts SET size = 'small2' WHERE size = 'small';

--посмотрим реально значение в поле enum
SELECT name, size+0 FROM shirts; 
SELECT * FROM shirts WHERE size=2;

-- set
CREATE TABLE myset (col SET('a', 'b', 'c', 'd'));
INSERT INTO myset (col) VALUES
('a,d'), ('d,a'), ('a,d,a'), ('a,d,d'), ('d,a,d'), ('a,c,b');
INSERT INTO myset (col) VALUES ('a,d,d,s');
SELECT * FROM myset WHERE FIND_IN_SET('a',col)>0;


-- 5 timestamp
-- посмотрим работу параметра explicit_defaults_for_timestamp, который выставляет timestamp по умолчанию
SHOW VARIABLES LIKE 'explicit_defaults_for_timestamp';
CREATE TABLE test_ts(name text, ts timestamp);
SHOW CREATE TABLE test_ts;
-- отключим это значение
SET EXPLICIT_DEFAULTS_FOR_TIMESTAMP = 0;
CREATE TABLE test_ts2(name text, ts timestamp);
SHOW CREATE TABLE test_ts2;

-- что произойдет, если будет 2 таймстампа?
CREATE TABLE test_ts3(name text, ts timestamp, ts2 timestamp);
SHOW CREATE TABLE test_ts3;

--протестим таймзоны
--sudo timedatectl set-timezone Europe/London
CREATE TABLE test_tz(t1 timestamp, t2 datetime);
INSERT INTO test_tz VALUES (NOW(),NOW());
SELECT * FROM test_tz;
SELECT * FROM test_tz WHERE t1=t2;

timedatectl list-timezones
sudo timedatectl set-timezone Europe/Moscow
sudo systemctl restart mysql
sudo mysql
use otus;
SELECT * FROM test_tz;
SELECT * FROM test_tz WHERE t1=t2;

-- date functions
SELECT t2, YEAR(t2) AS dyear, MONTH(t2) AS dmonth FROM test_tz;
SELECT STR_TO_DATE('May 1, 1974','%M %d,%Y');
SELECT CAST(NOW() AS DATE);
-- неявное преобразование типов, так как дата указана в дефолтном формате
SELECT DATEDIFF(NOW(),'2020-07-01');

-- JSON
SELECT JSON_ARRAY(1, "abc", NULL, TRUE, CURTIME());
SELECT JSON_OBJECT('id', 87, 'name', 'carrot');

SELECT JSON_MERGE(
    '{"network": "GSM"}' ,
    '{"network": "CDMA"}' ,
    '{"network": "HSPA"}' ,
    '{"network": "EVDO"}'
);

-- JSON
-- The JSON_INSERT function will only add the property to the object if it does not exists already.
-- The JSON_REPLACE function substitutes the property only if it is found.
-- The JSON_SET function will add the property if it is not found else replace it.

--загрузин данные
gcloud compute instances list
-- скопируем файл на сервер через scp
cat 20BDjson.sql
scp 20BDjson.sql aeugene@35.188.53.33:/home/aeugene
-- зарузим БД с json 
sudo mysql < 20BDjson.sql
/* output: OBJECT */
SELECT JSON_TYPE(attributes) FROM `store`.`products`;

SELECT
    *
FROM
    `store`.`products`
WHERE
    `category_id` = 1
AND JSON_EXTRACT(`attributes` , '$.ports.usb') > 0
AND JSON_EXTRACT(`attributes` , '$.ports.hdmi') > 0;

UPDATE `store`.`products`
SET `attributes` = JSON_INSERT(
    `attributes` ,
    '$.chipset' ,
    'Qualcomm'
)
WHERE
    `category_id` = 2;

SELECT * FROM `store`.`products`;

-- JSON update
UPDATE `store`.`products`
SET `attributes` = JSON_REPLACE(
    `attributes` ,
    '$.chipset' ,
    'Qualcomm Snapdragon'
)
WHERE
    `category_id` = 2;

-- DELETE
DELETE FROM `store`.`products`
WHERE `category_id` = 2
AND JSON_EXTRACT(`attributes` , '$.os') LIKE '%Jellybean%';

SELECT * FROM `store`.`products`;


gcloud compute instances delete mysql