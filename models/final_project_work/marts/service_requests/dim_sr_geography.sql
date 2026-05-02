-- Geography dimension for NYC 311 Service Requests
WITH source AS (
   SELECT DISTINCT
       incident_address,
       street_name,
       cross_street_1,
       cross_street_2,
       intersection_street_1,
       intersection_street_2,
       address_type,
       city AS sr_city,
       landmark,
       bbl AS sr_bbl
   FROM {{ ref('stg_nyc_311_doedohmh') }}
)

SELECT
   {{ dbt_utils.generate_surrogate_key(['incident_address', 'street_name', 'cross_street_1', 'cross_street_2', 'intersection_street_1', 'intersection_street_2', 'address_type', 'sr_city', 'landmark', 'sr_bbl']) }} AS sr_geo_sk,
   incident_address,
   street_name,
   cross_street_1,
   cross_street_2,
   intersection_street_1,
   intersection_street_2,
   address_type,
   sr_city,
   landmark,
   sr_bbl
FROM source