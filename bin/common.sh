#!/usr/bin/env bash
# Shared paths for Sure Sente local services. Source-only.
export SURE_SENTE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PGDATA_DIR="$HOME/.local/share/sure-sente/pgdata"
export PG_SOCKET_DIR="/tmp/opencode"
export PG_PORT="5434"
export PG_LOG="$PG_SOCKET_DIR/pg.log"
export BACKEND_DIR="$SURE_SENTE_ROOT/backend"
export PATH="/usr/lib/postgresql/14/bin:$PATH"
