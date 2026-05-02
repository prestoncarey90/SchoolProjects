-- Date dimension for NYC 311 Service Requests & Cafeteria Inspections
WITH all_dates AS (
   -- Collect all distinct dates used across the mart sources
   SELECT DISTINCT CAST(created_date AS DATE) AS full_date
   FROM {{ ref('stg_nyc_311_doedohmh') }}
   WHERE created_date IS NOT NULL

   UNION DISTINCT

   SELECT DISTINCT CAST(resolution_action_updated_date AS DATE) AS full_date
   FROM {{ ref('stg_nyc_311_doedohmh') }}
   WHERE resolution_action_updated_date IS NOT NULL

   UNION DISTINCT

   SELECT DISTINCT CAST(closed_date AS DATE) AS full_date
   FROM {{ ref('stg_nyc_311_doedohmh') }}
   WHERE closed_date IS NOT NULL

   UNION DISTINCT

   SELECT DISTINCT CAST(inspection_date AS DATE) AS full_date
   FROM {{ ref('stg_cafeteria_inspections') }}
   WHERE inspection_date IS NOT NULL

   UNION DISTINCT

   SELECT DISTINCT CAST(last_inspection_date AS DATE) AS full_date
   FROM {{ ref('stg_cafeteria_inspections') }}
   WHERE last_inspection_date IS NOT NULL
),

date_dimension AS (
   SELECT
       {{ dbt_utils.generate_surrogate_key(['full_date']) }} AS date_sk,
       full_date,
       EXTRACT(YEAR FROM full_date) AS year,
       EXTRACT(QUARTER FROM full_date) AS quarter,
       EXTRACT(MONTH FROM full_date) AS month_num,
       FORMAT_DATE('%B', full_date) AS month_name,
       EXTRACT(DAY FROM full_date) AS day_num,
       FORMAT_DATE('%A', full_date) AS day_name,
       EXTRACT(DAYOFWEEK FROM full_date) NOT IN (1, 7) AS is_school_day
   FROM all_dates
)

SELECT *
FROM date_dimension