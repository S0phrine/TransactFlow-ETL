-- PL: Tabela transakcje_errors przechowuje naruszenia reguł jakości danych.
-- EN: Table transakcje_errors data quality rule violations.
CREATE TABLE transakcje_errors (
    error_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    raw_id BIGINT NOT NULL,
    batch_id INTEGER NOT NULL,
    error_code VARCHAR(50) NOT NULL,
    error_description TEXT,
    detected_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT transakcje_errors_raw_id_fkey
        FOREIGN KEY (raw_id)
        REFERENCES transakcje_raw(raw_id),

    CONSTRAINT transakcje_errors_batch_id_fkey
        FOREIGN KEY (batch_id)
        REFERENCES etl_batches(batch_id),

    CONSTRAINT transakcje_errors_raw_error_unique
        UNIQUE (raw_id, error_code)
);

-- PL: Tabela docelowa zawiera wyłącznie poprawne i przetransformowane transakcje.
-- PL: source_raw_id umożliwia śledzenie pochodzenia danych i blokuje wielokrotne załadowanie tego samego surowego rekordu.
-- EN: Target table contains only valid and transformed transactions.
-- EN: source_raw_id provides data lineage and prevents duplicate loading of the same RAW record.
CREATE TABLE transakcje (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    klient_id INTEGER NOT NULL,
    kwota NUMERIC(15, 2) NOT NULL,
    typ VARCHAR(50) NOT NULL,
    data_transakcji TIMESTAMP NOT NULL,
    source_raw_id BIGINT NOT NULL,

    CONSTRAINT transakcje_klient_id_fkey
        FOREIGN KEY (klient_id)
        REFERENCES klienci(id),

    CONSTRAINT transakcje_source_raw_id_fk
        FOREIGN KEY (source_raw_id)
        REFERENCES transakcje_raw(raw_id),

    CONSTRAINT transakcje_source_raw_id_unique
        UNIQUE (source_raw_id)
);
