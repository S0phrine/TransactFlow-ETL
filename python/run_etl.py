"""PL:
Automatyzacja procesu ETL z pliku CSV do PostgreSQL.

Skrypt odczytuje dane transakcyjne z pliku CSV, rejestruje nową partię
danych, ładuje rekordy do warstwy surowej, uruchamia procedurę przetwarzającą
batch oraz wyświetla podsumowanie procesu.

EN:
Automation of the CSV-to-PostgreSQL ETL pipeline.

The script reads transaction data from a CSV file, registers a new data batch,
loads records into the raw layer, calls the batch-processing procedure,
and displays a process summary.
"""

import argparse
import csv
import os
import sys
from pathlib import Path

import psycopg
from dotenv import load_dotenv


EXPECTED_COLUMNS = [
    "external_id",
    "klient_id",
    "kwota",
    "typ",
    "data_transakcji",
]


def read_csv(csv_path: Path) -> list[dict[str, str]]:
    """PL: Odczytuje plik CSV i sprawdza jego strukturę.

    EN: Reads a CSV file and validates its structure.
    """
    if not csv_path.is_file():
        raise FileNotFoundError(f"Nie znaleziono pliku: {csv_path}")

    with csv_path.open(
        mode="r",
        encoding="utf-8-sig",
        newline="",
    ) as csv_file:
        reader = csv.DictReader(csv_file, delimiter=";")

        if reader.fieldnames != EXPECTED_COLUMNS:
            raise ValueError(
                "Nieprawidłowe kolumny CSV.\n"
                f"Oczekiwano: {EXPECTED_COLUMNS}\n"
                f"Otrzymano: {reader.fieldnames}"
            )

        rows = list(reader)

    if not rows:
        raise ValueError("Plik CSV nie zawiera żadnych rekordów.")

    return rows


def get_connection() -> psycopg.Connection:
    """PL: Tworzy połączenie z PostgreSQL na podstawie pliku .env.

    EN: Creates a PostgreSQL connection using variables loaded from .env.
    """
    project_root = Path(__file__).resolve().parent.parent
    load_dotenv(project_root / ".env")

    required_variables = [
        "DB_HOST",
        "DB_PORT",
        "DB_NAME",
        "DB_USER",
        "DB_PASSWORD",
    ]

    missing_variables = [
        variable
        for variable in required_variables
        if not os.getenv(variable)
    ]

    if missing_variables:
        raise ValueError(
            "Brak wymaganych zmiennych w pliku .env: "
            + ", ".join(missing_variables)
        )

    return psycopg.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
    )


def create_batch_and_load_raw_data(
    connection: psycopg.Connection,
    csv_path: Path,
    rows: list[dict[str, str]],
) -> int:
    """PL: Rejestruje batch i ładuje rekordy do warstwy surowej.

    EN: Registers a batch and loads its records into the raw layer.
    """
    with connection.transaction():
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO etl_batches (source_file)
                VALUES (%s)
                RETURNING batch_id;
                """,
                (csv_path.name,),
            )

            result = cursor.fetchone()

            if result is None:
                raise RuntimeError(
                    "Nie udało się utworzyć partii danych."
                )

            batch_id = result[0]

            cursor.executemany(
                """
                INSERT INTO transakcje_raw (
                    external_id,
                    klient_id,
                    kwota,
                    typ,
                    data_transakcji,
                    batch_id
                )
                VALUES (%s, %s, %s, %s, %s, %s);
                """,
                [
                    (
                        row["external_id"],
                        row["klient_id"],
                        row["kwota"],
                        row["typ"],
                        row["data_transakcji"],
                        batch_id,
                    )
                    for row in rows
                ],
            )

    return batch_id


def process_batch(
    connection: psycopg.Connection,
    batch_id: int,
) -> None:
    """PL: Uruchamia procedurę bazodanową dla wskazanego batcha.

    EN: Runs the database procedure for the selected batch.
    """
    try:
        with connection.transaction():
            with connection.cursor() as cursor:
                cursor.execute(
                    "CALL process_batch(%s);",
                    (batch_id,),
                )

    except Exception:
        with connection.transaction():
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE etl_batches
                    SET
                        status = 'FAILED',
                        finished_at = CURRENT_TIMESTAMP
                    WHERE batch_id = %s
                      AND status = 'STARTED';
                    """,
                    (batch_id,),
                )

        raise


def get_batch_summary(
    connection: psycopg.Connection,
    batch_id: int,
) -> tuple:
    """PL: Pobiera status i statystyki przetworzonego batcha.

    EN: Retrieves the status and processing statistics of a batch.
    """
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                b.batch_id,
                b.status,
                b.source_file,
                b.started_at,
                b.finished_at,
                (
                    SELECT COUNT(*)
                    FROM transakcje_raw r
                    WHERE r.batch_id = b.batch_id
                ) AS total_rows,
                (
                    SELECT COUNT(DISTINCT e.raw_id)
                    FROM transakcje_errors e
                    WHERE e.batch_id = b.batch_id
                ) AS rejected_rows,
                (
                    SELECT COUNT(*)
                    FROM transakcje t
                    JOIN transakcje_raw r
                        ON r.raw_id = t.source_raw_id
                    WHERE r.batch_id = b.batch_id
                ) AS loaded_rows
            FROM etl_batches b
            WHERE b.batch_id = %s;
            """,
            (batch_id,),
        )

        result = cursor.fetchone()

    if result is None:
        raise RuntimeError(
            f"Nie znaleziono podsumowania batcha {batch_id}."
        )

    return result


def print_summary(summary: tuple) -> None:
    """PL: Wyświetla podsumowanie procesu ETL w terminalu.

    EN: Displays the ETL process summary in the terminal.
    """
    (
        batch_id,
        status,
        source_file,
        started_at,
        finished_at,
        total_rows,
        rejected_rows,
        loaded_rows,
    ) = summary

    print("\nPodsumowanie procesu ETL")
    print("------------------------")
    print(f"Batch ID:           {batch_id}")
    print(f"Plik źródłowy:      {source_file}")
    print(f"Status:             {status}")
    print(f"Rozpoczęcie:        {started_at}")
    print(f"Zakończenie:        {finished_at}")
    print(f"Wszystkie rekordy:  {total_rows}")
    print(f"Załadowane:         {loaded_rows}")
    print(f"Odrzucone:          {rejected_rows}")


def main() -> int:
    """PL: Uruchamia kompletny proces ETL i zwraca kod zakończenia.

    EN: Runs the complete ETL workflow and returns its exit code.
    """
    parser = argparse.ArgumentParser(
        description=(
            "Wczytuje plik CSV i uruchamia proces ETL "
            "dla danych transakcyjnych."
        )
    )
    parser.add_argument(
        "csv_path",
        type=Path,
        help="Ścieżka do pliku CSV.",
    )
    arguments = parser.parse_args()

    try:
        csv_path = arguments.csv_path.resolve()
        rows = read_csv(csv_path)

        print(
            f"Odczytano {len(rows)} rekordów "
            f"z pliku '{csv_path.name}'."
        )

        with get_connection() as connection:
            batch_id = create_batch_and_load_raw_data(
                connection,
                csv_path,
                rows,
            )

            print(
                f"Utworzono batch {batch_id} "
                "i załadowano warstwę surową."
            )

            process_batch(connection, batch_id)
            summary = get_batch_summary(connection, batch_id)

        print_summary(summary)

        if summary[1] != "SUCCESS":
            print(
                "\nProces zakończył się statusem innym niż SUCCESS.",
                file=sys.stderr,
            )
            return 1

        return 0

    except (FileNotFoundError, ValueError) as error:
        print(
            f"Błąd danych wejściowych: {error}",
            file=sys.stderr,
        )
        return 1

    except psycopg.Error as error:
        print(
            f"Błąd PostgreSQL: {error}",
            file=sys.stderr,
        )
        return 1

    except Exception as error:
        print(
            f"Nieoczekiwany błąd: {error}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
