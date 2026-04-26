/*
===============================================================================
Stored Procedure: Load Silver_3NF Layer (Silver -> Silver_3NF)
===============================================================================
Script Purpose:
    This stored procedure performs the normalization process to populate the 
    3NF schema from the flat 'silver.railway' table.
	Actions Performed:
		- Truncates existing 3NF tables (in reverse order of FKs).
		- Populates Routes and Route_Schedule (Reference Data).
		- Populates Journey_Status (Status Metadata).
		- Populates Journey_Instance (The specific trip occurrences).
		- Populates Transaction_T (The ticket sales).
		
Parameters:
    None.

Usage Example:
    EXEC silver_3NF.load_silver_3NF;
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver_3NF.load_silver_3NF AS
BEGIN
    DECLARE @start_time AS DATETIME, @load_start_time AS DATETIME, @end_time AS DATETIME, @load_end_time AS DATETIME;
    
    BEGIN TRY
        SET @load_start_time = GETDATE();


        PRINT '============================================================';
        PRINT 'Loading Silver_3NF Layer - Railway Data';
        PRINT '============================================================';
        
        -- ====================================================================
        -- Step 1: Cleaning tables in correct order 
        -- ====================================================================
        PRINT '';
        PRINT '------------------------------------------------------------';
        PRINT 'Cleaning Tables';
        PRINT '------------------------------------------------------------';
        
        SET @start_time = GETDATE();

        -- Using DELETE for tables with Foreign Key constraints as TRUNCATE may fail
        DELETE FROM silver_3NF.Transaction_T; 
        DELETE FROM silver_3NF.Journey_Instance;
        DELETE FROM silver_3NF.Journey_Status;
        DELETE FROM silver_3NF.Route_Schedule;
        DELETE FROM silver_3NF.Routes;

        -- Reset Identity seeds
        DBCC CHECKIDENT ('silver_3NF.Routes', RESEED, 0);
        DBCC CHECKIDENT ('silver_3NF.Route_Schedule', RESEED, 0);
        DBCC CHECKIDENT ('silver_3NF.Journey_Status', RESEED, 0);
        DBCC CHECKIDENT ('silver_3NF.Journey_Instance', RESEED, 0);
        
        SET @end_time = GETDATE();
        PRINT '>> Truncate Duration: ' + CAST(DATEDIFF(Millisecond, @start_time, @end_time) AS NVARCHAR) + ' millisecond';
        PRINT '------------------------------------------';

        PRINT '';
        PRINT '------------------------------------------------------------';
        PRINT 'Loading Tables';
        PRINT '------------------------------------------------------------';


        -- ====================================================================
        -- Step 2: Load Routes 
        -- ====================================================================

        SET @start_time = GETDATE();
        PRINT '>> Inserting Data Into: silver_3NF.Routes';
        INSERT INTO silver_3NF.Routes (Departure_Station, Arrival_Destination,Route_Name)
        SELECT DISTINCT 
            Departure_Station, 
            Arrival_Destination,
            'From ' + sd.code + ' To ' + sa.code AS Route_Name
        FROM silver.railway r
        LEFT JOIN silver.Stations_Code sd
            ON r.Departure_Station = sd.station_name
        LEFT JOIN silver.Stations_Code sa
            ON r.Arrival_Destination = sa.station_name;

        SET @end_time = GETDATE();
        PRINT '   - Load Duration: ' + CAST(DATEDIFF(Millisecond, @start_time, @end_time) AS NVARCHAR) + ' millisecond';
        PRINT '------------------------------------------';


        -- ====================================================================
        -- Step 3: Load Route_Schedule 
        -- ====================================================================
        SET @start_time = GETDATE();
        PRINT '>> Inserting Data Into: silver_3NF.Route_Schedule';
        INSERT INTO silver_3NF.Route_Schedule (Route_ID, Journey_Time_Day_Part , Departure_Time, Arrival_Time, Route_Duration_Minutes)
        SELECT DISTINCT 
            r.Route_ID, 
            s.Journey_Time_Day_Part,
            s.Departure_Time, 
            s.Arrival_Time,
            s.Route_Duration_Minutes

        FROM silver.railway s
        JOIN silver_3NF.Routes r 
            ON s.Departure_Station = r.Departure_Station 
            AND s.Arrival_Destination = r.Arrival_Destination;


        SET @end_time = GETDATE();
        PRINT '   - Load Duration: ' + CAST(DATEDIFF(Millisecond, @start_time, @end_time) AS NVARCHAR) + ' millisecond';
        PRINT '------------------------------------------';


        -- ====================================================================
        -- Step 4: Load Journey_Status 
        -- ====================================================================
        SET @start_time = GETDATE();
        PRINT '>> Inserting Data Into: silver_3NF.Journey_Status';
        
        INSERT INTO silver_3NF.Journey_Status (Status, Reason_for_Delay)
        SELECT DISTINCT 
            Journey_Status, 
            Reason_for_Delay
        FROM silver.railway;
        
       SET @end_time = GETDATE();
        PRINT '   - Load Duration: ' + CAST(DATEDIFF(Millisecond, @start_time, @end_time) AS NVARCHAR) + ' millisecond';
        PRINT '------------------------------------------';


        -- ====================================================================
        -- Step 5: Load Journey_Instance 
        -- ====================================================================
        PRINT '';
        PRINT '------------------------------------------------------------';
        PRINT 'Loading Fact Tables';
        PRINT '------------------------------------------------------------';
        
        SET @start_time = GETDATE();
        PRINT '>> Inserting Data Into: silver_3NF.Journey_Instance';
        
        INSERT INTO silver_3NF.Journey_Instance (
                Trip_ID, 
                Journey_Status_ID, 
                Date_of_Journey, 
                Actual_Arrival_Time,
                Actual_Duration_Minutes,
                Delay_Duration_Minutes ,
                Delay_Status ,          
                Performance_Score ,     
                Compensation_Factor     )
        SELECT DISTINCT
            rs.Trip_ID,
            js.Journey_Status_ID,
            s.Date_of_Journey,
            s.Actual_Arrival_Time,
            s.Actual_Duration_Minutes,
            s.Delay_Duration_Minutes ,
            s.Delay_Status,           
            s.Performance_Score ,     
            s.Compensation_Factor    
        FROM silver.railway s
        JOIN silver_3NF.Routes r 
            ON s.Departure_Station = r.Departure_Station 
            AND s.Arrival_Destination = r.Arrival_Destination
        JOIN silver_3NF.Route_Schedule rs 
            ON r.Route_ID = rs.Route_ID 
            AND s.Departure_Time = rs.Departure_Time 
            AND s.Arrival_Time = rs.Arrival_Time
        JOIN silver_3NF.Journey_Status js 
            ON s.Journey_Status = js.Status 
            AND (s.Reason_for_Delay = js.Reason_for_Delay 
            OR (s.Reason_for_Delay IS NULL AND js.Reason_for_Delay IS NULL));
        
        SET @end_time = GETDATE();
        PRINT '   - Load Duration: ' + CAST(DATEDIFF(Millisecond, @start_time, @end_time) AS NVARCHAR) + ' millisecond';
        PRINT '------------------------------------------';


        -- ====================================================================
        -- Step 6: Load Transaction 
        -- ====================================================================
        SET @start_time = GETDATE();
        PRINT '>> Inserting Data Into: silver_3NF.Transaction_T';

        INSERT INTO silver_3NF.Transaction_T (
                Transaction_ID, 
                Date_of_Purchase, 
                Time_of_Purchase,
                Purchase_Time_Day_Part, 
                Purchase_Type, 
                Payment_Method, 
                Railcard, 
                Ticket_Class, 
                Ticket_Type, 
                Ticket_Segment,
                Price, 
                Journey_Instance_ID,
                Refund_Request,
                Price_After_Refund )
        SELECT 
            s.Transaction_ID,
            s.Date_of_Purchase,
            s.Time_of_Purchase,
            s.Purchase_Time_Day_Part,
            s.Purchase_Type,
            s.Payment_Method,
            s.Railcard,
            s.Ticket_Class,
            s.Ticket_Type,
            s.Ticket_Segment,
            s.Price,
            ji.Journey_Instance_ID,
            s.Refund_Request,
            s.Price_After_Refund
        FROM silver.railway s
        JOIN silver_3NF.Routes r 
            ON s.Departure_Station = r.Departure_Station 
            AND s.Arrival_Destination = r.Arrival_Destination
        JOIN silver_3NF.Route_Schedule rs 
            ON r.Route_ID = rs.Route_ID 
            AND s.Departure_Time = rs.Departure_Time 
            AND s.Arrival_Time = rs.Arrival_Time
        JOIN silver_3NF.Journey_Status js 
            ON s.Journey_Status = js.Status 
            AND (s.Reason_for_Delay = js.Reason_for_Delay 
            OR (s.Reason_for_Delay IS NULL AND js.Reason_for_Delay IS NULL))
        JOIN silver_3NF.Journey_Instance ji 
            ON rs.Trip_ID = ji.Trip_ID 
            AND js.Journey_Status_ID = ji.Journey_Status_ID
            AND s.Date_of_Journey = ji.Date_of_Journey
            AND (s.Actual_Arrival_Time = ji.Actual_Arrival_Time OR (s.Actual_Arrival_Time IS NULL AND ji.Actual_Arrival_Time IS NULL));
       
        SET @end_time = GETDATE();
        PRINT '   - Load Duration: ' + CAST(DATEDIFF(Millisecond, @start_time, @end_time) AS NVARCHAR) + ' millisecond';
        PRINT '------------------------------------------';

        PRINT '============================================================';
        SET @load_end_time = GETDATE();
        PRINT 'Normalization to Silver_3NF Complete';
        PRINT '- Total Load Duration: ' + CAST(DATEDIFF(ms, @load_start_time, @load_end_time) AS NVARCHAR) + ' millisecond';
        PRINT '============================================================';

    END TRY
    BEGIN CATCH
        PRINT '============================================================';
        PRINT 'ERROR OCCURRED DURING 3NF NORMALIZATION';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number:  ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State:   ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '============================================================';
    END CATCH
END;
GO

-- Execute the procedure
EXEC silver_3NF.load_silver_3NF;

SELECT
    *   
FROM silver_3NF.Routes