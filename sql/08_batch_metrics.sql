-- PL: Zbiorcze statystyki jakości danych dla pierwszego wsadu.
-- EN: Combined data quality metrics for demonstration batch 1.

WITH total AS (
    SELECT COUNT(*) AS total_rows
    FROM transakcje_raw
    WHERE batch_id = 1
),
rejected AS (
    SELECT COUNT(DISTINCT raw_id) AS rejected_rows
    FROM transakcje_errors
    WHERE batch_id = 1
),
valid AS (
    SELECT COUNT(*) AS valid_rows
    FROM transakcje t
    JOIN transakcje_raw r
        ON t.source_raw_id = r.raw_id
    WHERE r.batch_id = 1
)
SELECT
    total_rows,
    rejected_rows,
    valid_rows
FROM total
CROSS JOIN rejected
CROSS JOIN valid;
