/*
NYC Taxi SQL Project
File: 02_cleaning.sql
Purpose: build cleaned working tables
*/

-- Drop previous working tables if they already exist.
DROP TABLE IF EXISTS taxi_trips_sample;
DROP TABLE IF EXISTS taxi_trips_clean;
DROP TABLE IF EXISTS taxi_trips_clean_all;

-- Create a sample table for fast iteration

CREATE TABLE taxi_trips_sample AS
SELECT *
FROM taxi_trips
LIMIT 100000;

/*
Clean the sample table
- positive trip duration only
- exclude very long trips (> 2 hours)
- keep realistic passenger counts
- remove rows with missing coordinates
*/
-- ---------------------------------------------
CREATE TABLE taxi_trips_clean AS
SELECT *
FROM taxi_trips_sample
WHERE trip_duration > 0
  AND trip_duration < 7200
  AND passenger_count BETWEEN 1 AND 6
  AND pickup_longitude IS NOT NULL
  AND pickup_latitude IS NOT NULL
  AND dropoff_longitude IS NOT NULL
  AND dropoff_latitude IS NOT NULL;

/*
Create a fully cleaned table on all rows
Use this table for final results/dashboard
*/
CREATE TABLE taxi_trips_clean_all AS
SELECT *
FROM taxi_trips
WHERE trip_duration > 0
  AND trip_duration < 7200
  AND passenger_count BETWEEN 1 AND 6
  AND pickup_longitude IS NOT NULL
  AND pickup_latitude IS NOT NULL
  AND dropoff_longitude IS NOT NULL
  AND dropoff_latitude IS NOT NULL;
