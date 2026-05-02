-- Violation dimension for NYC Cafeteria Inspections
WITH source AS (
   SELECT DISTINCT
       violation_level,
       violation_code,
       violation_description
   FROM {{ ref('stg_cafeteria_inspections') }}
)

SELECT
   {{ dbt_utils.generate_surrogate_key(['violation_level', 'violation_code']) }} AS violation_sk,
   violation_level AS level,
   violation_code AS code,
   violation_description
FROM source