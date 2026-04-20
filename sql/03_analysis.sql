/*
NYC Taxi SQL Project
File: 03_analysis.sql
Purpose: exploratory analysis and dashboard prep
*/

-- SECTION 1 - Basic trip volume and duration analysis

-- Trips per day
SELECT
    DATE(pickup_datetime) AS trip_date,
    COUNT(*) AS nb_trips
FROM taxi_trips_clean
GROUP BY trip_date
ORDER BY trip_date;

-- Trips per hour (rush hours)
SELECT
    EXTRACT(HOUR FROM pickup_datetime) AS pickup_hour,
    COUNT(*) AS nb_trips
FROM taxi_trips_clean
GROUP BY pickup_hour
ORDER BY nb_trips DESC;

-- Average trip duration in minutes
SELECT
    ROUND(AVG(trip_duration / 60.0), 2) AS avg_trip_duration_min
FROM taxi_trips_clean;

-- Trips by day of week
SELECT
    TRIM(TO_CHAR(pickup_datetime, 'Day')) AS day_of_week,
    COUNT(*) AS nb_trips
FROM taxi_trips_clean
GROUP BY day_of_week
ORDER BY nb_trips DESC;

-- Weekday vs weekend comparison
SELECT
    CASE
        WHEN EXTRACT(DOW FROM pickup_datetime) IN (0, 6) THEN 'weekend'
        ELSE 'weekday'
    END AS period,
    COUNT(*) AS nb_trips,
	ROUND(
    COUNT(*)::numeric / COUNT(DISTINCT DATE(pickup_datetime)),
    2
	) AS avg_trips_per_day,
    ROUND(AVG(trip_duration / 60.0), 2) AS avg_trip_duration_min
FROM taxi_trips_clean
GROUP BY period;

-- Peak hours by weekday
SELECT
    TRIM(TO_CHAR(pickup_datetime, 'Day')) AS day_of_week,
    EXTRACT(HOUR FROM pickup_datetime) AS pickup_hour,
    COUNT(*) AS nb_trips,
    ROUND(AVG(trip_duration / 60.0), 2) AS avg_trip_duration_min
FROM taxi_trips_clean
GROUP BY day_of_week, pickup_hour
ORDER BY nb_trips DESC
LIMIT 20;

-- Trips and average duration by passenger count
SELECT
    passenger_count,
    COUNT(*) AS nb_trips,
    ROUND(AVG(trip_duration / 60.0), 2) AS avg_trip_duration_min
FROM taxi_trips_clean
GROUP BY passenger_count
ORDER BY passenger_count;

-- SECTION 2 - Distance and speed calculations

-- Trip duration against estimated Haversine distance (km)
SELECT
    id,
    ROUND(trip_duration / 60.0, 2) AS trip_duration_min,
    ROUND(
        (
            (6371000 * 2 * ASIN(
                SQRT(
                    POWER(SIN(RADIANS(dropoff_latitude - pickup_latitude) / 2), 2)
                    + COS(RADIANS(pickup_latitude))
                    * COS(RADIANS(dropoff_latitude))
                    * POWER(SIN(RADIANS(dropoff_longitude - pickup_longitude) / 2), 2)
                )
            )
        ) / 1000)::NUMERIC,
        2
    ) AS distance_km
FROM taxi_trips_clean
LIMIT 10;

-- Mean travel speed in km/h
SELECT
    ROUND(
        AVG(
            (
                (
                    6371000 * 2 * ASIN(
                        SQRT(
                            POWER(SIN(RADIANS(dropoff_latitude - pickup_latitude) / 2), 2)
                            + COS(RADIANS(pickup_latitude))
                            * COS(RADIANS(dropoff_latitude))
                            * POWER(SIN(RADIANS(dropoff_longitude - pickup_longitude) / 2), 2)
                        )
                    )
                ) / 1000
            ) / NULLIF(trip_duration / 3600.0, 0)
        )::NUMERIC,
        2
    ) AS avg_speed_kmh
FROM taxi_trips_clean;

-- Average speed and trip count by hour
SELECT
    EXTRACT(HOUR FROM pickup_datetime) AS hour,
    ROUND(AVG((distance_meters / NULLIF(trip_duration, 0)) * 3.6)::NUMERIC, 2) AS avg_speed_kmh,
    COUNT(*) AS nb_trips
FROM (
    SELECT
        pickup_datetime,
        trip_duration,
        6371000 * 2 * ASIN(
            SQRT(
                POWER(SIN(RADIANS(dropoff_latitude - pickup_latitude) / 2), 2)
                + COS(RADIANS(pickup_latitude))
                * COS(RADIANS(dropoff_latitude))
                * POWER(SIN(RADIANS(dropoff_longitude - pickup_longitude) / 2), 2)
            )
        ) AS distance_meters
    FROM taxi_trips_clean
)
GROUP BY hour
ORDER BY hour;

-- SECTION 3 - Anomaly detection

-- Trips with implausibly low or high average speeds
SELECT *
FROM (
    SELECT
        id,
        ROUND(trip_duration / 60.0, 2) AS trip_duration_min,
        ((
            6371000 * 2 * ASIN(
                SQRT(
                    POWER(SIN(RADIANS(dropoff_latitude - pickup_latitude) / 2), 2)
                    + COS(RADIANS(pickup_latitude))
                    * COS(RADIANS(dropoff_latitude))
                    * POWER(SIN(RADIANS(dropoff_longitude - pickup_longitude) / 2), 2)
                )
            )
        ) / trip_duration) * 3.6 AS speed_kmh,
        ROUND(
            (
                (6371000 * 2 * ASIN(
                    SQRT(
                        POWER(SIN(RADIANS(dropoff_latitude - pickup_latitude) / 2), 2)
                        + COS(RADIANS(pickup_latitude))
                        * COS(RADIANS(dropoff_latitude))
                        * POWER(SIN(RADIANS(dropoff_longitude - pickup_longitude) / 2), 2)
                    )
                )
            ) / 1000)::NUMERIC,
            2
        ) AS distance_km
    FROM taxi_trips_clean
)
WHERE speed_kmh < 5 OR speed_kmh > 120;

-- Distribution of trips by speed category
SELECT
    CASE
        WHEN speed_kmh > 120 THEN 'error_fast'
        WHEN speed_kmh < 5 THEN 'very_slow'
        WHEN speed_kmh BETWEEN 5 AND 15 THEN 'congested'
        ELSE 'normal'
    END AS category,
    COUNT(*) AS nb_trips
FROM (
    SELECT
        ((
            6371000 * 2 * ASIN(
                SQRT(
                    POWER(SIN(RADIANS(dropoff_latitude - pickup_latitude) / 2), 2)
                    + COS(RADIANS(pickup_latitude))
                    * COS(RADIANS(dropoff_latitude))
                    * POWER(SIN(RADIANS(dropoff_longitude - pickup_longitude) / 2), 2)
                )
            )
        ) / NULLIF(trip_duration, 0)) * 3.6 AS speed_kmh
    FROM taxi_trips_clean
)
GROUP BY category;

-- Average speed by hour after removing anomalous speeds
WITH trips_with_speed AS (
    SELECT
        pickup_datetime,
        EXTRACT(HOUR FROM pickup_datetime) AS hour,
        ((
            6371000 * 2 * ASIN(
                SQRT(
                    POWER(SIN(RADIANS(dropoff_latitude - pickup_latitude) / 2), 2)
                    + COS(RADIANS(pickup_latitude))
                    * COS(RADIANS(dropoff_latitude))
                    * POWER(SIN(RADIANS(dropoff_longitude - pickup_longitude) / 2), 2)
                )
            )
        ) / NULLIF(trip_duration, 0)) * 3.6 AS speed_kmh
    FROM taxi_trips_clean
),
cleaned AS (
    SELECT *
    FROM trips_with_speed
    WHERE speed_kmh BETWEEN 5 AND 120
)
SELECT
    hour,
    ROUND(AVG(speed_kmh)::NUMERIC, 2) AS avg_speed_kmh,
    COUNT(*) AS nb_trips
FROM cleaned
GROUP BY hour
ORDER BY hour;

-- SECTION 4 - Weekday vs weekend speed analysis

-- Average speed on weekdays vs weekends
WITH trips_with_speed AS (
    SELECT
        pickup_datetime,
        CASE
            WHEN EXTRACT(DOW FROM pickup_datetime) IN (0, 6) THEN 'weekend'
            ELSE 'weekday'
        END AS period,
        ((
            6371000 * 2 * ASIN(
                SQRT(
                    POWER(SIN(RADIANS(dropoff_latitude - pickup_latitude) / 2), 2)
                    + COS(RADIANS(pickup_latitude))
                    * COS(RADIANS(dropoff_latitude))
                    * POWER(SIN(RADIANS(dropoff_longitude - pickup_longitude) / 2), 2)
                )
            )
        ) / NULLIF(trip_duration, 0)) * 3.6 AS speed_kmh
    FROM taxi_trips_clean
)
SELECT
    period,
    ROUND(AVG(speed_kmh)::NUMERIC, 2) AS avg_speed_kmh
FROM trips_with_speed
WHERE speed_kmh BETWEEN 5 AND 120
GROUP BY period;

-- Average speed by hour for weekdays vs weekends
WITH trips_with_speed AS (
    SELECT
        pickup_datetime,
        EXTRACT(HOUR FROM pickup_datetime) AS hour,
        CASE
            WHEN EXTRACT(DOW FROM pickup_datetime) IN (0, 6) THEN 'weekend'
            ELSE 'weekday'
        END AS period,
        ((
            6371000 * 2 * ASIN(
                SQRT(
                    POWER(SIN(RADIANS(dropoff_latitude - pickup_latitude) / 2), 2)
                    + COS(RADIANS(pickup_latitude))
                    * COS(RADIANS(dropoff_latitude))
                    * POWER(SIN(RADIANS(dropoff_longitude - pickup_longitude) / 2), 2)
                )
            )
        ) / NULLIF(trip_duration, 0)) * 3.6 AS speed_kmh
    FROM taxi_trips_clean
),
cleaned AS (
    SELECT *
    FROM trips_with_speed
    WHERE speed_kmh BETWEEN 5 AND 120
)
SELECT
    hour,
    period,
    ROUND(AVG(speed_kmh)::NUMERIC, 2) AS avg_speed_kmh,
    COUNT(*) AS nb_trips
FROM cleaned
GROUP BY hour, period
ORDER BY period, hour;

-- SECTION 5 - Geographic aggregation for dashboarding

-- Average speed and trip count by geographic zone and hour
WITH trips_with_speed AS (
    SELECT
        EXTRACT(HOUR FROM pickup_datetime) AS pickup_hour,
        ROUND(pickup_latitude::NUMERIC, 2) AS lat_zone,
        ROUND(pickup_longitude::NUMERIC, 2) AS lon_zone,
        ((
            6371000 * 2 * ASIN(
                SQRT(
                    POWER(SIN(RADIANS(dropoff_latitude - pickup_latitude) / 2), 2)
                    + COS(RADIANS(pickup_latitude))
                    * COS(RADIANS(dropoff_latitude))
                    * POWER(SIN(RADIANS(dropoff_longitude - pickup_longitude) / 2), 2)
                )
            )
        ) / NULLIF(trip_duration, 0)) * 3.6 AS speed_kmh
    FROM taxi_trips_clean
),
cleaned AS (
    SELECT *
    FROM trips_with_speed
    WHERE speed_kmh BETWEEN 5 AND 120
)
SELECT
    pickup_hour,
    lat_zone,
    lon_zone,
    ROUND(AVG(speed_kmh)::NUMERIC, 2) AS avg_speed_kmh,
    COUNT(*) AS nb_trips
FROM cleaned
GROUP BY pickup_hour, lat_zone, lon_zone
HAVING COUNT(*) > 50;
