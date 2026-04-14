-- Clean and standardize open restaurant application data
-- Apply layered dedupe rules: prior address-based filter + newer business key filters

WITH source AS (
   SELECT * FROM {{ source('raw_restaurants', 'source_nyc_open_restaurant_apps') }}
),

prepared AS (
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
       UPPER(TRIM(CAST(legal_business_name AS STRING))) AS legal_business_name,
       CAST(doing_business_as_dba AS STRING) AS doing_business_as_dba,
       CAST(seating_interest_sidewalk AS STRING) AS seating_interest,

       -- Location fields
       CASE
           WHEN UPPER(TRIM(CAST(bulding_number AS STRING))) = 'UNDEFINED' THEN NULL
           ELSE CAST(bulding_number AS STRING)
       END AS stg_building_number,
       NULLIF(TRIM(REGEXP_REPLACE(
           REGEXP_REPLACE(
               UPPER(CAST(street AS STRING)),
               r"['\.#]",
               ''
           ),
           r'\s+',
           ' '
       )), '') AS stg_street_name,
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

       -- Normalize and standardize business address (uppercase + common abbreviation expansion)
       TRIM(REGEXP_REPLACE(
           REGEXP_REPLACE(
               REGEXP_REPLACE(
                   REGEXP_REPLACE(
                       REGEXP_REPLACE(
                           REGEXP_REPLACE(
                               REGEXP_REPLACE(
                                   REGEXP_REPLACE(
                                       REGEXP_REPLACE(
                                           REGEXP_REPLACE(
                                               UPPER(TRIM(CAST(business_address AS STRING))),
                                               r'\bST\.?\b', 'STREET'
                                           ),
                                           r'\bAVE\.?\b', 'AVENUE'
                                       ),
                                       r'\bRD\.?\b', 'ROAD'
                                   ),
                                   r'\bBLVD\.?\b', 'BOULEVARD'
                               ),
                               r'\bDR\.?\b', 'DRIVE'
                           ),
                           r'\bLN\.?\b', 'LANE'
                       ),
                       r'\bCT\.?\b', 'COURT'
                   ),
                   r'\bPL\.?\b', 'PLACE'
               ),
               r'\s+', ' '
           ),
           r'\s+,', ','
       )) AS business_address,

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
),

filtered AS (
   SELECT *
   FROM prepared
   WHERE application_id NOT IN ('8243', '10420')
),

dedup_stage_0 AS (
   SELECT
       *
   FROM filtered

   -- Prior rule restored:
   -- If normalized legal business name + normalized business address are present and equal,
   -- keep the most recent timestamp.
   QUALIFY ROW_NUMBER() OVER (
       PARTITION BY
           CASE
               WHEN legal_business_name IS NOT NULL
                    AND legal_business_name != ''
                    AND business_address IS NOT NULL
                    AND business_address != ''
               THEN legal_business_name
               ELSE application_id
           END,
           CASE
               WHEN legal_business_name IS NOT NULL
                    AND legal_business_name != ''
                    AND business_address IS NOT NULL
                    AND business_address != ''
               THEN business_address
               ELSE application_id
           END
       ORDER BY time_of_submission DESC
   ) = 1
),

dedup_stage_1 AS (
   SELECT
       *
   FROM dedup_stage_0

   -- New rule 1:
   -- If legal_business_name + stg_zip_code + stg_building_number + stg_street_name are all present and equal,
   -- keep only the most recent timestamp.
   QUALIFY ROW_NUMBER() OVER (
       PARTITION BY
           CASE
               WHEN legal_business_name IS NOT NULL
                    AND legal_business_name != ''
                    AND stg_zip_code IS NOT NULL
                    AND stg_zip_code != ''
                    AND stg_building_number IS NOT NULL
                    AND stg_street_name IS NOT NULL
               THEN legal_business_name
               ELSE application_id
           END,
           CASE
               WHEN legal_business_name IS NOT NULL
                    AND legal_business_name != ''
                    AND stg_zip_code IS NOT NULL
                    AND stg_zip_code != ''
                    AND stg_building_number IS NOT NULL
                    AND stg_street_name IS NOT NULL
               THEN stg_zip_code
               ELSE application_id
           END,
           CASE
               WHEN legal_business_name IS NOT NULL
                    AND legal_business_name != ''
                    AND stg_zip_code IS NOT NULL
                    AND stg_zip_code != ''
                    AND stg_building_number IS NOT NULL
                    AND stg_street_name IS NOT NULL
               THEN stg_building_number
               ELSE application_id
           END,
           CASE
               WHEN legal_business_name IS NOT NULL
                    AND legal_business_name != ''
                    AND stg_zip_code IS NOT NULL
                    AND stg_zip_code != ''
                    AND stg_building_number IS NOT NULL
                    AND stg_street_name IS NOT NULL
               THEN stg_street_name
               ELSE application_id
           END
       ORDER BY time_of_submission DESC
   ) = 1
),

dedup_stage_2 AS (
   SELECT
       *
   FROM dedup_stage_1

   -- New rule 2:
   -- If legal_business_name + stg_zip_code + stg_building_number are present and
   -- either sidewalk or roadway approval is YES, keep only the most recent timestamp.
   QUALIFY ROW_NUMBER() OVER (
       PARTITION BY
           CASE
               WHEN legal_business_name IS NOT NULL
                    AND legal_business_name != ''
                    AND stg_zip_code IS NOT NULL
                    AND stg_zip_code != ''
                    AND stg_building_number IS NOT NULL
                    AND (
                        approved_for_sidewalk_seating = 'YES'
                        OR approved_for_roadway_seating = 'YES'
                    )
               THEN legal_business_name
               ELSE application_id
           END,
           CASE
               WHEN legal_business_name IS NOT NULL
                    AND legal_business_name != ''
                    AND stg_zip_code IS NOT NULL
                    AND stg_zip_code != ''
                    AND stg_building_number IS NOT NULL
                    AND (
                        approved_for_sidewalk_seating = 'YES'
                        OR approved_for_roadway_seating = 'YES'
                    )
               THEN stg_zip_code
               ELSE application_id
           END,
           CASE
               WHEN legal_business_name IS NOT NULL
                    AND legal_business_name != ''
                    AND stg_zip_code IS NOT NULL
                    AND stg_zip_code != ''
                    AND stg_building_number IS NOT NULL
                    AND (
                        approved_for_sidewalk_seating = 'YES'
                        OR approved_for_roadway_seating = 'YES'
                    )
               THEN stg_building_number
               ELSE application_id
           END
       ORDER BY time_of_submission DESC
   ) = 1
),

cleaned AS (
   SELECT *
   FROM dedup_stage_2
)

SELECT * FROM cleaned
-- Suggested model name: stg_nyc_open_restaurant_apps