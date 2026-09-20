-- PL:
-- Procedura przetwarza pojedynczą partię danych wskazaną przez p_batch_id.
-- Waliduje rekordy warstwy surowej, zapisuje wykryte błędy,
-- ładuje poprawne rekordy i aktualizuje status partii.
--
-- EN:
-- The procedure processes one data batch identified by p_batch_id.
-- It validates raw records, records detected errors,
-- loads valid rows and updates the batch status.

CREATE OR REPLACE PROCEDURE process_batch(IN p_batch_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
BEGIN
    SELECT status
    INTO v_status
    FROM etl_batches
    WHERE batch_id = p_batch_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Batch with id % does not exist.',
            p_batch_id;
    END IF;

    IF v_status <> 'STARTED' THEN
        RAISE EXCEPTION
            'Batch % has status %, expected STARTED.',
            p_batch_id,
            v_status;
    END IF;

    BEGIN
        -- Obecna walidacja dat wykorzystuje pg_input_is_valid().
        -- Jawne ustawienie zapewnia obsługę formatu DD.MM.YYYY.
        PERFORM set_config('DateStyle', 'ISO, DMY', true);

        INSERT INTO transakcje_errors (
            raw_id,
            batch_id,
            error_code,
            error_description
        )

        SELECT
            raw_id,
            batch_id,
            'MISSING_AMOUNT',
            'Brak wymaganej wartości kwoty'
        FROM transakcje_raw
        WHERE batch_id = p_batch_id
          AND (kwota IS NULL OR TRIM(kwota) = '')

        UNION ALL

        SELECT
            raw_id,
            batch_id,
            'MISSING_CUSTOMER_ID',
            'Brak identyfikatora klienta'
        FROM transakcje_raw
        WHERE batch_id = p_batch_id
          AND (klient_id IS NULL OR TRIM(klient_id) = '')

        UNION ALL

        SELECT
            r.raw_id,
            r.batch_id,
            'INVALID_CUSTOMER_ID',
            'Klient o podanym identyfikatorze nie istnieje'
        FROM transakcje_raw r
        LEFT JOIN klienci k
            ON r.klient_id = CAST(k.id AS TEXT)
        WHERE r.batch_id = p_batch_id
          AND k.id IS NULL
          AND r.klient_id IS NOT NULL
          AND TRIM(r.klient_id) <> ''

        UNION ALL

        SELECT
            raw_id,
            batch_id,
            'MISSING_TRANSACTION_TYPE',
            'Brak typu transakcji'
        FROM transakcje_raw
        WHERE batch_id = p_batch_id
          AND (typ IS NULL OR TRIM(typ) = '')

        UNION ALL

        SELECT
            raw_id,
            batch_id,
            'MISSING_TIMESTAMP',
            'Brak daty transakcji'
        FROM transakcje_raw
        WHERE batch_id = p_batch_id
          AND (
              data_transakcji IS NULL
              OR TRIM(data_transakcji) = ''
          )

        UNION ALL

        SELECT
            raw_id,
            batch_id,
            'INVALID_AMOUNT_FORMAT',
            'Niepoprawny format kwoty'
        FROM transakcje_raw
        WHERE batch_id = p_batch_id
          AND TRIM(kwota) !~ '^[+-]?[0-9]+([.,][0-9]+)?$'
          AND TRIM(kwota) <> ''

        UNION ALL

        SELECT
            raw_id,
            batch_id,
            'NON_POSITIVE_AMOUNT',
            'Kwota musi być większa od zera'
        FROM transakcje_raw
        WHERE batch_id = p_batch_id
          AND TRIM(kwota) ~ '^[+-]?[0-9]+([.,][0-9]+)?$'
          AND CAST(
              REPLACE(TRIM(kwota), ',', '.')
              AS NUMERIC
          ) <= 0

        UNION ALL

        SELECT
            r.raw_id,
            r.batch_id,
            'DUPLICATE_EXTERNAL_ID',
            'Zduplikowany identyfikator transakcji'
        FROM transakcje_raw r
        WHERE r.batch_id = p_batch_id
          AND r.external_id IN (
              SELECT external_id
              FROM transakcje_raw
              WHERE batch_id = p_batch_id
              GROUP BY external_id
              HAVING COUNT(*) > 1
          )

        UNION ALL

        SELECT
            raw_id,
            batch_id,
            'INVALID_TRANSACTION_TYPE',
            'Niedozwolony typ transakcji'
        FROM transakcje_raw
        WHERE batch_id = p_batch_id
          AND LOWER(TRIM(typ) COLLATE pg_unicode_fast)
              NOT IN ('przelew', 'wpłata', 'wypłata')
          AND TRIM(typ) <> ''

        UNION ALL

        SELECT
            raw_id,
            batch_id,
            'INVALID_TIMESTAMP_FORMAT',
            'Niepoprawny format daty i czasu'
        FROM transakcje_raw
        WHERE batch_id = p_batch_id
          AND REGEXP_REPLACE(
                  TRIM(data_transakcji),
                  '[[:space:]]+',
                  ' ',
                  'g'
              ) !~
              '^[0-9]{2}\.[0-9]{2}\.[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
          AND TRIM(data_transakcji) <> ''

        UNION ALL

        SELECT
            raw_id,
            batch_id,
            'INVALID_TIMESTAMP_VALUE',
            'Nieprawidłowa wartość daty lub czasu'
        FROM transakcje_raw
        WHERE batch_id = p_batch_id
          AND REGEXP_REPLACE(
                  TRIM(data_transakcji),
                  '[[:space:]]+',
                  ' ',
                  'g'
              ) ~
              '^[0-9]{2}\.[0-9]{2}\.[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
          AND NOT pg_input_is_valid(
              REGEXP_REPLACE(
                  TRIM(data_transakcji),
                  '[[:space:]]+',
                  ' ',
                  'g'
              ),
              'timestamp'
          )

        ON CONFLICT (raw_id, error_code) DO NOTHING;

        INSERT INTO transakcje (
            klient_id,
            kwota,
            typ,
            data_transakcji,
            source_raw_id
        )
        SELECT
            CAST(TRIM(r.klient_id) AS INTEGER),
            CAST(
                REPLACE(TRIM(r.kwota), ',', '.')
                AS NUMERIC(15, 2)
            ),
            LOWER(TRIM(r.typ) COLLATE pg_unicode_fast),
            TO_TIMESTAMP(
                REGEXP_REPLACE(
                    TRIM(r.data_transakcji),
                    '[[:space:]]+',
                    ' ',
                    'g'
                ),
                'DD.MM.YYYY HH24:MI:SS'
            )::TIMESTAMP,
            r.raw_id
        FROM transakcje_raw r
        WHERE r.batch_id = p_batch_id
          AND NOT EXISTS (
              SELECT 1
              FROM transakcje_errors e
              WHERE e.raw_id = r.raw_id
          )
        ON CONFLICT (source_raw_id) DO NOTHING;

        UPDATE etl_batches
        SET
            status = 'SUCCESS',
            finished_at = CURRENT_TIMESTAMP
        WHERE batch_id = p_batch_id;

        RAISE NOTICE
            'Batch % processed successfully.',
            p_batch_id;

    EXCEPTION
        WHEN OTHERS THEN
            UPDATE etl_batches
            SET
                status = 'FAILED',
                finished_at = CURRENT_TIMESTAMP
            WHERE batch_id = p_batch_id;

            RAISE WARNING
                'Batch % processing failed: %',
                p_batch_id,
                SQLERRM;
    END;
END;
$$;
