-- Clean and standardize cafeteria inspections raw data
-- One row per establishment (school) per inspection (composite key)

WITH source AS (
    SELECT *
    FROM {{ source('raw_inspections', 'source_cafeteria_inspections') }}
),

typed AS (
    SELECT
        -- Keep passthrough columns except fields transformed below
        * EXCEPT (
            entityid,
            schoolname,
            number,
            street,
            city,
            state,
            borough,
            zipcode,
            permittee,
            ptet,
            site_type,
            level,
            code,
            violationdescription,
            communityboard,
            councildistrict,
            censustract,
            bin,
            bbl,
            nta,
            inspectiondate,
            lastinspection,
            latitude,
            longitude,
            borocode
        ),

        -- IDs and school info
        NULLIF(TRIM(CAST(entityid AS STRING)), '') AS record_id,
        NULLIF(REGEXP_REPLACE(TRIM(CAST(schoolname AS STRING)), r'\s+', ' '), '') AS school_name,
        NULLIF(REGEXP_REPLACE(TRIM(CAST(number AS STRING)), r'\s+', ' '), '') AS building_number,
        NULLIF(REGEXP_REPLACE(TRIM(CAST(street AS STRING)), r'\s+', ' '), '') AS street_name,
        NULLIF(REGEXP_REPLACE(TRIM(CAST(city AS STRING)), r'\s+', ' '), '') AS city,
        UPPER(NULLIF(REGEXP_REPLACE(TRIM(CAST(state AS STRING)), r'\s+', ' '), '')) AS state,

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

        -- Zip code cleanup
        CASE
            WHEN NULLIF(TRIM(CAST(zipcode AS STRING)), '') IS NULL THEN NULL
            WHEN REGEXP_CONTAINS(TRIM(CAST(zipcode AS STRING)), r'^\d{5}$') THEN TRIM(CAST(zipcode AS STRING))
            WHEN REGEXP_CONTAINS(TRIM(CAST(zipcode AS STRING)), r'^\d{5}-\d{4}$') THEN TRIM(CAST(zipcode AS STRING))
            ELSE NULL
        END AS zip_code,

        NULLIF(REGEXP_REPLACE(TRIM(CAST(permittee AS STRING)), r'\s+', ' '), '') AS permittee,
        NULLIF(REGEXP_REPLACE(TRIM(CAST(ptet AS STRING)), r'\s+', ' '), '') AS ptet,
        NULLIF(REGEXP_REPLACE(TRIM(CAST(site_type AS STRING)), r'\s+', ' '), '') AS site_type,
        NULLIF(REGEXP_REPLACE(TRIM(CAST(level AS STRING)), r'\s+', ' '), '') AS violation_level,
        NULLIF(REGEXP_REPLACE(TRIM(CAST(code AS STRING)), r'\s+', ' '), '') AS violation_code,
        NULLIF(REGEXP_REPLACE(TRIM(CAST(violationdescription AS STRING)), r'\s+', ' '), '') AS violation_description,

        -- Geography and governance fields
        NULLIF(REGEXP_REPLACE(TRIM(CAST(communityboard AS STRING)), r'\s+', ' '), '') AS community_board,
        NULLIF(REGEXP_REPLACE(TRIM(CAST(councildistrict AS STRING)), r'\s+', ' '), '') AS council_district,
        NULLIF(REGEXP_REPLACE(TRIM(CAST(censustract AS STRING)), r'\s+', ' '), '') AS census_tract,
        NULLIF(REGEXP_REPLACE(TRIM(CAST(bin AS STRING)), r'\s+', ' '), '') AS bin,
        NULLIF(REGEXP_REPLACE(TRIM(CAST(bbl AS STRING)), r'\s+', ' '), '') AS bbl,
        NULLIF(REGEXP_REPLACE(TRIM(CAST(nta AS STRING)), r'\s+', ' '), '') AS nta,

        -- Parse timestamps from raw source
        SAFE_CAST(inspectiondate AS TIMESTAMP) AS inspection_ts,
        SAFE_CAST(lastinspection AS TIMESTAMP) AS last_inspection_ts,

        SAFE_CAST(latitude AS FLOAT64) AS latitude,
        SAFE_CAST(longitude AS FLOAT64) AS longitude,
        SAFE_CAST(borocode AS INT64) AS borocode
    FROM source
),

cleaned AS (
    SELECT
        record_id,
        school_name,
        building_number,
        street_name,
        city,
        state,
        borough,
        zip_code,

        -- Split datetime into separate fields for reporting flexibility (keep date only)
        DATE(inspection_ts) AS inspection_date,
        DATE(last_inspection_ts) AS last_inspection_date,

        permittee,
        ptet,
        site_type,
        violation_level,
        violation_code,
        violation_description,

        latitude,
        longitude,
        community_board,
        council_district,
        census_tract,
        bin,
        bbl,
        nta,
        borocode,

        CURRENT_TIMESTAMP() AS ci_stg_loaded_at
    FROM typed
    WHERE record_id IS NOT NULL
),


deduped AS (
    SELECT *
    FROM cleaned
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY
            record_id, school_name, building_number, street_name, city, state, borough, zip_code,
            inspection_date, last_inspection_date,
            permittee, ptet, site_type, violation_level, violation_code, violation_description,
            latitude, longitude, community_board, council_district, census_tract, bin, bbl, nta, borocode
        ORDER BY ci_stg_loaded_at DESC
    ) = 1
)

SELECT *
FROM deduped