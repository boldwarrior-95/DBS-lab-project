#!/bin/bash
# Runs once on first DB startup. The gvenzl image executes everything in
# /container-entrypoint-initdb.d/ as SYS in the CDB; we connect as APP_USER
# in the PDB so the schema/PLSQL/seed are owned by the application user.
#
# The real SQL files are mounted at /opt/sql/ (NOT inside initdb.d) so the
# entrypoint doesn't run them a second time as SYS in the CDB.
set -euo pipefail

: "${APP_USER:?must be set by docker-compose}"
: "${APP_USER_PASSWORD:?must be set by docker-compose}"

DB_SERVICE="${DB_SERVICE:-FREEPDB1}"
DB_PORT="${DB_PORT:-1521}"
SQL_DIR="${SQL_DIR:-/opt/sql}"

echo "[init.sh] Loading D-SCAE schema as ${APP_USER}@${DB_SERVICE}..."

sqlplus -L -S "${APP_USER}/${APP_USER_PASSWORD}@//localhost:${DB_PORT}/${DB_SERVICE}" <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET ECHO ON
SET FEEDBACK ON
@${SQL_DIR}/01_schema.sql
@${SQL_DIR}/02_plsql.sql
@${SQL_DIR}/03_seed.sql
EXIT
SQL

echo "[init.sh] D-SCAE schema loaded successfully."
