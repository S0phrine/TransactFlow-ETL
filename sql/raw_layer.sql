CREATE TABLE transakcje_raw (
    raw_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    external_id TEXT,
    klient_id TEXT,
    kwota TEXT,
    typ TEXT,
    data_transakcji TEXT,
    loaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
