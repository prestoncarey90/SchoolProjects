 -- Quick test to verify source connection works
 SELECT
     bbl,
     bin
 FROM {{ source('raw_inspections', 'source_cafeteria_inspections') }}
 LIMIT 10