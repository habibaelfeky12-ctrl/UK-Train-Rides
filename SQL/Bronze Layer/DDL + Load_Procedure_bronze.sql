/*
===============================================================================
DDL Script: Create Bronze Table
===============================================================================
Script Purpose:
    This script creates tables in the 'bronze' schema, dropping existing tables 
    if they already exist.
	  Run this script to re-define the DDL structure of 'bronze' Tables
===============================================================================
*/

IF OBJECT_ID('bronze.railway', 'U') IS NOT NULL
    DROP TABLE bronze.railway;
CREATE TABLE bronze.railway(
    Transaction_ID           NVARCHAR(50),
    Date_of_Purchase         DATE,
    Time_of_Purchase         TIME,
    Purchase_Type            NVARCHAR(50),
    Payment_Method           NVARCHAR(50),
    Railcard                 NVARCHAR(50),
    Ticket_Class             NVARCHAR(50),
    Ticket_Type              NVARCHAR(50),
    Price                    DECIMAL(10,2),
    Departure_Station        NVARCHAR(100),
    Arrival_Destination      NVARCHAR(100),
    Date_of_Journey          DATE,
    Departure_Time           TIME,
    Arrival_Time             TIME,
    Actual_Arrival_Time      TIME,
    Journey_Status           NVARCHAR(50),
    Reason_for_Delay         NVARCHAR(100),
    Refund_Request           NVARCHAR(10)
);
GO

/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external CSV file. 
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the `BULK INSERT` command to load data from csv Files to bronze tables.

Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC bronze.load_bronze;
===============================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @load_start_time DATETIME, @load_end_time DATETIME;
    BEGIN TRY
        SET @load_start_time = GETDATE();

        PRINT '============================================================';
        PRINT 'Loading Railway Data to Bronze Layer';
        PRINT '============================================================';
        

        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.railway';
        TRUNCATE TABLE bronze.railway;

        PRINT '>> Inserting Data Into : bronze.railway';
        BULK INSERT bronze.railway
        FROM '/var/opt/mssql/dataWarehouseSets/railway.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST( DATEDIFF(Millisecond, @start_time, @end_time) AS NVARCHAR) + ' millisecond';
        PRINT'------------------------------------------';

        PRINT '============================================================';
        SET @load_end_time = GETDATE();
        PRINT 'Loading Railway Data Is Complete';
        PRINT '- The Railway Data Total Load Duration: ' + CAST( DATEDIFF(Millisecond, @load_start_time, @load_end_time) AS NVARCHAR) + ' millisecond';
        PRINT '============================================================';
    END TRY

    BEGIN CATCH

        PRINT '============================================================';
        PRINT 'Error Occurred During Loading Railway Data';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '============================================================';   

    END CATCH
END
GO

EXEC bronze.load_bronze;