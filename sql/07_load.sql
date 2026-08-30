-- PL: Załadowanie poprawnych i przetransformowanych rekordów do tabeli docelowej.
-- PL: source_raw_id pozwala śledzić pochodzenie danych, a instrukcja ON CONFLICT zapobiega ponownemu załadowaniu tego samego rekordu.

-- EN: Load valid and transformed records into the target table.
-- EN: source_raw_id provides data lineage, while the ON CONFLICT clause prevents duplicate loading of the same record.

INSERT INTO transakcje (
    klient_id,
    kwota,
    typ,
    data_transakcji,
    source_raw_id
)
SELECT
    CAST(TRIM(r.klient_id) AS INTEGER) AS klient_id,
    CAST(REPLACE(TRIM(r.kwota), ',', '.') AS NUMERIC(15, 2)) AS kwota,
    LOWER(TRIM(r.typ) COLLATE pg_unicode_fast) AS typ,
    TO_TIMESTAMP(
        REGEXP_REPLACE(
            TRIM(r.data_transakcji),
            '[[:space:]]+',
            ' ',
            'g'
        ),
        'DD.MM.YYYY HH24:MI:SS'
    )::TIMESTAMP AS data_transakcji,
    r.raw_id AS source_raw_id
FROM transakcje_raw r
WHERE NOT EXISTS (
    SELECT 1
    FROM transakcje_errors e
    WHERE e.raw_id = r.raw_id
)
ON CONFLICT (source_raw_id) DO NOTHING;

-- PL: Ręczne domknięcie demonstracyjnego batcha 1.
-- PL: W etapie Python batch_id będzie przekazywany dynamicznie.
-- EN: Manual finalization of demonstration batch 1.
-- EN: In the Python stage, batch_id will be supplied dynamically.
UPDATE etl_batches
SET
    status = 'SUCCESS',
    finished_at = CURRENT_TIMESTAMP
WHERE batch_id = 1;
