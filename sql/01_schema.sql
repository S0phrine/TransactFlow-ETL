-- PL: 
-- Bazowe tabele projektu TransactFlow ETL.
-- Są tworzone jako pierwsze, ponieważ kolejne elementy potoku przetwarzania danych odwołują się do nich przez klucze obce:
-- - klienci przechowuje dane referencyjne klientów,
-- - etl_batches przechowuje informacje o poszczególnych uruchomieniach ETL.
-- transakcje_raw, transakcje_errors oraz transakcje są tworzone później, ponieważ zależą od tych tabel lub od siebie nawzajem.

-- EN: 
-- Core tables of the TransactFlow ETL project.
-- They are created first because later pipeline components reference them through foreign keys:
-- - klienci stores customer reference data,
-- - etl_batches stores metadata about individual ETL runs.
-- transakcje_raw, transakcje_errors and transakcje are created later because they depend on these tables or on each other.

CREATE TABLE klienci (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    imie VARCHAR(20) NOT NULL,
    nazwisko VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    data_rejestracji DATE NOT NULL
);

-- PL: Rejestr uruchomień procesu ETL. Każdy batch reprezentuje jedną partię danych przetwarzaną przez pipeline.
-- EN: Registry of ETL process runs. Each batch represents one set of data processed by the pipeline.

CREATE TABLE etl_batches (
    batch_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_file TEXT NOT NULL,
    started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'STARTED'
);
