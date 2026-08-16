CREATE TABLE klienci (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    imie VARCHAR(20) NOT NULL,
    nazwisko VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    data_rejestracji DATE NOT NULL
);

CREATE TABLE transakcje (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    klient_id INTEGER NOT NULL,
    kwota NUMERIC(15, 2) NOT NULL,
    typ VARCHAR(50) NOT NULL,
    data_transakcji TIMESTAMP NOT NULL,

    CONSTRAINT fk_transakcje_klienci
        FOREIGN KEY (klient_id)
        REFERENCES klienci(id)
);
