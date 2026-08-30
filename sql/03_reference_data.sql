-- PL: Przykładowe dane referencyjne klientów używane przez demonstracyjny potok przetwarzania danych.
-- EN: Sample customer reference data used by the demonstration pipeline.

INSERT INTO klienci (imie, nazwisko, email, data_rejestracji)
VALUES
    ('Anna', 'Nowak', 'aniafrania@gmail.com', '2026-07-26'),
    ('Michał', 'Anioł', 'michalaniol@gmail.com', '2026-07-26'),
    ('Karolina', 'Szatan', 'karoszatan@onet.pl', '2026-07-26');
