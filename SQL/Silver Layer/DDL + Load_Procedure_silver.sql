
/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'silver' schema, dropping existing tables 
    if they already exist.
	  Run this script to re-define the DDL structure of 'silver' Tables
===============================================================================
*/

-- Table 1: Stations code table
IF OBJECT_ID('silver.railway', 'U') IS NOT NULL
    DROP TABLE silver.railway;

IF OBJECT_ID('silver.Stations_Code', 'U') IS NOT NULL
    DROP TABLE silver.Stations_Code;
CREATE TABLE silver.Stations_Code(
    code	        NVARCHAR(100) ,
    lat             NVARCHAR(100),
    long            NVARCHAR(100),
    station_name    NVARCHAR(100) PRIMARY KEY
);
GO


CREATE TABLE silver.railway(
    Transaction_ID           NVARCHAR(50),
    Date_of_Purchase         DATE,
    Time_of_Purchase         TIME,
    Purchase_Type            NVARCHAR(50),
    Payment_Method           NVARCHAR(50),
    Railcard                 NVARCHAR(50),
    Ticket_Class             NVARCHAR(50),
    Ticket_Type              NVARCHAR(50),
    Price                    DECIMAL(6,2),
    Departure_Station        NVARCHAR(100),
    Arrival_Destination      NVARCHAR(100),
    Date_of_Journey          DATE,
    Departure_Time           TIME,
    Arrival_Time             TIME,
    Actual_Arrival_Time      TIME,
    Journey_Status           NVARCHAR(50),
    Reason_for_Delay         NVARCHAR(100),
    Refund_Request           NVARCHAR(10),
    -- ========== DERIVED COLUMNS ==========
    Route_Name               NVARCHAR(100),
    Purchase_Time_Day_Part   NVARCHAR(50),
    Journey_Time_Day_Part    NVARCHAR(50),
    Route_Duration_Minutes   INT,
    Actual_Duration_Minutes  INT,
    Delay_Duration_Minutes   INT,
    Delay_Status             NVARCHAR(50),
    Compensation_Factor      DECIMAL(6,3),
    Ticket_Segment           NVARCHAR(50),
    Performance_Score        DECIMAL(6,3),
    Price_After_Refund       DECIMAL(6,2)

);
GO





/*
===============================================================================
Stored Procedure: Load Silver Layer - Railway Data (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver.railway' table from the 'bronze.railway' table.
	Actions Performed:
		- Truncates Silver railway table.
		- Inserts transformed and cleansed data from Bronze into Silver.
		- Applies data quality rules and standardization.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/

CREATE OR ALTER PROCEDURE Silver.load_silver AS
BEGIN
    DECLARE @start_time AS DATETIME, @load_start_time AS DATETIME, @end_time AS DATETIME, @load_end_time AS DATETIME;
    BEGIN TRY
        SET @load_start_time = GETDATE();

        -- ====================================================================
        -- Step 1: Load Stations Code
        -- ====================================================================
        SET @start_time = GETDATE();

        -- Insert Railway Table in Silver Schema
        PRINT '>> Truncating Table: silver.Stations_Code';
        TRUNCATE TABLE silver.Stations_Code;

        PRINT '>> Inserting Data Into: silver.Stations_Code';
        BULK INSERT silver.Stations_Code
        FROM '/var/opt/mssql/dataWarehouseSets/stations.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '\n',
            TABLOCK
        );


        -- Drop '[ColumnName]' from table '[TableName]' in schema '[dbo]'
        ALTER TABLE silver.Stations_Code
            DROP COLUMN [lat] ;
        

        ALTER TABLE silver.Stations_Code
            DROP COLUMN [long];
        

        UPDATE silver.Stations_Code
        SET code = REPLACE(code, '"', '');
        

        UPDATE silver.Stations_Code
        SET station_name = REPLACE(station_name, '"', '');
        

        UPDATE silver.Stations_Code
        SET station_name = 
            CASE
                WHEN station_name = 'Edinburgh' THEN 'Edinburgh Waverley'
                WHEN station_name = 'Edinburgh Waverley' THEN 'Edinburgh Waverley'
                WHEN station_name = 'Swindon (Wilts)' THEN 'Swindon'
                WHEN station_name = 'London St Pancras International' THEN 'London St Pancras'
                WHEN station_name = 'Warrington Central' THEN 'Warrington'
                WHEN station_name = 'Didcot Parkway' THEN 'Didcot'
                WHEN station_name = 'Wakefield Westgate' THEN 'Wakefield'
            ELSE station_name
            END;
        
        

        SET @end_time = GETDATE();
        PRINT '   - Load Duration: ' + CAST(DATEDIFF(Millisecond, @start_time, @end_time) AS NVARCHAR) + ' millisecond';
        PRINT '------------------------------------------';
        PRINT '============================================================';
        PRINT 'Loading Silver Layer - Railway Data';
        PRINT '============================================================';
        
        SET @start_time = GETDATE();

        -- Insert Railway Table in Silver Schema
        PRINT '>> Truncating Table: silver.railway';
        TRUNCATE TABLE silver.railway;
        
        PRINT '>> Inserting Data Into: silver.railway';
        INSERT INTO silver.railway (
            Transaction_ID,
            Date_of_Purchase,
            Time_of_Purchase,
            Purchase_Type,
            Payment_Method,
            Railcard,
            Ticket_Class,
            Ticket_Type,
            Price,
            Departure_Station,
            Arrival_Destination,
            Date_of_Journey,
            Departure_Time,
            Arrival_Time,
            Actual_Arrival_Time,
            Journey_Status,
            Reason_for_Delay,
            Refund_Request,
         -- ========== DERIVED COLUMNS ==========
            Route_Name,
            Purchase_Time_Day_Part,
            Journey_Time_Day_Part,
            Route_Duration_Minutes,
            Actual_Duration_Minutes,
            Delay_Duration_Minutes,
            Delay_Status,
            Compensation_Factor,
            Ticket_Segment,
            Performance_Score,
            Price_After_Refund
        )
        SELECT 
            -- Primary Key - Remove spaces and validate
            TRIM(Transaction_ID) AS Transaction_ID,
            
            -- Date of Purchase - Validate reasonable date range
            CASE 
                WHEN Date_of_Purchase IS NULL THEN NULL
                WHEN Date_of_Purchase > GETDATE() THEN NULL
                WHEN Date_of_Purchase > Date_of_Journey THEN NULL
                ELSE Date_of_Purchase
            END AS Date_of_Purchase,
            
            -- Time of Purchase - Validate logical time sequence
            CASE 
                WHEN Time_of_Purchase IS NULL THEN NULL
                WHEN Date_of_Purchase = Date_of_Journey 
                     AND Time_of_Purchase >= Departure_Time THEN NULL
                ELSE Time_of_Purchase
            END AS Time_of_Purchase,
            
            -- Purchase Type - Standardize
            CASE UPPER(TRIM(Purchase_Type))
                WHEN 'ONLINE' THEN 'Online'
                WHEN 'STATION' THEN 'Station'
                ELSE TRIM(Purchase_Type)
            END AS Purchase_Type,
            
            -- Payment Method - Standardize
            CASE UPPER(TRIM(Payment_Method))
                WHEN 'CREDIT CARD' THEN 'Credit Card'
                WHEN 'DEBIT CARD' THEN 'Debit Card'
                WHEN 'CONTACTLESS' THEN 'Contactless'
                ELSE TRIM(Payment_Method)
            END AS Payment_Method,
            
            -- Railcard - Standardize
            CASE 
                WHEN Railcard IS NULL THEN 'No Railcard'
                WHEN UPPER(TRIM(Railcard)) = 'NONE' THEN 'No Railcard'
                WHEN UPPER(TRIM(Railcard)) = 'ADULT' THEN 'Adult'
                WHEN UPPER(TRIM(Railcard)) = 'SENIOR' THEN 'Senior'
                WHEN UPPER(TRIM(Railcard)) = 'DISABLED' THEN 'Disabled'
                WHEN UPPER(TRIM(Railcard)) = '' THEN 'None'
                WHEN UPPER(TRIM(Railcard)) = 'N/A' THEN 'None'
                ELSE TRIM(Railcard)
            END AS Railcard,
            
            -- Ticket Class - Standardize
            CASE UPPER(TRIM(Ticket_Class))
                WHEN 'STANDARD' THEN 'Standard'
                WHEN 'FIRST CLASS' THEN 'First Class'
                ELSE TRIM(Ticket_Class)
            END AS Ticket_Class,
            
            -- Ticket Type - Standardize
            CASE UPPER(TRIM(Ticket_Type))
                WHEN 'ADVANCE' THEN 'Pre-Booked'
                WHEN 'OFF-PEAK' THEN 'Off-Peak'
                WHEN 'ANYTIME' THEN 'Anytime'
                ELSE TRIM(Ticket_Type)
            END AS Ticket_Type,
            
            -- Price - Validate non-negative
            CASE 
                WHEN Price IS NULL THEN 0
                WHEN Price < 0 THEN 0
                ELSE Price
            END AS Price,
            
            -- Departure Station - Clean spaces
            CASE
                WHEN TRIM(Departure_Station)='Edinburgh' then 'Edinburgh Waverley' 
                ELSE TRIM(Departure_Station)
            END AS Departure_Station,
            
            -- Arrival Destination - Clean spaces
            CASE
                WHEN TRIM(Arrival_Destination)='Edinburgh' then 'Edinburgh Waverley' 
                ELSE TRIM(Arrival_Destination)
            END  AS Arrival_Destination,
            
            -- Date of Journey - Validate reasonable date range
            CASE 
                WHEN Date_of_Journey IS NULL THEN NULL
                WHEN Date_of_Journey > DATEADD(YEAR, 2, GETDATE()) THEN NULL
                ELSE Date_of_Journey
            END AS Date_of_Journey,
            
            -- Departure Time
            Departure_Time,
            
            -- Arrival Time
            Arrival_Time,
            
            -- Actual Arrival Time - Should be NULL for Cancelled journeys
            CASE 
                WHEN UPPER(TRIM(Journey_Status)) = 'CANCELLED' THEN NULL
                ELSE Actual_Arrival_Time
            END AS Actual_Arrival_Time,
            
            -- Journey Status - Standardize
            CASE
                WHEN DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time) = 0 THEN 'On Time'
                WHEN UPPER(TRIM(Journey_Status)) = 'ON TIME' THEN 'On Time'
                WHEN UPPER(TRIM(Journey_Status)) = 'DELAYED' THEN 'Delayed'
                WHEN UPPER(TRIM(Journey_Status)) = 'CANCELLED' THEN 'Cancelled'
                ELSE TRIM(Journey_Status)
            END AS Journey_Status,
            
            -- Reason for Delay - Clean and validate consistency with Journey Status
            CASE 
                WHEN UPPER(TRIM(Journey_Status)) = 'ON TIME' THEN 'No Delay'
                WHEN DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time) = 0 THEN 'No Delay'
                WHEN UPPER(TRIM(Journey_Status)) IN ('DELAYED', 'CANCELLED') 
                     AND (Reason_for_Delay IS NULL OR TRIM(Reason_for_Delay) = '') 
                     THEN 'Unknown'
                WHEN UPPER(TRIM(Reason_for_Delay)) IN ('TRAFFIC') 
                     THEN 'Traffic'
                WHEN UPPER(TRIM(Reason_for_Delay)) IN ('TECHNICAL ISSUE', 'TECHNICAL', 'MECHANICAL FAILURE') 
                     THEN 'Technical Issue'
                WHEN UPPER(TRIM(Reason_for_Delay)) IN ('SIGNAL FAILURE', 'SIGNAL ISSUE') 
                     THEN 'Signal Failure'
                WHEN UPPER(TRIM(Reason_for_Delay)) IN ('STAFFING', 'STAFF SHORTAGE') 
                     THEN 'Staff Problem'
                WHEN UPPER(TRIM(Reason_for_Delay)) IN ('WEATHER', 'WEATHER CONDITIONS') 
                     THEN 'Weather'                
                WHEN Reason_for_Delay IS NOT NULL AND TRIM(Reason_for_Delay) != ''
                     THEN TRIM(Reason_for_Delay)
                ELSE 'Unknown'
            END AS Reason_for_Delay,
            
            -- Refund Request - Standardize to Yes/No
           CASE 
             WHEN Journey_Status = 'On Time' THEN 'No'
             WHEN DATEDIFF(MINUTE,Actual_Arrival_Time,Arrival_Time) = 0 THEN 'No'
             WHEN UPPER(REPLACE(TRIM(Refund_Request),char(13),'')) IN ('YES', 'Y') THEN 'Yes'
             WHEN UPPER(REPLACE(TRIM(Refund_Request),char(13),'')) IN ('NO', 'N', '', 'N/A') THEN 'No'
              ELSE 'No'
            END AS Refund_Request,

            -- =========================
            --   The DERIVED COLUMNS 
            -- =========================
            -- define route name to help in analysis
            'From ' + sd.code + ' To ' + sa.code AS Route_Name, 

            -- Categorizes each purchase into a time-of-day segment (Morning, Afternoon, Evening, Night)
            -- based on the hour of Purchase_Time to simplify analysis and reporting            
            CASE 
                WHEN Time_of_Purchase  BETWEEN '05:00:00' AND '11:59:59' THEN 'Morning'
                WHEN Time_of_Purchase  BETWEEN '12:00:00' AND '16:59:59' THEN 'Afternoon'
                WHEN Time_of_Purchase  BETWEEN '17:00:00' AND '20:59:59' THEN 'Evening'
                ELSE 'Night'
            END AS Purchase_Time_Day_Part,

            -- Categorizes each journey into a time-of-day segment (Morning, Afternoon, Evening, Night)
            -- based on the hour of Purchase_Time to simplify analysis and reporting
            CASE 
                WHEN Departure_Time  BETWEEN '05:00:00' AND '11:59:59' THEN 'Morning'
                WHEN Departure_Time  BETWEEN '12:00:00' AND '16:59:59' THEN 'Afternoon'
                WHEN Departure_Time  BETWEEN '17:00:00' AND '20:59:59' THEN 'Evening'
                ELSE 'Night'
            END AS Journey_Time_Day_Part,



            CASE 
                WHEN Departure_Time IS NOT NULL AND Arrival_Time IS NOT NULL
                THEN 
                    CASE 
                        WHEN Arrival_Time > Departure_Time THEN DATEDIFF(MINUTE, Departure_Time, Arrival_Time)
                        ELSE DATEDIFF(MINUTE, Departure_Time, Arrival_Time) + 1440  -- Add 24 hours (1440 minutes) for overnight
                    END
                ELSE NULL
            END AS Route_Duration_Minutes,
            
            -- Actual Duration: Actual Arrival - Scheduled Departure in minutes
            CASE 
                WHEN Departure_Time IS NOT NULL 
                     AND Actual_Arrival_Time IS NOT NULL
                     AND UPPER(TRIM(Journey_Status)) != 'CANCELLED'
                     AND Actual_Arrival_Time > Departure_Time
                    THEN DATEDIFF(MINUTE, Departure_Time, Actual_Arrival_Time)
                WHEN Departure_Time IS NOT NULL 
                     AND Actual_Arrival_Time IS NOT NULL
                     AND UPPER(TRIM(Journey_Status)) != 'CANCELLED'
                     AND Actual_Arrival_Time < Departure_Time
                    THEN DATEDIFF(MINUTE, Departure_Time, Arrival_Time) + 1440  -- Add 24 hours (1440 minutes) for overnight              
                ELSE NULL
            END AS Actual_Duration_Minutes,
            
            -- Delay Duration: Actual Arrival - Scheduled Arrival in minutes
            CASE 
                WHEN Arrival_Time IS NOT NULL 
                     AND Actual_Arrival_Time IS NOT NULL
                     AND UPPER(TRIM(Journey_Status)) != 'CANCELLED'
                THEN DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time)
                ELSE NULL
            END AS Delay_Duration_Minutes,
            
            -- Classifies trip punctuality based on delay ratio (delay time vs total journey duration)
            CASE 
                 WHEN 
                     1.0 * DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time)
                     / NULLIF(DATEDIFF(MINUTE, Departure_Time, Arrival_Time), 0)
                     = 0 THEN 'On Schedule'

                 WHEN 
                     1.0 * DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time)
                     / NULLIF(DATEDIFF(MINUTE, Departure_Time, Arrival_Time), 0)
                     <= 0.5 THEN 'Almost On Time'

                 WHEN 
                     1.0 * DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time)
                     / NULLIF(DATEDIFF(MINUTE, Departure_Time, Arrival_Time), 0)
                     <= 0.20 THEN 'Delayed'

                ELSE 'Critical '
            END AS Delay_Status,
            
            -- Compensation Factor based on delay duration
            CASE 
                WHEN Arrival_Time IS NULL OR Actual_Arrival_Time IS NULL THEN 1.00
                WHEN DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time) < 15 THEN 0
                WHEN DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time) BETWEEN 15 AND 29 THEN 0.25
                WHEN DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time) BETWEEN 30 AND 59 THEN 0.50
                WHEN DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time) >= 60  THEN 1.00
                ELSE 0
            END AS Compensation_Factor,
            
            -- Categorizes tickets into a segments
            CASE 
                WHEN Ticket_Class ='Standard'    AND Ticket_Type ='Advance' THEN 'Budget'
                WHEN Ticket_Class ='Standard'    AND Ticket_Type ='Off-Peak' THEN 'Standard'
                WHEN Ticket_Class ='Standard'    AND Ticket_Type ='Anytime' THEN 'Premium'
                WHEN Ticket_Class ='First Class' AND Ticket_Type ='Advance' THEN 'Premium'
                WHEN Ticket_Class ='First Class' AND Ticket_Type  IN ('Off-Peak','Anytime') THEN 'Luxury'
            END AS Ticket_Segment,

            -- Performance_Score: overall performance metric .
            CASE 
                WHEN (100 - ( (CAST(CASE 
                                        WHEN Actual_Arrival_Time > Arrival_Time 
                                            THEN DATEDIFF(minute, Arrival_Time, Actual_Arrival_Time) 
                                        ELSE 0 END AS FLOAT) 
                                / NULLIF(DATEDIFF(minute, Departure_Time, Arrival_Time), 0)) * 100 
                             * CASE 
                                    WHEN (CAST(Departure_Time AS TIME) BETWEEN '06:00:00' AND '08:00:00') 
                                        OR (CAST(Departure_Time AS TIME) BETWEEN '16:00:00' AND '19:00:00') 
                                        THEN 1.5 
                                    ELSE 1.0 
                                END
                      )) < 0 THEN 0
                ELSE 
                    (100 - ( (CAST(CASE 
                                        WHEN Actual_Arrival_Time > Arrival_Time 
                                            THEN DATEDIFF(minute, Arrival_Time, Actual_Arrival_Time) 
                                        ELSE 0 END AS FLOAT) 
                                / NULLIF(DATEDIFF(minute, Departure_Time, Arrival_Time), 0)) * 100 
                             * CASE 
                                    WHEN (CAST(Departure_Time AS TIME) BETWEEN '06:00:00' AND '08:00:00') 
                                        OR (CAST(Departure_Time AS TIME) BETWEEN '16:00:00' AND '19:00:00') 
                                        THEN 1.5 
                                    ELSE 1.0 
                                END
                      ))
            END AS Performance_Score,

            -- Price After Refund: Price - (Price * Compensation Factor)
            CASE 
                WHEN Price IS NULL OR Price < 0 THEN 0
                WHEN UPPER(TRIM(Journey_Status)) = 'CANCELLED' 
                     AND UPPER(REPLACE(TRIM(Refund_Request), CHAR(13), '')) IN ('YES', 'Y') 
                THEN 0  -- Full refund for cancelled journeys with refund request
                WHEN Arrival_Time IS NULL OR Actual_Arrival_Time IS NULL THEN 0
                ELSE 
                    Price - (Price * 
                        CASE 
                            WHEN DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time) < 15 THEN 0
                            WHEN DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time) BETWEEN 15 AND 29 THEN 0.25
                            WHEN DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time) BETWEEN 30 AND 59 THEN 0.50
                            WHEN DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time) >= 60 THEN 1.00
                            ELSE 0
                        END
                    )
            END AS Price_After_Refund
             

        FROM bronze.railway r
        LEFT JOIN silver.Stations_Code sd
            ON r.Departure_Station = sd.station_name
        LEFT JOIN silver.Stations_Code sa
            ON r.Arrival_Destination = sa.station_name
            
         
        WHERE Transaction_ID IS NOT NULL  -- Filter out records with NULL primary key
          AND TRIM(Transaction_ID) != ''  -- Filter out empty Transaction IDs
          AND Departure_Station IS NOT NULL  -- Must have departure station
          AND Arrival_Destination IS NOT NULL  -- Must have arrival destination
          AND Departure_Station != Arrival_Destination;  -- Cannot be same station

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(Millisecond, @start_time, @end_time) AS NVARCHAR) + ' millisecond';
        PRINT '------------------------------------------';

        PRINT '============================================================';
        SET @load_end_time = GETDATE();
        PRINT 'Loading Silver Layer - Railway Data Is Complete';
        PRINT '- The Railway Silver Layer Total Load Duration: ' + CAST(DATEDIFF(Millisecond, @load_start_time, @load_end_time) AS NVARCHAR) + ' millisecond';
        PRINT '============================================================';
        
    END TRY
    BEGIN CATCH
        PRINT '============================================================';
        PRINT 'Error Occurred During Loading Silver Layer - Railway Data';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '============================================================';  
    END CATCH
END;
GO


-- ===============================================================================
-- Execute the Silver.load_silver procedure
-- ===============================================================================
EXEC Silver.load_silver;

SELECT DISTINCT
    Route_Name,
    Departure_Station,
    Arrival_Destination
FROM silver.railway
      



      


