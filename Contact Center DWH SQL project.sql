/*
===============================================================================
Create Database and Schemas
===============================================================================
Script Purpose: 
	This script creates a new DataBase named 'ContactCenterDWH' only after cheking if it doesn't exist. 
	If DataBase already exits, it will delete and recreate the DataBase.
	The Script sets up threee schemas in DataBase: 'Bronze', 'Silver', 'Gold'.

WARNING!!:
	Running the script will delete the DataBase named 'ContactCenterDWH' if it already exists.
	All the DATA in DataBase will be deleted permanently. ONLY proceed with caution.
	Ensure you have proper backups before running the script
*/

USE master;
GO

-- create the new database: 'CallsDB'
IF EXISTS (SELECT 1 FROM sys.databases WHERE NAME = 'ContactCenterDWH')
BEGIN
    ALTER DATABASE ContactCenterDWH SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE ContactCenterDWH;
END

CREATE DATABASE ContactCenterDWH;
Go

-- Switch to the new DataBase
USE ContactCenterDWH;
GO

--create schemas
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO

-- create bronze layer tables, if already exists then drop and create table again
IF OBJECT_ID ('bronze.calls','U') IS NOT NULL
    DROP TABLE bronze.calls;
CREATE TABLE bronze.calls (
    call_id                 VARCHAR (100),
    case_id                 VARCHAR (50),
    call_start_datetime     DATETIME    ,
    call_end_datetime       DATETIME    ,
    employee_id             VARCHAR (20),
    customer_id             VARCHAR (20),
    call_reason_id          VARCHAR (20),
    queue                   VARCHAR (50),
    channel                 VARCHAR (20),
    call_status             VARCHAR (20),
    hold_time_seconds       INT         ,
    acw_time_seconds        INT         ,
    transfer_flag           BIT         ,
    escalation_flag         BIT         ,
    resolution_status       VARCHAR (20),
    fcr_flag                BIT         ,
    sentiment               VARCHAR (20),
    csat_score              varchar(10),
    nps_score               varchar(10),
    complaint_flag          BIT         ,
    callback_requested_flag INT         
);


IF OBJECT_ID ('bronze.call_reasons','U') IS NOT NULL
    DROP TABLE bronze.calls;
CREATE TABLE bronze.call_reasons (
    call_reason_id     VARCHAR (100),
    category           VARCHAR (20) ,
    subcategory        VARCHAR (20) ,
    reason_description VARCHAR (30) 
);

IF OBJECT_ID ('bronze.customers','U') IS NOT NULL
    DROP TABLE bronze.calls;
CREATE TABLE bronze.customers (
    customer_id          VARCHAR (20) ,
    customer_name        VARCHAR (100),
    date_of_birth        DATE         ,
    gender               VARCHAR (20) ,
    city                 VARCHAR (20) ,
    state                VARCHAR (20) ,
    customer_since       DATE         ,
    customer_segment     VARCHAR (20) ,
    product              VARCHAR (50) ,
    [plan]               VARCHAR (50) ,
    contract_type        VARCHAR (20) ,
    customer_status      VARCHAR (20) ,
    registration_channel VARCHAR (50) 
);


IF OBJECT_ID ('bronze.employees','U') IS NOT NULL
    DROP TABLE bronze.calls;
CREATE TABLE bronze.employees (
    employee_id      VARCHAR (20) ,
    employee_name    VARCHAR (100),
    team_leader_name VARCHAR (100),
    manager_name     VARCHAR (100),
    site             VARCHAR (20) ,
    process          VARCHAR (20) ,
    join_date        DATE         ,
    skill_level      VARCHAR (3)  ,
    status           VARCHAR (10) 
);


-- load data into bronze tables usingh BULK INSERT using TRUNCATE, existing data will be removed and new data will be loaded
-- can execute the bronze.load_bronze stored procedure to automatically truncate and load new data

EXEC bronze.load_bronze

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    BEGIN TRY
        PRINT '=========================================='
        PRINT           'Loading bronze layer'
        PRINT '=========================================='

        TRUNCATE TABLE bronze.calls
        BULK INSERT bronze.calls
        FROM 'D:\call_center_source_data\calls.csv'
        WITH (FIRSTROW = 2, 
              FIELDTERMINATOR = ',', 
              ROWTERMINATOR = '0X0a', TABLOCK
        );

        TRUNCATE TABLE bronze.customers
        BULK INSERT bronze.customers 
        FROM 'D:\call_center_source_data\customers.csv'
        WITH (FIRSTROW = 2, 
              FIELDTERMINATOR = ',', 
              ROWTERMINATOR = '0X0a', TABLOCK
        );

        TRUNCATE TABLE bronze.employees
        BULK INSERT bronze.employees 
        FROM 'D:\call_center_source_data\employees.csv'
        WITH (FIRSTROW = 2, 
              FIELDTERMINATOR = ',', 
              ROWTERMINATOR = '0X0a', TABLOCK
        );

        TRUNCATE TABLE bronze.call_reasons
        BULK INSERT bronze.call_reasons 
        FROM 'D:\call_center_source_data\call_reasons.csv'
        WITH (FIRSTROW = 2, 
              FIELDTERMINATOR = ',', 
              ROWTERMINATOR = '0X0a', TABLOCK
        );

        PRINT '=========================================='
        PRINT      'Bronzer layer load completed'
        PRINT '=========================================='
    END TRY

    BEGIN CATCH
        PRINT '==========================================';
        PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER';
        PRINT 'ERROR MESSAGE: ' + ERROR_MESSAGE();
        PRINT 'ERROR MESSAGE: ' + CAST(ERROR_MESSAGE() AS VARCHAR);
        PRINT 'ERROR MESSAGE: ' + CAST(ERROR_STATE() AS VARCHAR);
        PRINT '=========================================='
    END CATCH
END


/*
==================================================================================
                        create silver tables
==================================================================================
*/


IF OBJECT_ID ('silver.customers','U') IS NOT NULL
    DROP TABLE silver.customers;
CREATE TABLE silver.customers (
    customer_id          VARCHAR (20) ,
    customer_name        VARCHAR (100),
    date_of_birth        DATE         ,
    gender               VARCHAR (20) ,
    city                 VARCHAR (20) ,
    state                VARCHAR (20) ,
    customer_since       DATE         ,
    customer_since_days  INT          ,
    customer_segment     VARCHAR (20) ,
    [product]            VARCHAR (50) ,
    [plan]               VARCHAR (50) ,
    contract_type        VARCHAR (20) ,
    customer_status      VARCHAR (20) ,
    registration_channel VARCHAR (50) 
);


IF OBJECT_ID ('silver.employees','U') IS NOT NULL
    DROP TABLE silver.employees;
CREATE TABLE silver.employees (
    employee_id      VARCHAR (20) ,
    employee_name    VARCHAR (100),
    team_leader_name VARCHAR (100),
    manager_name     VARCHAR (100),
    site             VARCHAR (20) ,
    process          VARCHAR (20) ,
    join_date        DATE         ,
    skill_level      VARCHAR (3)  ,
    status           VARCHAR (10) ,
    employee_valid_flag BIT       
);


IF OBJECT_ID ('silver.call_reasons','U') IS NOT NULL
    DROP TABLE silver.call_reasons;
create table silver.call_reasons (
    call_reason_id     VARCHAR (100),
    category           VARCHAR (20) ,
    subcategory        VARCHAR (20) ,
    reason_description VARCHAR (30) 
);


IF OBJECT_ID ('silver.calls','U') IS NOT NULL
    DROP TABLE silver.calls;
CREATE TABLE silver.calls (
    call_id                 VARCHAR (100),
    case_id                 VARCHAR (50),
    call_start_datetime     DATETIME2(0),
    call_end_datetime       DATETIME2(0),
    call_duration_seconds   INT         ,
    employee_id             VARCHAR (20),
    customer_id             VARCHAR (20),
    call_reason_id          VARCHAR (20),
    queue                   VARCHAR (50),
    channel                 VARCHAR (20),
    call_status             VARCHAR (20),
    hold_time_seconds       INT         ,
    acw_time_seconds        INT         ,
    transfer_flag           BIT         ,
    escalation_flag         BIT         ,
    resolution_status       VARCHAR (20),
    fcr_flag                BIT         ,
    sentiment               VARCHAR (20),
    csat_score              INT,
    nps_score               INT         ,
    complaint_flag          BIT         ,
    callback_requested_flag BIT         ,
    employee_valid_flag     BIT         ,
    customer_valid_flag bit             ,
    call_reason_valid_flag bit
);

-->> INSERT the cleaned, transformed data into silver tables

-- silver customers table

INSERT INTO silver.customers (customer_id, customer_name, date_of_birth, gender, city, state, customer_since, customer_since_days, customer_segment, [product], [plan], contract_type, customer_status, registration_channel)
SELECT customer_id,
       customer_name,
       date_of_birth,
       gender,
       city,
       state,
       customer_since,
       DATEDIFF(day, customer_since, GETDATE()) AS customer_since_days,
       customer_segment,
       product,
       [plan],
       contract_type,
       customer_status,
       registration_channel
FROM   bronze.customers;


-- silver employees table, removed duplicates
INSERT INTO silver.employees (employee_id, employee_name, team_leader_name, manager_name, site, process, join_date, skill_level, status)
SELECT employee_id,
       employee_name,
       team_leader_name,
       manager_name,
       site,
       process,
       join_date,
       skill_level,
       status
FROM   (SELECT *,
               ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY employee_id) AS employee_flag
        FROM   bronze.employees) AS t
WHERE  employee_flag = 1;


-- silver call reasons table, no issues with this table
INSERT INTO silver.call_reasons (call_reason_id, category, subcategory, reason_description)
SELECT *
FROM   bronze.call_reasons;


-- silver calls table, created flags for invalid customer id, employee id, call reaon id. SHOULD NOT REMOVE INVALID ids data
INSERT INTO silver.calls (call_id, case_id, call_start_datetime, call_end_datetime, call_duration_seconds, 
            employee_id, customer_id, call_reason_id, queue, channel, call_status, hold_time_seconds, acw_time_seconds, 
            transfer_flag, escalation_flag, resolution_status, fcr_flag, sentiment, csat_score, nps_score, complaint_flag, 
            callback_requested_flag, employee_valid_flag, customer_valid_flag, call_reason_valid_flag)
    
        SELECT c.call_id,
               c.case_id,
               CAST (c.call_start_datetime AS DATETIME2 (0)) AS call_start_datetime,
               CAST (c.call_end_datetime AS DATETIME2 (0)) AS call_end_datetime,
               DATEDIFF(second, call_start_datetime, call_end_datetime) AS call_duration_seconds,
               c.employee_id,
               c.customer_id,
               c.call_reason_id,
               TRIM(c.queue) AS 'queue',
               c.channel,
               c.call_status,
               c.hold_time_seconds,
               c.acw_time_seconds,
               c.transfer_flag,
               c.escalation_flag,
               c.resolution_status,
               c.fcr_flag,
               c.sentiment,
               CASE WHEN TRY_CONVERT (DECIMAL (10, 2), c.csat_score) BETWEEN 0 AND 5 THEN CAST (TRY_CONVERT (DECIMAL (10, 2), c.csat_score) AS INT) ELSE NULL END csat_score,
               CASE WHEN TRY_CONVERT (DECIMAL (10, 2), c.nps_score) BETWEEN 0 AND 10 THEN CAST (TRY_CONVERT (DECIMAL (10, 2), c.nps_score) AS INT) ELSE NULL END nps_score,
               c.complaint_flag,
               c.callback_requested_flag,
               CASE WHEN c.employee_id IS NOT NULL
                         AND e.employee_id IS NULL THEN 0 ELSE 1 END AS employee_valid_flag,
               CASE WHEN c.customer_id IS NOT NULL
                         AND cu.customer_id IS NULL THEN 0 ELSE 1 END AS customer_valid_flag,
               CASE WHEN c.call_reason_id IS NOT NULL
                         AND cr.call_reason_id IS NULL THEN 0 ELSE 1 END AS call_reason_valid_flag
        FROM   bronze.calls c
               LEFT JOIN
               silver.employees e
               ON e.employee_id = c.employee_id
               LEFT JOIN
               silver.customers AS cu
               ON cu.customer_id = c.customer_id
               LEFT JOIN
               silver.call_reasons AS cr
               ON cr.call_reason_id = c.call_reason_id
               

/*
==================================================================================
                        create GOLD tables
==================================================================================
*/

-- creating gold tables, first DIMs then FACT as FACT is dependent on DIM tables

-- gold employees table, included emnployees tenure and tenure band for analysis
create table gold.dim_employee (
    employee_id      VARCHAR (20) ,
    employee_name    VARCHAR (100),
    team_leader_name VARCHAR (100),
    manager_name     VARCHAR (100),
    site             VARCHAR (20) ,
    process          VARCHAR (20) ,
    join_date        DATE         ,
    skill_level      VARCHAR (3)  ,
    status           VARCHAR (10) ,
    employee_tenure_days INT,
    employee_tenure_band varchar(20)
)


--- gold customers table, included customers age, customer loyalty, region: North or south for analysis

CREATE TABLE gold.dim_customer (
    customer_id VARCHAR (20),
    customer_name VARCHAR (100),
    date_of_birth DATE,
    customer_age INT,
    customer_age_group varchar(20),
    gender VARCHAR (20),
    city VARCHAR (20),
    state VARCHAR (20),
    region VARCHAR (20),
    customer_since DATE,
    customer_since_days INT,
    customer_loyalty_band VARCHAR (20),
    customer_segment VARCHAR (20),
    [product] VARCHAR (50),
    [plan] VARCHAR (50),
    contract_type VARCHAR (20),
    customer_status VARCHAR (20),
    registration_channel VARCHAR (50)
);


--- gold call reasons table, no changes since data is clean and good from bronze layer and no business logics needed

CREATE TABLE gold.dim_call_reason (
    call_reason_id     VARCHAR (100),
    category           VARCHAR (20) ,
    subcategory        VARCHAR (20) ,
    reason_description VARCHAR (30) 
);


--- gold.calendar, for all date realted analysis, there is no such table in bronze or silver, creating it in the gold level based on call_startDate in calls table

CREATE TABLE gold.calendar (
    date_key INT,
    full_date DATE,
    year SMALLINT,
    quarter VARCHAR (2),
    quarter_number TINYINT,
    month TINYINT,
    month_name VARCHAR (10),
    month_year date,
    week_number TINYINT,
    day_of_month TINYINT,
    day_name VARCHAR (10),
    day_of_week TINYINT,
    is_weekend BIT
);


---- gold FACT calls table

select * from silver.calls
create table gold.fact_calls (
    call_id                 VARCHAR (100),
    case_id                 VARCHAR (50),
    date_key                INT,
    employee_id             VARCHAR (20),
    customer_id             VARCHAR (20),
    call_reason_id          VARCHAR (20),

    call_start_datetime     DATETIME2(0),
    call_end_datetime       DATETIME2(0),
    call_duration_seconds   INT         ,
    hold_time_seconds       INT         ,
    acw_time_seconds        INT         ,

    queue                   VARCHAR (50),
    channel                 VARCHAR (20),
    call_status             VARCHAR (20),
    resolution_status       VARCHAR (20),
    sentiment               VARCHAR (20),

    transfer_flag           BIT         ,
    escalation_flag         BIT         ,
    fcr_flag                BIT         ,
    
    csat_score              INT,
    nps_score               INT         ,

    complaint_flag          BIT         ,
    callback_requested_flag BIT         ,

    customer_age_at_call varchar(20)    ,
    employee_tenure_at_call varchar (20)
    )


-->> INSERT data into gold tables (expecting business ready data with all 

--- gold employees table

INSERT INTO gold.dim_employee (employee_id, employee_name, team_leader_name, 
            manager_name, site, process, join_date, skill_level, status, 
            employee_tenure_days, employee_tenure_band)
SELECT employee_id,
       employee_name,
       team_leader_name,
       manager_name,
       site,
       process,
       join_date,
       skill_level,
       status,
       DATEDIFF(day, join_date, GETDATE()) AS employee_tenure_days,
       CASE WHEN DATEDIFF(day, join_date, GETDATE()) < 180 THEN '< 6 Months' 
            WHEN DATEDIFF(day, join_date, GETDATE()) < 365 THEN '6-12 Months' 
            WHEN DATEDIFF(day, join_date, GETDATE()) < 730 THEN '1-2 Years' 
            WHEN DATEDIFF(day, join_date, GETDATE()) < 1095 THEN '2-3 Years' 
            ELSE '3+ Years' END AS employee_tenure_band
FROM   silver.employees;


--- gold customers table

insert into gold.dim_customer (customer_id,customer_name,date_of_birth,customer_age,customer_age_group,gender,
            city,[state], region,customer_since,customer_since_days,customer_loyalty_band,customer_segment,[product],
            [plan],contract_type,customer_status,registration_channel)

select customer_id, 
        customer_name, 
        date_of_birth,
        DATEDIFF(Year,date_of_birth,getdate()) customer_age,
        case when DATEDIFF(Year,date_of_birth,getdate()) between 18 and 24 then '18-24'
            when DATEDIFF(Year,date_of_birth,getdate()) between 25 and 34 then '25-34'
            when DATEDIFF(Year,date_of_birth,getdate()) between 35 and 44 then '35-44'
            when DATEDIFF(Year,date_of_birth,getdate()) between 45 and 54 then '45-54'
            else '55+' end customer_age_group,
        gender,
        city,
        [state],
        case when state in ('Kerala','Karnataka','Tamil Nadu','Telangana','Andhra Pradesh') then 'South'
            else 'North' end region,
            customer_since,
            customer_since_days,
            case when customer_since_days < 30 then 'new'
                when customer_since_days < 180 then '< 6 Months'
                when customer_since_days < 365 then '6-12 Months'
                when customer_since_days < 730 then '1-2 Years'
                when customer_since_days < 1095 then '2-3 Years'
                else  '3+ Years' end customer_loyalty_band,
                customer_segment,
                [product],
                [plan],
                contract_type,
                customer_status,
                registration_channel
from silver.customers


--- gold call reasons table (same as bronze and silver)

insert into gold.dim_call_reason (call_reason_id,category,subcategory,reason_description)
select *
from    silver.call_reasons


-- create calendar, useful for date level analysis, dates will be available only from the startdate and enddate in the calls table

declare @startdate date = (select MIN(CAST(call_start_datetime as DATE)) from silver.calls);
declare @enddate date   = (select MAX(CAST(call_start_datetime as DATE)) from silver.calls);

WHILE @startdate < @enddate
BEGIN
    INSERT INTO gold.calendar (date_key, full_date, [year], [quarter], quarter_number, [month], month_name, month_year, week_number, day_of_month, day_name, day_of_week, is_weekend)
    VALUES
( 
    CONVERT(INT,CONVERT(VARCHAR(8),@startdate,112)),
    @startdate,
    YEAR(@startdate),
    CONCAT('Q',DATEPART(quarter,@startdate)),
    DATEPART(quarter,@startdate),
    MONTH(@startdate),
    DATENAME(MONTH,@startdate),
    DATEFROMPARTS(YEAR(@startdate),MONTH(@startdate),1),
    DATEPART(WEEK,@startdate),
    DAY(@startdate),
    DATENAME(WEEKDAY,@startdate),
    DATEPART(WEEKDAY,@startdate),
    CASE WHEN DATEPART(WEEKDAY,@startdate) in (1,7) THEN 1 ELSE 0 END);
    
SET @startdate = DATEADD(DAY,1,@startdate);
END;


----- Inseting data to MAIN FACT table: gold.fact_calls, there are few invalid customer ids and employee id which doens't exists in dim tables, hence they are mention ad unkown in gold.fact_calls

INSERT INTO gold.fact_calls (call_id, case_id, date_key, employee_id, customer_id, call_reason_id, call_start_datetime, call_end_datetime, call_duration_seconds, hold_time_seconds, acw_time_seconds, [queue], channel, call_status, resolution_status, sentiment, transfer_flag, escalation_flag, fcr_flag, csat_score, nps_score, complaint_flag, callback_requested_flag, customer_age_at_call, employee_tenure_at_call)
SELECT c.call_id,
       c.case_id,
       CAST (CONVERT (VARCHAR (8), c.call_start_datetime, 112) AS INT) AS date_key,
       CASE WHEN employee_valid_flag = 0 THEN 'UNKNOWN' ELSE c.employee_id END AS employee_id,
       CASE WHEN customer_valid_flag = 0 THEN 'UNKNOWN' ELSE c.customer_id END AS customer_id,
       CASE WHEN call_reason_valid_flag = 0 THEN 'UNKNOWN' ELSE c.call_reason_id END AS call_reason_id,
       c.call_start_datetime,
       c.call_end_datetime,
       c.call_duration_seconds,
       c.hold_time_seconds,
       c.acw_time_seconds,
       c.queue,
       c.channel,
       c.call_status,
       c.resolution_status,
       c.sentiment,
       c.transfer_flag,
       escalation_flag,
       fcr_flag,
       c.csat_score,
       c.nps_score,
       c.complaint_flag,
       c.callback_requested_flag,
       CASE WHEN DATEDIFF(YEAR, cu.date_of_birth, c.call_start_datetime) BETWEEN 18 AND 24 THEN '18-24' WHEN DATEDIFF(YEAR, cu.date_of_birth, c.call_start_datetime) BETWEEN 25 AND 34 THEN '25-34' WHEN DATEDIFF(YEAR, cu.date_of_birth, c.call_start_datetime) BETWEEN 35 AND 44 THEN '35-44' WHEN DATEDIFF(YEAR, cu.date_of_birth, c.call_start_datetime) BETWEEN 45 AND 54 THEN '45-54' ELSE '55+' END AS customer_age_at_call,
       CASE WHEN DATEDIFF(day, e.join_date, c.call_start_datetime) < 180 THEN '< 6 Months' WHEN DATEDIFF(day, e.join_date, c.call_start_datetime) < 365 THEN '6-12 Months' WHEN DATEDIFF(day, e.join_date, c.call_start_datetime) < 730 THEN '1-2 Years' WHEN DATEDIFF(day, e.join_date, c.call_start_datetime) < 1095 THEN '2-3 Years' ELSE '3+ Years' END AS employee_tenure_at_call
FROM   silver.calls AS c
       LEFT JOIN
       gold.dim_customer AS cu
       ON cu.customer_id = c.customer_id
       LEFT JOIN
       gold.dim_employee AS e
       ON e.employee_id = c.employee_id;