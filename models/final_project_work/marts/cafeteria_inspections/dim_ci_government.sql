-- Government dimension for NYC Cafeteria Inspections
WITH source AS (
   SELECT DISTINCT
       community_board,
       census_tract
   FROM {{ ref('stg_cafeteria_inspections') }}
)

SELECT
   {{ dbt_utils.generate_surrogate_key(['community_board', 'census_tract']) }} AS ci_gov_sk,
   community_board,
   census_tract
FROM source