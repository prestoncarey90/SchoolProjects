-- Shared geography dimension for NYC 311 Service Requests & Cafeteria Inspections
WITH geography_rows AS (
   -- Collect distinct shared geography attributes from both marts
   SELECT DISTINCT
       borough,
       incident_zip AS zip_code,
       council_district
   FROM {{ ref('stg_nyc_311_doedohmh') }}
   WHERE borough IS NOT NULL
      OR incident_zip IS NOT NULL
      OR council_district IS NOT NULL

   UNION DISTINCT

   SELECT DISTINCT
       borough,
       zip_code,
       council_district
   FROM {{ ref('stg_cafeteria_inspections') }}
   WHERE borough IS NOT NULL
      OR zip_code IS NOT NULL
      OR council_district IS NOT NULL
),

dim_shared_geography AS (
   SELECT
       {{ dbt_utils.generate_surrogate_key(['borough', 'zip_code', 'council_district']) }} AS geo_sk,
       borough,
       zip_code,
       council_district
   FROM geography_rows
)

SELECT *
FROM dim_shared_geography