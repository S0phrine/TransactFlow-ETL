-- PL: Warstwa surowa przechowująca dane transakcyjne przed walidacją i transformacją.
-- PL: Kolumny źródłowe są typu TEXT, aby błędne dane nie blokowały ingestu.

-- EN: Raw layer storing transaction data before validation and transformation.
-- EN: Source columns use TEXT so invalid values do not block ingestion.

CREATE TABLE transakcje_raw (
    raw_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    external_id TEXT,
    klient_id TEXT,
    kwota TEXT,
    typ TEXT,
    data_transakcji TEXT,
    loaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    batch_id INTEGER NOT NULL,
    CONSTRAINT transakcje_raw_batch_id_fkey
        FOREIGN KEY (batch_id)
        REFERENCES etl_batches(batch_id)
);
