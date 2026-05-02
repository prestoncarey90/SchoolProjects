-- Government dimension for NYC 311 Service Requests
WITH source AS (
   SELECT DISTINCT
       agency,
       agency_name,
       community_board,
       police_precinct
   FROM {{ ref('stg_nyc_311_doedohmh') }}
)

SELECT
   {{ dbt_utils.generate_surrogate_key(['agency', 'agency_name', 'community_board', 'police_precinct']) }} AS sr_gov_sk,
   agency,
   agency_name,
   community_board AS sr_community_board,
   police_precinct
FROM source