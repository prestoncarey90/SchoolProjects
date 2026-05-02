-- School dimension for NYC Cafeteria Inspections
WITH source AS (
   SELECT DISTINCT
       school_name,
       permittee,
       ptet,
       site_type
   FROM {{ ref('stg_cafeteria_inspections') }}
)

SELECT
   {{ dbt_utils.generate_surrogate_key(['school_name']) }} AS school_sk,
   /* Build school dimension using mapping (school name → DBN),
   used for scalability if we need to join with other tables */
   school_name AS dbn,
   school_name,
   permittee,
   ptet,
   site_type,
   CASE
      WHEN UPPER(school_name) LIKE '%ELEMENTARY%' THEN 'ELEMENTARY'
      WHEN UPPER(school_name) LIKE '%MIDDLE%' THEN 'MIDDLE'
      WHEN UPPER(school_name) LIKE '%HIGH%' THEN 'HIGH'
      WHEN UPPER(school_name) LIKE '%PREP%' THEN 'PREP'
      WHEN UPPER(school_name) LIKE '%ACADEMY%' THEN 'ACADEMY'
      ELSE NULL
   END AS school_level,

   /* COMMENTING OUT FOR NOW (per discussion with team) - mapping from
   facility_type to economic_need_index is not available in source,
   present for potential scalability with potential third dataset,
   set to NULL for now, except school_level with temporary workaround.
   NULL AS facility_type,
   NULL AS total_enrollment,
   NULL AS economic_need_index,
   NULL AS academic_year, 
   NULL AS is_current_school_year, */
   CURRENT_TIMESTAMP() AS dw_inserted_at
FROM source