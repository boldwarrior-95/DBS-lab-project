"""
Oracle connection pool + thin query helpers for D-SCAE.

Uses python-oracledb in Thin mode (no Instant Client required).
"""

import os
import oracledb

DB_USER     = os.environ["DB_USER"]
DB_PASSWORD = os.environ["DB_PASSWORD"]
DB_HOST     = os.environ.get("DB_HOST", "db")
DB_PORT     = int(os.environ.get("DB_PORT", "1521"))
DB_SERVICE  = os.environ.get("DB_SERVICE", "FREEPDB1")

POOL_MIN    = int(os.environ.get("DB_POOL_MIN", "1"))
POOL_MAX    = int(os.environ.get("DB_POOL_MAX", "8"))

_pool: oracledb.ConnectionPool | None = None


def init_pool() -> oracledb.ConnectionPool:
    global _pool
    if _pool is None:
        _pool = oracledb.create_pool(
            user=DB_USER,
            password=DB_PASSWORD,
            dsn=f"{DB_HOST}:{DB_PORT}/{DB_SERVICE}",
            min=POOL_MIN,
            max=POOL_MAX,
            increment=1,
        )
    return _pool


def get_conn():
    return init_pool().acquire()


def _force_clob_to_str(cursor, metadata):
    if metadata.type_code is oracledb.DB_TYPE_CLOB:
        return cursor.var(oracledb.DB_TYPE_LONG, arraysize=cursor.arraysize)
    if metadata.type_code is oracledb.DB_TYPE_BLOB:
        return cursor.var(oracledb.DB_TYPE_LONG_RAW, arraysize=cursor.arraysize)


def query(sql: str, params: dict | None = None, one: bool = False):
    """Run a SELECT and return list[dict] (or single dict / None when one=True)."""
    with get_conn() as conn:
        conn.outputtypehandler = _force_clob_to_str
        cur = conn.cursor()
        cur.execute(sql, params or {})
        cols = [d[0].lower() for d in cur.description]
        if one:
            row = cur.fetchone()
            return dict(zip(cols, row)) if row else None
        return [dict(zip(cols, r)) for r in cur.fetchall()]


def execute(sql: str, params: dict | None = None) -> None:
    """Run a DML statement and commit."""
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(sql, params or {})
        conn.commit()


def insert_returning(sql: str, params: dict) -> int:
    """
    Run an INSERT that ends with `RETURNING <id_col> INTO :new_id`
    and return the generated ID.
    """
    with get_conn() as conn:
        cur = conn.cursor()
        new_id_var = cur.var(oracledb.NUMBER)
        cur.execute(sql, {**params, "new_id": new_id_var})
        conn.commit()
        # python-oracledb wraps RETURNING values in a list (one per row affected).
        result = new_id_var.getvalue()
        return int(result[0] if isinstance(result, list) else result)
