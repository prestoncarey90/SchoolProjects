 -- Quick test to verify source connection works
 SELECT
     unique_key,
     created_date,
     complaint_type,
     borough
 FROM {{ source('raw_db1', 'source_dot_service_requests_history') }}
 LIMIT 10