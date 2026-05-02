-- Fact table for NYC Cafeteria Inspections
WITH source AS (
   SELECT *
   FROM {{ ref('stg_cafeteria_inspections') }}
),

fact_cafeteria_inspection AS (
   SELECT
       {{ dbt_utils.generate_surrogate_key(['record_id']) }} AS inspection_sk,
       s.record_id,

       d1.date_sk AS inspection_date_sk,
       d2.date_sk AS last_inspection_date_sk,

       sch.school_sk,
       v.violation_sk,
       cig.ci_geo_sk,
       cigov.ci_gov_sk,
       sg.geo_sk,

       s.latitude,
       s.longitude,
       CURRENT_TIMESTAMP() AS ci_dw_inserted_at,
       NULL AS ci_dw_updated_at
   FROM source s
   LEFT JOIN {{ ref('dim_shared_date') }} d1 ON d1.full_date = s.inspection_date
   LEFT JOIN {{ ref('dim_shared_date') }} d2 ON d2.full_date = s.last_inspection_date
   LEFT JOIN {{ ref('dim_school') }} sch ON sch.school_name = s.school_name
   LEFT JOIN {{ ref('dim_violation') }} v ON v.level = s.violation_level AND v.code = s.violation_code
   LEFT JOIN {{ ref('dim_ci_geography') }} cig ON cig.number = s.building_number AND cig.street = s.street_name AND cig.ci_city = s.city AND cig.state = s.state AND cig.bin = s.bin AND cig.ci_bbl = s.bbl AND cig.nta = s.nta AND cig.borocode = s.borocode
   LEFT JOIN {{ ref('dim_ci_government') }} cigov ON cigov.community_board = s.community_board AND cigov.census_tract = s.census_tract
   LEFT JOIN {{ ref('dim_shared_geography') }} sg ON sg.borough = s.borough AND sg.zip_code = s.zip_code AND sg.council_district = s.council_district
)

SELECT *
FROM fact_cafeteria_inspection
