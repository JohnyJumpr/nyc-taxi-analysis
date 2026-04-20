CREATE TABLE taxi_trips (
    id TEXT PRIMARY KEY,
    vendor_id INTEGER,
    pickup_datetime TIMESTAMP,
    dropoff_datetime TIMESTAMP,
    passenger_count INTEGER,
    pickup_longitude NUMERIC,
    pickup_latitude NUMERIC,
    dropoff_longitude NUMERIC,
    dropoff_latitude NUMERIC,
    store_and_fwd_flag TEXT,
    trip_duration INTEGER
);