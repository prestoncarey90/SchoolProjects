-- Clean and standardize open restaurant application data
-- Keep most recent record per normalized global ID; fallback to objectid when globalid is missing

WITH source AS (
   SELECT * FROM {{ source('raw_restaurants', 'source_nyc_open_restaurant_apps') }}
),

cleaned AS (
   SELECT
       -- Keep all other columns, then replace selected fields with cleaned/cast versions
       * EXCEPT (
           objectid,
           globalid,
           seating_interest_sidewalk,
           restaurant_name,
           legal_business_name,
           doing_business_as_dba,
           bulding_number,
           street,
           borough,
           zip,
           business_address,
           approved_for_sidewalk_seating,
           approved_for_roadway_seating,
           qualify_alcohol,
           latitude,
           longitude,
           time_of_submission
       ),

       -- Identifiers
       CAST(objectid AS STRING) AS application_id,
       CAST(globalid AS STRING) AS global_id,

       -- Restaurant details
       CAST(restaurant_name AS STRING) AS restaurant_name,
       CAST(legal_business_name AS STRING) AS legal_business_name,
       CAST(doing_business_as_dba AS STRING) AS doing_business_as_dba,
       CAST(seating_interest_sidewalk AS STRING) AS seating_interest,

       -- Location fields
       CAST(bulding_number AS STRING) AS stg_building_number,
       CAST(street AS STRING) AS stg_street_name,
       CASE
           WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
           WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
           WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
           WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
           WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
           ELSE 'UNKNOWN or CITYWIDE'
       END AS borough,
       CASE
           WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA', '') THEN NULL
           WHEN LENGTH(CAST(zip AS STRING)) = 5 THEN CAST(zip AS STRING)
           WHEN LENGTH(CAST(zip AS STRING)) = 9 THEN CAST(zip AS STRING)
           WHEN LENGTH(CAST(zip AS STRING)) = 10
               AND REGEXP_CONTAINS(CAST(zip AS STRING), r'^\d{5}-\d{4}')
           THEN CAST(zip AS STRING)
           ELSE NULL
       END AS stg_zip_code,
       CAST(business_address AS STRING) AS business_address,

       -- Status-like fields (standardized to uppercase strings)
       UPPER(TRIM(CAST(approved_for_sidewalk_seating AS STRING))) AS approved_for_sidewalk_seating,
       UPPER(TRIM(CAST(approved_for_roadway_seating AS STRING))) AS approved_for_roadway_seating,
       UPPER(TRIM(CAST(qualify_alcohol AS STRING))) AS qualify_alcohol,

       -- Timestamps and coordinates
       CAST(time_of_submission AS TIMESTAMP) AS time_of_submission,
       CAST(latitude AS DECIMAL) AS latitude,
       CAST(longitude AS DECIMAL) AS longitude,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters
   WHERE objectid IS NOT NULL
   AND borough IS NOT NULL
   -- Remove known bad ZIPs that are exactly 4 digits long
   AND NOT REGEXP_CONTAINS(TRIM(CAST(zip AS STRING)), r'^\d{4}$')

   -- Deduplicate: keep latest submitted row per normalized globalid
   -- (falls back to objectid if globalid is null/blank)
   QUALIFY ROW_NUMBER() OVER (
       PARTITION BY COALESCE(
           NULLIF(UPPER(TRIM(CAST(globalid AS STRING))), ''),
           CAST(objectid AS STRING)
       )
       ORDER BY CAST(time_of_submission AS TIMESTAMP) DESC
   ) = 1
)

SELECT * FROM cleaned
-- Suggested model name: stg_nyc_open_restaurant_apps