-- Problem dimension for NYC 311 Service Requests
WITH source AS (
   SELECT DISTINCT
       complaint_type,
       descriptor,
       open_data_channel_type,
       status
   FROM {{ ref('stg_nyc_311_doedohmh') }}
)

SELECT
   {{ dbt_utils.generate_surrogate_key(['complaint_type', 'descriptor', 'open_data_channel_type', 'status']) }} AS problem_sk,
   complaint_type,
   descriptor,
   open_data_channel_type,
   status
FROM source