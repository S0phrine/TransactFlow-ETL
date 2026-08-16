
-- Kontrole jakości danych
-- Data quality checks



-- 1.
-- Rekordy z brakującymi wymaganymi wartościami
-- Records with missing required values
SELECT raw_id, external_id, klient_id, kwota, typ, data_transakcji
FROM transakcje_raw
WHERE klient_id IS NULL OR TRIM(klient_id) = ''
   OR kwota IS NULL OR TRIM(kwota) = ''
   OR typ IS NULL OR TRIM(typ) = ''
   OR data_transakcji IS NULL OR TRIM(data_transakcji) = '';


-- 2.
-- Odwołania do klientów, którzy nie istnieją w tabeli klienci
-- References to customers that do not exist in the klienci table
SELECT
    r.raw_id,
    r.external_id,
    r.klient_id,
    k.id
FROM transakcje_raw r
LEFT JOIN klienci k
    ON r.klient_id = CAST(k.id AS TEXT)
WHERE k.id IS NULL
  AND r.klient_id IS NOT NULL
  AND TRIM(r.klient_id) <> '';


-- 3.
-- Duplikaty identyfikatora external_id
-- Duplicate external_id values
SELECT external_id, COUNT(*)
FROM transakcje_raw
GROUP BY external_id
HAVING COUNT(*) > 1;


-- 4.
-- Kwoty zapisane w niepoprawnym formacie
-- Amounts stored in an invalid format
SELECT raw_id, external_id, kwota
FROM transakcje_raw
WHERE kwota !~ '^[+-]?[0-9]+([.,][0-9]+)?$'
  AND TRIM(kwota) <> '';


-- 5.
-- Kwoty mniejsze lub równe zero
-- Non-positive amounts
SELECT raw_id, external_id, kwota
FROM transakcje_raw
WHERE kwota ~ '^[+-]?[0-9]+([.,][0-9]+)?$'
  AND CAST(kwota AS NUMERIC) <= 0;


-- 6.
-- Niedozwolone typy transakcji
-- Invalid transaction types
SELECT raw_id, external_id, typ
FROM transakcje_raw
WHERE LOWER(TRIM(typ) COLLATE pg_unicode_fast)
      NOT IN ('przelew', 'wpłata', 'wypłata')
  AND TRIM(typ) <> '';


-- Dane źródłowe zapisują daty w formacie DD.MM.YYYY.
-- Source data uses the DD.MM.YYYY date format.
SET DateStyle = 'ISO, DMY';


-- 7.
-- Daty, które nie mają oczekiwanego formatu DD.MM.YYYY HH:MM:SS
-- Dates that do not match the expected DD.MM.YYYY HH:MM:SS format
SELECT raw_id, external_id, data_transakcji
FROM transakcje_raw
WHERE REGEXP_REPLACE(
          TRIM(data_transakcji),
          '[[:space:]]+',
          ' ',
          'g'
      ) !~ '^[0-9]{2}\.[0-9]{2}\.[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
  AND TRIM(data_transakcji) <> '';


-- 8.
-- Wartości mające poprawny format, ale niebędące prawidłową datą lub godziną
-- Values matching the expected format but containing an invalid date or time
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
