/*
===============================================================================
Quality Checks - Railway Data
===============================================================================
Script Purpose:
    This script performs various quality checks for data consistency, accuracy, 
    and standardization across the 'silver.railway' table. It includes checks for:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid date ranges and orders.
    - Data consistency between related fields.
    - Valid time formats and logical time sequences.

Usage Notes:
    - Run these checks after data loading Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

-- ====================================================================
-- Checking 'silver.railway'
-- ====================================================================

-- Check for NULLs or Duplicates in Primary Key (Transaction ID)
-- Expectation: No Results
SELECT 
    Transaction_ID,
    COUNT(*) 
FROM silver.railway
GROUP BY Transaction_ID
HAVING COUNT(*) > 1 OR Transaction_ID IS NULL;

-- Check for Unwanted Spaces in String Fields
-- Expectation: No Results
SELECT 
    Transaction_ID
FROM silver.railway
WHERE Transaction_ID != TRIM(Transaction_ID)
   OR Purchase_Type != TRIM(Purchase_Type)
   OR Payment_Method != TRIM(Payment_Method)
   OR Railcard != TRIM(Railcard)
   OR Ticket_Class != TRIM(Ticket_Class)
   OR Ticket_Type != TRIM(Ticket_Type)
   OR Departure_Station != TRIM(Departure_Station)
   OR Arrival_Destination != TRIM(Arrival_Destination)
   OR Journey_Status != TRIM(Journey_Status);

-- Data Standardization & Consistency - Purchase Type
-- Expectation: Review Valid Values
SELECT DISTINCT 
    Purchase_Type 
FROM silver.railway
ORDER BY Purchase_Type;

-- Data Standardization & Consistency - Payment Method
-- Expectation: Review Valid Values
SELECT DISTINCT 
    Payment_Method 
FROM silver.railway
ORDER BY Payment_Method;

-- Data Standardization & Consistency - Railcard Type
-- Expectation: Review Valid Values
SELECT DISTINCT 
    Railcard 
FROM silver.railway
ORDER BY Railcard;

-- Data Standardization & Consistency - Ticket Class
-- Expectation: Review Valid Values
SELECT DISTINCT 
    Ticket_Class 
FROM silver.railway
ORDER BY Ticket_Class;

-- Data Standardization & Consistency - Ticket Type
-- Expectation: Review Valid Values
SELECT DISTINCT 
    Ticket_Type 
FROM silver.railway
ORDER BY Ticket_Type;

-- Data Standardization & Consistency - Journey Status
-- Expectation: Review Valid Values
SELECT DISTINCT 
    Journey_Status 
FROM silver.railway
ORDER BY Journey_Status;

-- Data Standardization & Consistency - Refund Request
-- Expectation: Should be 'Yes' or 'No' only
SELECT DISTINCT 
    Refund_Request 
FROM silver.railway
ORDER BY Refund_Request;

-- Check for NULLs or Negative Values in Price
-- Expectation: No Results
SELECT 
    Transaction_ID,
    Price 
FROM silver.railway
WHERE Price <= 0 OR Price IS NULL;

-- Check for Invalid Date Orders (Purchase Date > Journey Date)
-- Expectation: No Results (Cannot purchase ticket after journey date)
SELECT 
    Transaction_ID,
    Date_of_Purchase,
    Date_of_Journey
FROM silver.railway
WHERE Date_of_Purchase > Date_of_Journey;

-- Check for Invalid time Orders (Time_of_Purchase > Departure_Time)
-- Expectation: No Results (Cannot purchase ticket after journey Time)
SELECT 
    Transaction_ID,
    Date_of_Purchase,
    Date_of_Journey,
    Departure_Time,
    Time_of_Purchase
FROM Silver.railway
WHERE Date_of_Purchase = Date_of_Journey 
      AND Time_of_Purchase >= Departure_Time

-- Check for Invalid Time Orders (Departure Time >= Arrival Time on same day)
-- Expectation: Some results may be valid for overnight journeys
SELECT 
    Transaction_ID,
    Departure_Time,
    Arrival_Time,
    Date_of_Journey
FROM silver.railway
WHERE Departure_Time >= Arrival_Time 
  AND Journey_Status != 'Cancelled';



-- Check Data Consistency: Delayed Journeys Should Have Reason for Delay
-- Expectation: No Results (All delayed journeys should have a reason)
SELECT 
    Transaction_ID,
    Journey_Status,
    Reason_for_Delay
FROM silver.railway
WHERE Journey_Status = 'Delayed' 
  AND (Reason_for_Delay IS NULL OR TRIM(Reason_for_Delay) = '');

-- Check Data Consistency: On Time Journeys Should NOT Have Reason for Delay
-- Expectation: No Results
SELECT 
    Transaction_ID,
    Journey_Status,
    Reason_for_Delay
FROM silver.railway
WHERE Journey_Status = 'On Time' 
  AND Reason_for_Delay IS NOT NULL 
  AND TRIM(Reason_for_Delay) != '';

-- Check Data Consistency: Cancelled Journeys Should Have Reason
-- Expectation: No Results (All cancelled journeys should have a reason)
SELECT 
    Transaction_ID,
    Journey_Status,
    Reason_for_Delay
FROM silver.railway
WHERE Journey_Status = 'Cancelled' 
  AND (Reason_for_Delay IS NULL OR TRIM(Reason_for_Delay) = '');

-- Check Data Consistency: Cancelled Journeys Should Have NULL Actual Arrival Time
-- Expectation: No Results
SELECT 
    Transaction_ID,
    Journey_Status,
    Actual_Arrival_Time
FROM silver.railway
WHERE Journey_Status = 'Cancelled' 
  AND Actual_Arrival_Time IS NOT NULL;


-- Check Data Consistency: Actual Arrival Time Should Match or Be After Scheduled
-- Expectation: No Results
SELECT 
    Transaction_ID,
    Arrival_Time,
    Actual_Arrival_Time,
    Journey_Status
FROM silver.railway
WHERE Actual_Arrival_Time IS NOT NULL
  AND Actual_Arrival_Time >= Arrival_Time
  AND Journey_Status not in ('On Time', 'Delayed') ;

-- Check for Refund Requests on Delayed or Cancelled or On Time Journeys
-- Expectation: Review refund patterns
SELECT 
    Journey_Status,
    Refund_Request,
    COUNT(*) AS Count
FROM silver.railway
WHERE Journey_Status IN ('On Time' ,'Delayed', 'Cancelled')
GROUP BY Journey_Status, Refund_Request
ORDER BY Journey_Status, Refund_Request;

-- Check for Same Departure and Arrival Stations
-- Expectation: No Results (Invalid journeys)
SELECT 
    Transaction_ID,
    Departure_Station,
    Arrival_Destination
FROM silver.railway
WHERE Departure_Station = Arrival_Destination;

-- Check for NULL Critical Fields
-- Expectation: No Results
SELECT 
    Transaction_ID
FROM silver.railway
WHERE Date_of_Purchase IS NULL
   OR Date_of_Journey IS NULL
   OR Departure_Station IS NULL
   OR Arrival_Destination IS NULL
   OR Journey_Status IS NULL;

-- Check for Future Journey Dates (Beyond Reasonable Range)
-- Expectation: No journeys scheduled too far in future
SELECT 
    Transaction_ID,
    Date_of_Journey
FROM silver.railway
WHERE Date_of_Journey > DATEADD(YEAR, 1, GETDATE());


-- Check for NULL Route Duration when both times exist
-- Expectation: No Results
SELECT 
    Transaction_ID,
    Departure_Time,
    Arrival_Time,
    Route_Duration_Minutes
FROM silver.railway
WHERE Departure_Time IS NOT NULL 
  AND Arrival_Time IS NOT NULL
  AND Route_Duration_Minutes IS NULL;

-- Check for Negative Route Duration (Invalid)
-- Expectation: Review cases (may indicate overnight journeys)
SELECT 
    Transaction_ID,
    Departure_Time,
    Arrival_Time,
    Route_Duration_Minutes
FROM silver.railway
WHERE Route_Duration_Minutes < 0;

-- Check for Unreasonably Long Route Durations (> 12 hours)
-- Expectation: Review these cases
SELECT 
    Transaction_ID,
    Departure_Station,
    Arrival_Destination,
    Route_Duration_Minutes,
    Route_Duration_Minutes / 60.0 AS Route_Duration_Hours
FROM silver.railway
WHERE Route_Duration_Minutes > 720
ORDER BY Route_Duration_Minutes DESC;


-- Check for NULL Actual Duration when times exist and journey not cancelled
-- Expectation: No Results
SELECT 
    Transaction_ID,
    Departure_Time,
    Actual_Arrival_Time,
    Journey_Status,
    Actual_Duration_Minutes
FROM silver.railway
WHERE Departure_Time IS NOT NULL 
  AND Actual_Arrival_Time IS NOT NULL
  AND Journey_Status != 'Cancelled'
  AND Actual_Duration_Minutes IS NULL;

-- Check for Cancelled journeys with Actual Duration
-- Expectation: No Results
SELECT 
    Transaction_ID,
    Journey_Status,
    Actual_Duration_Minutes
FROM silver.railway
WHERE Journey_Status = 'Cancelled' 
  AND Actual_Duration_Minutes IS NOT NULL;


-- Check for NULL Delay Duration when times exist and journey not cancelled
-- Expectation: No Results
SELECT 
    Transaction_ID,
    Arrival_Time,
    Actual_Arrival_Time,
    Journey_Status,
    Delay_Duration_Minutes
FROM silver.railway
WHERE Arrival_Time IS NOT NULL 
  AND Actual_Arrival_Time IS NOT NULL
  AND Journey_Status != 'Cancelled'
  AND Delay_Duration_Minutes IS NULL;


-- Check Delayed journeys with zero or minimal delay
-- Expectation: Review these inconsistencies
SELECT 
    Transaction_ID,
    Arrival_Time,
    Actual_Arrival_Time,
    Journey_Status,
    Delay_Duration_Minutes
FROM silver.railway
WHERE Journey_Status = 'Delayed' 
  AND (Delay_Duration_Minutes IS NULL OR Delay_Duration_Minutes <= 0);


-- Check Compensation Factor ranges
-- Expectation: Should only be 0, 0.25, 0.50, 1.00
SELECT DISTINCT 
    Compensation_Factor
FROM silver.railway
WHERE Compensation_Factor NOT IN (0, 0.25, 0.50, 1.00)
ORDER BY Compensation_Factor;

-- Check for mismatched Compensation Factor and Journey Status
-- Expectation: Cancelled journeys should have factor 1.00
SELECT 
    Transaction_ID,
    Journey_Status,
    Delay_Duration_Minutes,
    Compensation_Factor
FROM silver.railway
WHERE Journey_Status = 'Cancelled' 
  AND Compensation_Factor != 1.00;


-- Check for NULL Revenue After Refund
-- Expectation: No Results
SELECT 
    Transaction_ID,
    Price,
    Compensation_Factor,
    Revenue_After_Refund
FROM silver.railway
WHERE Revenue_After_Refund IS NULL;

-- Check for Negative Revenue
-- Expectation: No Results
SELECT 
    Transaction_ID,
    Price,
    Compensation_Factor,
    Revenue_After_Refund
FROM silver.railway
WHERE Revenue_After_Refund < 0;

-- Verify Revenue Calculation: Revenue = Price - (Price * Compensation_Factor)
-- Expectation: No significant discrepancies
SELECT 
    Transaction_ID,
    Journey_Status,
    Price,
    Compensation_Factor,
    Revenue_After_Refund,
    ROUND(Price - (Price * Compensation_Factor), 2) AS Expected_Revenue,
    ROUND(ABS(Revenue_After_Refund - (Price - (Price * Compensation_Factor))), 2) AS Difference
FROM silver.railway
WHERE ABS(Revenue_After_Refund - (Price - (Price * Compensation_Factor))) > 0.01
ORDER BY Difference DESC;

-- Check Cancelled journeys with refund requests should have zero revenue
-- Expectation: Review cases
SELECT 
    Transaction_ID,
    Journey_Status,
    Refund_Request,
    Price,
    Revenue_After_Refund
FROM silver.railway
WHERE Journey_Status = 'Cancelled' 
  AND Refund_Request = 'Yes'
  AND Revenue_After_Refund != 0;

-- ====================================================================
-- Data Quality Summary Report 
-- ====================================================================

SELECT 
    'Total Records' AS Metric,
    COUNT(*) AS Value
FROM silver.railway
UNION ALL
SELECT 
    'Records with NULL Transaction_ID',
    COUNT(*)
FROM silver.railway
WHERE Transaction_ID IS NULL
UNION ALL
SELECT 
    'Records with Negative Price',
    COUNT(*)
FROM silver.railway
WHERE Price < 0
UNION ALL

SELECT 
    'Number_of_journeys',
    COUNT(*) 
FROM (
    SELECT 
        COUNT(*) As No_of_tickets
      ,Departure_Station
      ,Arrival_Destination
      ,Date_of_Journey
      ,Departure_Time
    FROM silver.railway
    GROUP BY 
       Departure_Station
      ,Arrival_Destination
      ,Date_of_Journey
      ,Departure_Time
    ) t
UNION ALL
SELECT 
    'Delayed Journeys',
    COUNT(*)
FROM  (
    SELECT 
        COUNT(*) As No_of_tickets
      ,Departure_Station
      ,Arrival_Destination
      ,Date_of_Journey
      ,Departure_Time
    FROM silver.railway
    WHERE Journey_Status = 'Delayed'
    GROUP BY 
       Departure_Station
      ,Arrival_Destination
      ,Date_of_Journey
      ,Departure_Time
    ) tt
UNION ALL
SELECT 
    'Cancelled Journeys',
    COUNT(*)
FROM  (
    SELECT 
        COUNT(*) As No_of_tickets
      ,Departure_Station
      ,Arrival_Destination
      ,Date_of_Journey
      ,Departure_Time
    FROM silver.railway
    WHERE Journey_Status = 'Cancelled'
    GROUP BY 
       Departure_Station
      ,Arrival_Destination
      ,Date_of_Journey
      ,Departure_Time
    ) tt

UNION ALL
SELECT 
    'Refund Requests',
    COUNT(*)
FROM silver.railway
WHERE Refund_Request = 'Yes'
UNION ALL
SELECT 
    'NULL Route Duration',
    COUNT(*)
FROM silver.railway
WHERE Route_Duration_Minutes IS NULL
UNION ALL
SELECT 
    'NULL Delay Duration',
    COUNT(*)
FROM (
    SELECT 
        COUNT(*) As No_of_tickets
      ,Departure_Station
      ,Arrival_Destination
      ,Date_of_Journey
      ,Departure_Time
      ,Delay_Duration_Minutes
    FROM silver.railway
    GROUP BY 
       Departure_Station
      ,Arrival_Destination
      ,Date_of_Journey
      ,Departure_Time
      ,Delay_Duration_Minutes
    ) tttt
WHERE Delay_Duration_Minutes IS NULL
UNION ALL
SELECT 
    'Journeys with Compensation',
    COUNT(*)
FROM (
    SELECT 
        COUNT(*) As No_of_tickets
      ,Departure_Station
      ,Arrival_Destination
      ,Date_of_Journey
      ,Departure_Time
      ,Compensation_Factor
    FROM silver.railway
    GROUP BY 
       Departure_Station
      ,Arrival_Destination
      ,Date_of_Journey
      ,Departure_Time
      ,Compensation_Factor
    ) ttttt
WHERE Compensation_Factor > 0
UNION ALL
SELECT 
    'Total Original Revenue',
    CAST(ROUND(SUM(Price), 2) AS INT)
FROM silver.railway
UNION ALL
SELECT 
    'Total Revenue After Refund',
    CAST(ROUND(SUM(Revenue_After_Refund), 2) AS INT)
FROM silver.railway
UNION ALL
SELECT 
    'Total Compensation Paid',
    CAST(ROUND(SUM(Price - Revenue_After_Refund), 2) AS INT)
FROM silver.railway;

