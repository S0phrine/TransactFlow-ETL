-- PL: Zapytania profilujące, które służą do ręcznej kontroli jakości danych w warstwie surowej.
-- EN: Profiling queries for manual data quality inspection in the raw layer.

-- 1. Brakujące wymagane wartości / Missing required values
SELECT raw_id, external_id, klient_id, kwota, typ, data_transakcji
FROM transakcje_raw
WHERE klient_id IS NULL OR TRIM(klient_id) = ''
   OR kwota IS NULL OR TRIM(kwota) = ''
   OR typ IS NULL OR TRIM(typ) = ''
   OR data_transakcji IS NULL OR TRIM(data_transakcji) = '';

-- 2. Nieistniejący klient / Non-existing customer
SELECT
    r.raw_id,
    r.external_id,
    r.klient_id,
    k.id AS matched_customer_id
FROM transakcje_raw r
LEFT JOIN klienci k
    ON r.klient_id = CAST(k.id AS TEXT)
WHERE k.id IS NULL
  AND r.klient_id IS NOT NULL
  AND TRIM(r.klient_id) <> '';

-- 3. Duplikaty external_id w obrębie batcha / Duplicate external_id within a batch
SELECT batch_id, external_id, COUNT(*) AS duplicate_count
FROM transakcje_raw
GROUP BY batch_id, external_id
HAVING COUNT(*) > 1;

-- 4. Niepoprawny format kwoty / Invalid amount format
SELECT raw_id, external_id, kwota
FROM transakcje_raw
WHERE TRIM(kwota) !~ '^[+-]?[0-9]+([.,][0-9]+)?$'
  AND TRIM(kwota) <> '';

-- 5. Kwota mniejsza lub równa zero / Non-positive amount
SELECT raw_id, external_id, kwota
FROM transakcje_raw
WHERE TRIM(kwota) ~ '^[+-]?[0-9]+([.,][0-9]+)?$'
  AND CAST(REPLACE(TRIM(kwota), ',', '.') AS NUMERIC) <= 0;

-- 6. Niedozwolony typ transakcji / Invalid transaction type
SELECT raw_id, external_id, typ
FROM transakcje_raw
WHERE LOWER(TRIM(typ) COLLATE pg_unicode_fast)
      NOT IN ('przelew', 'wpłata', 'wypłata')
  AND TRIM(typ) <> '';

-- 7. Niepoprawny format daty i czasu / Invalid timestamp format
SELECT raw_id, external_id, data_transakcji
FROM transakcje_raw
WHERE REGEXP_REPLACE(
          TRIM(data_transakcji),
          '[[:space:]]+',
          ' ',
          'g'
      ) !~ '^[0-9]{2}\.[0-9]{2}\.[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
  AND TRIM(data_transakcji) <> '';

-- 8. Format jest poprawny, ale wartość daty/czasu jest niemożliwa.
--    Format is valid, but the timestamp value itself is impossible.
SET DateStyle = 'ISO, DMY';

SELECT raw_id, external_id, data_transakcji
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
  );
