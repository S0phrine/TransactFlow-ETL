-- Warstwa surowa przechowująca dane transakcyjne w niezmienionej postaci.
-- Kolumny źródłowe są typu TEXT, aby błędne dane nie blokowały importu.

-- Raw layer storing transaction data in its original form.
-- Source columns use the TEXT type so invalid values do not block ingestion.

CREATE TABLE transakcje_raw (
    raw_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    external_id TEXT,
    klient_id TEXT,
    kwota TEXT,
    typ TEXT,
    data_transakcji TEXT,
    loaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
