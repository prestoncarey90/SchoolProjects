-- Fact table for NYC 311 Service Requests
WITH source AS (
   SELECT *
   FROM {{ ref('stg_nyc_311_doedohmh') }}
),

fact_service_request AS (
   SELECT
       {{ dbt_utils.generate_surrogate_key(['service_request_id']) }} AS fact_service_request_sk,
       s.service_request_id AS unique_key,

       d1.date_sk AS created_date_sk,
       NULL AS due_date_sk,
       d2.date_sk AS updated_date_sk,
       d3.date_sk AS closed_date_sk,

       p.problem_sk,
       srg.sr_gov_sk,
       srg2.sr_geo_sk,
       sg.geo_sk,

       CASE
           WHEN s.created_date IS NOT NULL AND s.closed_date IS NOT NULL THEN DATE_DIFF(s.closed_date, s.created_date, DAY)
       END AS count_days_created_to_closed,
       NULL AS count_business_days_created_to_closed,
       s.resolution_description,
       s.latitude,
       s.longitude,
       s.x_coordinate_state_plane,
       s.y_coordinate_state_plane,
       CURRENT_TIMESTAMP() AS sr_dw_inserted_at,
       NULL AS sr_dw_updated_at
   FROM source s
   LEFT JOIN {{ ref('dim_shared_date') }} d1 ON d1.full_date = s.created_date
   LEFT JOIN {{ ref('dim_shared_date') }} d2 ON d2.full_date = s.resolution_action_updated_date
   LEFT JOIN {{ ref('dim_shared_date') }} d3 ON d3.full_date = s.closed_date
   LEFT JOIN {{ ref('dim_problem') }} p ON p.complaint_type = s.complaint_type AND p.descriptor = s.descriptor AND p.open_data_channel_type = s.open_data_channel_type AND p.status = s.status
   LEFT JOIN {{ ref('dim_sr_government') }} srg ON srg.agency = s.agency AND srg.agency_name = s.agency_name AND srg.sr_community_board = s.community_board AND srg.police_precinct = s.police_precinct
   LEFT JOIN {{ ref('dim_sr_geography') }} srg2 ON srg2.incident_address = s.incident_address AND srg2.street_name = s.street_name AND srg2.cross_street_1 = s.cross_street_1 AND srg2.cross_street_2 = s.cross_street_2 AND srg2.intersection_street_1 = s.intersection_street_1 AND srg2.intersection_street_2 = s.intersection_street_2 AND srg2.address_type = s.address_type AND srg2.sr_city = s.city AND srg2.landmark = s.landmark AND srg2.sr_bbl = s.bbl
   LEFT JOIN {{ ref('dim_shared_geography') }} sg ON sg.borough = s.borough AND sg.zip_code = s.incident_zip AND sg.council_district = s.council_district
)

SELECT *
FROM fact_service_request
