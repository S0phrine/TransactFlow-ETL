-- PL: Walidacja surowych danych. Każde naruszenie reguły trafia do tabeli transakcje_errors.
-- PL: UNIQUE(raw_id, error_code) + ON CONFLICT zapewniają idempotentność zapisu błędów.

-- EN: Raw data validation. Each rule violation is written to table transakcje_errors.
-- EN: UNIQUE(raw_id, error_code) + ON CONFLICT make error recording idempotent.

SET DateStyle = 'ISO, DMY';

INSERT INTO transakcje_errors (
    raw_id,
    batch_id,
    error_code,
    error_description
)

SELECT raw_id, batch_id, 'MISSING_AMOUNT', 'Brak wymaganej wartości kwoty'
FROM transakcje_raw
WHERE kwota IS NULL OR TRIM(kwota) = ''

UNION ALL

SELECT raw_id, batch_id, 'MISSING_CUSTOMER_ID', 'Brak identyfikatora klienta'
FROM transakcje_raw
WHERE klient_id IS NULL OR TRIM(klient_id) = ''

UNION ALL

SELECT r.raw_id, r.batch_id, 'INVALID_CUSTOMER_ID', 'Klient o podanym identyfikatorze nie istnieje'
FROM transakcje_raw r
LEFT JOIN klienci k
    ON r.klient_id = CAST(k.id AS TEXT)
WHERE k.id IS NULL
  AND r.klient_id IS NOT NULL
  AND TRIM(r.klient_id) <> ''

UNION ALL

SELECT raw_id, batch_id, 'MISSING_TRANSACTION_TYPE', 'Brak typu transakcji'
FROM transakcje_raw
WHERE typ IS NULL OR TRIM(typ) = ''

UNION ALL

SELECT raw_id, batch_id, 'MISSING_TIMESTAMP', 'Brak daty transakcji'
FROM transakcje_raw
WHERE data_transakcji IS NULL OR TRIM(data_transakcji) = ''

UNION ALL

SELECT raw_id, batch_id, 'INVALID_AMOUNT_FORMAT', 'Niepoprawny format kwoty'
FROM transakcje_raw
WHERE TRIM(kwota) !~ '^[+-]?[0-9]+([.,][0-9]+)?$'
  AND TRIM(kwota) <> ''

UNION ALL

SELECT raw_id, batch_id, 'NON_POSITIVE_AMOUNT', 'Kwota musi być większa od zera'
FROM transakcje_raw
WHERE TRIM(kwota) ~ '^[+-]?[0-9]+([.,][0-9]+)?$'
  AND CAST(REPLACE(TRIM(kwota), ',', '.') AS NUMERIC) <= 0

UNION ALL

SELECT r.raw_id, r.batch_id, 'DUPLICATE_EXTERNAL_ID', 'Zduplikowany identyfikator transakcji'
FROM transakcje_raw r
WHERE (r.batch_id, r.external_id) IN (
    SELECT batch_id, external_id
    FROM transakcje_raw
    GROUP BY batch_id, external_id
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT raw_id, batch_id, 'INVALID_TRANSACTION_TYPE', 'Niedozwolony typ transakcji'
FROM transakcje_raw
WHERE LOWER(TRIM(typ) COLLATE pg_unicode_fast)
      NOT IN ('przelew', 'wpłata', 'wypłata')
  AND TRIM(typ) <> ''

UNION ALL

SELECT raw_id, batch_id, 'INVALID_TIMESTAMP_FORMAT', 'Niepoprawny format daty i czasu'
FROM transakcje_raw
WHERE REGEXP_REPLACE(
          TRIM(data_transakcji),
          '[[:space:]]+',
          ' ',
          'g'
      ) !~ '^[0-9]{2}\.[0-9]{2}\.[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
  AND TRIM(data_transakcji) <> ''

UNION ALL

SELECT raw_id, batch_id, 'INVALID_TIMESTAMP_VALUE', 'Nieprawidłowa wartość daty lub czasu'
FROM transakcje_raw
WHERE REGEXP_REPLACE(
          TRIM(data_transakcji),
          '[[:space:]]+',
          ' ',
          'g'
      ) ~ '^[0-9]{2}\.[0-9]{2}\.[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
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
