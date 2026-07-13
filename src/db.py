"""Small helper module that wires the raw CSVs into a DuckDB connection.

Keeping this logic in one place means every notebook starts from the exact
same tables/view, instead of copy-pasting the same setup code four times.
"""

from pathlib import Path

import duckdb

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data"
SQL_DIR = PROJECT_ROOT / "sql"


def get_connection() -> duckdb.DuckDBPyConnection:
    """Create an in-memory DuckDB connection with the raw data loaded.

    Loads the two CSV files into "users" and "orders" tables, then creates
    the "base_orders" view defined in sql/01_base_view.sql on top of them.
    """
    con = duckdb.connect(database=":memory:")

    users_csv = (DATA_DIR / "users_jan_feb_2026.csv").as_posix()
    orders_csv = (DATA_DIR / "orders_jan_feb_2026.csv").as_posix()

    con.execute(f"CREATE OR REPLACE TABLE users AS SELECT * FROM read_csv_auto('{users_csv}', header = true)")
    con.execute(f"CREATE OR REPLACE TABLE orders AS SELECT * FROM read_csv_auto('{orders_csv}', header = true)")

    base_view_sql = (SQL_DIR / "01_base_view.sql").read_text(encoding="utf-8")
    con.execute(base_view_sql)

    return con


def load_query(sql_filename: str, query_name: str) -> str:
    """Extract one named query block from a .sql file in the sql/ folder.

    Query blocks are delimited by a header comment in the form
    "-- === query_name ===", so a single .sql file can hold several
    related, individually runnable queries.
    """
    text = (SQL_DIR / sql_filename).read_text(encoding="utf-8")
    marker = f"-- === {query_name} ==="
    if marker not in text:
        raise ValueError(f"Query '{query_name}' not found in {sql_filename}")

    after_marker = text.split(marker, 1)[1]
    next_marker_pos = after_marker.find("-- === ")
    query = after_marker if next_marker_pos == -1 else after_marker[:next_marker_pos]
    return query.strip().rstrip(";").strip()
