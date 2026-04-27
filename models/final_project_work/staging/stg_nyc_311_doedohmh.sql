-- Clean and standardize NYC 311 service request data
-- One row per service request, identified by unique_key
-- Deduplication: keep most recent by created_date if duplicates exist (unlikely)

WITH source AS (
   SELECT *
   FROM {{ source('raw_311', 'source_service_request') }}
),

typed AS (
   SELECT
       -- Select transformed fields explicitly to avoid star/except expansion issues
       -- IDs and core identifiers
       CAST(unique_key AS STRING) AS service_request_id,
       CAST(facility_type AS STRING) AS facility_type,

       -- Agency information
       CAST(agency AS STRING) AS agency,
       CAST(agency_name AS STRING) AS agency_name,
       CAST(complaint_type AS STRING) AS complaint_type,
       CAST(descriptor AS STRING) AS descriptor,
       CAST(descriptor_2 AS STRING) AS descriptor_2,
       CAST(status AS STRING) AS status,
       CAST(open_data_channel_type AS STRING) AS open_data_channel_type,

       -- Resolution tracking
       CAST(resolution_description AS STRING) AS resolution_description,

       -- Location type and address fields
       CAST(address_type AS STRING) AS address_type,
       CAST(location_type AS STRING) AS location_type,
       NULLIF(REGEXP_REPLACE(TRIM(CAST(incident_address AS STRING)), r'\s+', ' '), '') AS incident_address,
       NULLIF(REGEXP_REPLACE(TRIM(CAST(street_name AS STRING)), r'\s+', ' '), '') AS street_name,
       NULLIF(REGEXP_REPLACE(TRIM(CAST(cross_street_1 AS STRING)), r'\s+', ' '), '') AS cross_street_1,
       NULLIF(REGEXP_REPLACE(TRIM(CAST(cross_street_2 AS STRING)), r'\s+', ' '), '') AS cross_street_2,
       NULLIF(REGEXP_REPLACE(TRIM(CAST(intersection_street_1 AS STRING)), r'\s+', ' '), '') AS intersection_street_1,
       NULLIF(REGEXP_REPLACE(TRIM(CAST(intersection_street_2 AS STRING)), r'\s+', ' '), '') AS intersection_street_2,
       NULLIF(REGEXP_REPLACE(TRIM(CAST(landmark AS STRING)), r'\s+', ' '), '') AS landmark,

       -- Borough normalization for cleaner dimensional joins
       CASE
           WHEN UPPER(REGEXP_REPLACE(TRIM(CAST(borough AS STRING)), r'\s+', ' ')) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
           WHEN UPPER(REGEXP_REPLACE(TRIM(CAST(borough AS STRING)), r'\s+', ' ')) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
           WHEN UPPER(REGEXP_REPLACE(TRIM(CAST(borough AS STRING)), r'\s+', ' ')) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
           WHEN UPPER(REGEXP_REPLACE(TRIM(CAST(borough AS STRING)), r'\s+', ' ')) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
           WHEN UPPER(REGEXP_REPLACE(TRIM(CAST(borough AS STRING)), r'\s+', ' ')) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
           WHEN NULLIF(REGEXP_REPLACE(TRIM(CAST(borough AS STRING)), r'\s+', ' '), '') IS NULL THEN NULL
           ELSE INITCAP(REGEXP_REPLACE(TRIM(CAST(borough AS STRING)), r'\s+', ' '))
       END AS borough,

       CAST(city AS STRING) AS city,

       -- Zip code cleanup
       CASE
           WHEN NULLIF(TRIM(CAST(incident_zip AS STRING)), '') IS NULL THEN NULL
           WHEN REGEXP_CONTAINS(TRIM(CAST(incident_zip AS STRING)), r'^\d{5}$') THEN TRIM(CAST(incident_zip AS STRING))
           WHEN REGEXP_CONTAINS(TRIM(CAST(incident_zip AS STRING)), r'^\d{5}-\d{4}$') THEN TRIM(CAST(incident_zip AS STRING))
           ELSE NULL
       END AS incident_zip,

       -- Parks-related fields
       CAST(park_borough AS STRING) AS park_borough,
       CAST(park_facility_name AS STRING) AS park_facility_name,

       -- Geography and governance fields
       CAST(community_board AS STRING) AS community_board,
       CAST(council_district AS STRING) AS council_district,
       CAST(police_precinct AS STRING) AS police_precinct,
       CAST(bbl AS STRING) AS bbl,

       -- Timestamps: split into DATE and TIME
       SAFE_CAST(created_date AS TIMESTAMP) AS created_ts,
       SAFE_CAST(closed_date AS TIMESTAMP) AS closed_ts,
       SAFE_CAST(resolution_action_updated_date AS TIMESTAMP) AS resolution_action_updated_ts,

       -- Coordinates
       SAFE_CAST(latitude AS DECIMAL) AS latitude,
       SAFE_CAST(longitude AS DECIMAL) AS longitude,
       SAFE_CAST(x_coordinate_state_plane AS DECIMAL) AS x_coordinate_state_plane,
       SAFE_CAST(y_coordinate_state_plane AS DECIMAL) AS y_coordinate_state_plane

   FROM source
),

cleaned AS (
   SELECT
       service_request_id,
       facility_type,
       agency,
       agency_name,
       complaint_type,
       descriptor,
       descriptor_2,
       status,
       open_data_channel_type,
       resolution_description,

       address_type,
       location_type,
       incident_address,
       street_name,
       cross_street_1,
       cross_street_2,
       intersection_street_1,
       intersection_street_2,
       landmark,

       borough,
       city,
       incident_zip,

       park_borough,
       park_facility_name,

       community_board,
       council_district,
       police_precinct,
       bbl,

       -- Split timestamps into DATE and TIME for reporting flexibility
       DATE(created_ts) AS created_date,
       TIME(created_ts) AS created_time,
       DATE(closed_ts) AS closed_date,
       TIME(closed_ts) AS closed_time,
       DATE(resolution_action_updated_ts) AS resolution_action_updated_date,
       TIME(resolution_action_updated_ts) AS resolution_action_updated_time,

       latitude,
       longitude,
       x_coordinate_state_plane,
       y_coordinate_state_plane,

       CURRENT_TIMESTAMP() AS sr_stg_loaded_at

   FROM typed
   WHERE service_request_id IS NOT NULL
),

deduped AS (
   SELECT *
   FROM cleaned
   -- Keep most recent by created_date if exact duplicates exist (unique_key should be unique)
   QUALIFY ROW_NUMBER() OVER (
       PARTITION BY service_request_id
       ORDER BY created_date DESC, created_time DESC
   ) = 1
)

SELECT *
FROM deduped
-- Suggested model name: stg_nyc_311_service_requests