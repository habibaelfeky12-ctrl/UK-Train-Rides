/*
===============================================================================
DDL Script: Create Silver_3NF Normalized Tables
===============================================================================
Script Purpose:
    This script creates normalized tables in the 'silver_3NF' schema following 
    Third Normal Form (3NF) principles for the railway ticket database.
    
Tables Created:
    1. Routes - Store unique route information (Departure/Arrival stations)
    2. Route_Schedule - Store scheduled trip information with fixed timetables
    3. Journey_Status - Store journey status types and delay reasons
    4. Journey_Instance - Store specific journey occurrences with actual times
    5. Transaction - Store ticket purchase transactions
    
Usage:
    Run this script to create the normalized 3NF structure
===============================================================================
*/
IF OBJECT_ID('silver_3NF.Transaction_T', 'U') IS NOT NULL
    DROP TABLE silver_3NF.Transaction_T;

IF OBJECT_ID('silver_3NF.Journey_Instance', 'U') IS NOT NULL
    DROP TABLE silver_3NF.Journey_Instance;

IF OBJECT_ID('silver_3NF.Journey_Status', 'U') IS NOT NULL
    DROP TABLE silver_3NF.Journey_Status;

IF OBJECT_ID('silver_3NF.Route_Schedule', 'U') IS NOT NULL
    DROP TABLE silver_3NF.Route_Schedule;

IF OBJECT_ID('silver_3NF.Routes', 'U') IS NOT NULL
    DROP TABLE silver_3NF.Routes;




-- ====================================================================
-- Table 2: Routes
-- ====================================================================

CREATE TABLE silver_3NF.Routes(
    Route_ID                INT IDENTITY(1,1) PRIMARY KEY,
    Departure_Station       NVARCHAR(100) NOT NULL,
    Arrival_Destination     NVARCHAR(100) NOT NULL,
    Route_Name              NVARCHAR(100) NOT NULL
    CONSTRAINT UQ_Route UNIQUE (Departure_Station, Arrival_Destination),

);
GO

-- ====================================================================
-- Table 3: Route_Schedule
-- ====================================================================

CREATE TABLE silver_3NF.Route_Schedule(
    Trip_ID                      INT IDENTITY(1,1) PRIMARY KEY,
    Route_ID                     INT NOT NULL,
    Journey_Time_Day_Part        NVARCHAR(50),
    Departure_Time               TIME NOT NULL,
    Arrival_Time                 TIME NOT NULL,
    Route_Duration_Minutes       INT

    CONSTRAINT FK_Route_Schedule_Route FOREIGN KEY (Route_ID) 
        REFERENCES silver_3NF.Routes(Route_ID),
    CONSTRAINT UQ_Trip UNIQUE (Route_ID, Departure_Time, Arrival_Time)
);
GO

-- ====================================================================
-- Table 4: Journey_Status
-- ====================================================================

CREATE TABLE silver_3NF.Journey_Status(
    Journey_Status_ID       INT IDENTITY(1,1) PRIMARY KEY,
    Status                  NVARCHAR(50) NOT NULL,
    Reason_for_Delay        NVARCHAR(100),
    CONSTRAINT UQ_Status UNIQUE (Status, Reason_for_Delay)
);
GO

-- ====================================================================
-- Table 5: Journey_Instance
-- ====================================================================

CREATE TABLE silver_3NF.Journey_Instance(
    Journey_Instance_ID         INT IDENTITY(1,1) PRIMARY KEY,
    Trip_ID                     INT NOT NULL,
    Journey_Status_ID           INT NOT NULL,
    Date_of_Journey             DATE NOT NULL,
    Actual_Arrival_Time         TIME,
    Actual_Duration_Minutes     INT,
    Delay_Duration_Minutes      INT,
    Delay_Status                NVARCHAR(50),
    Performance_Score           DECIMAL(6,3),
    Compensation_Factor         DECIMAL(6,3)
    CONSTRAINT FK_Journey_Instance_Trip FOREIGN KEY (Trip_ID) 
        REFERENCES silver_3NF.Route_Schedule(Trip_ID),
    CONSTRAINT FK_Journey_Instance_Status FOREIGN KEY (Journey_Status_ID) 
        REFERENCES silver_3NF.Journey_Status(Journey_Status_ID)
);
GO

-- ====================================================================
-- Table 6: Transaction
-- ====================================================================


CREATE TABLE silver_3NF.Transaction_T (
    Transaction_ID              NVARCHAR(50) PRIMARY KEY,
    Date_of_Purchase            DATE,
    Time_of_Purchase            TIME,
    Purchase_Time_Day_Part      NVARCHAR(50),
    Purchase_Type               NVARCHAR(50),
    Payment_Method              NVARCHAR(50),
    Railcard                    NVARCHAR(50),
    Ticket_Class                NVARCHAR(50),
    Ticket_Type                 NVARCHAR(50),
    Ticket_Segment              NVARCHAR(50),
    Price                       DECIMAL(6,2),
    Journey_Instance_ID         INT NOT NULL,
    Refund_Request              NVARCHAR(10),
    Price_After_Refund          DECIMAL(6,2)
    CONSTRAINT FK_Transaction_Journey FOREIGN KEY (Journey_Instance_ID) 
        REFERENCES silver_3NF.Journey_Instance(Journey_Instance_ID)
);
GO


PRINT '============================================================';
PRINT 'Silver_3NF Schema Created Successfully';
PRINT '============================================================';
PRINT 'Tables Created:';
PRINT '  1. Stations';   
PRINT '  2. Routes';         
PRINT '  3. Route_Schedule';  
PRINT '  4. Journey_Status';  
PRINT '  5. Journey_Instance';
PRINT '  6. Transaction';     
PRINT '============================================================';


