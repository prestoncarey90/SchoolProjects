-- Geography dimension for NYC Cafeteria Inspections
WITH source AS (
   SELECT DISTINCT
       building_number,
       street_name,
       city,
       state,
       bin,
       bbl,
       nta,
       borocode
   FROM {{ ref('stg_cafeteria_inspections') }}
)

SELECT
   {{ dbt_utils.generate_surrogate_key(['building_number', 'street_name', 'city', 'state', 'bin', 'bbl', 'nta', 'borocode']) }} AS ci_geo_sk,
   building_number AS number,
   street_name AS street,
   city AS ci_city,
   state,
   bin,
   bbl AS ci_bbl,
   nta,
   borocode
FROM source