# Sure Sente — local setup

Stack: Elixir/Phoenix API (`backend/`, Postgres) + React+TS Vite app (`web/`).
Spec docs in this directory remain the source of truth (see README.md).

## 1. Database (local, no sudo needed)

```bash
export PATH=/usr/lib/postgresql/14/bin:$PATH
initdb -D /tmp/opencode/pgdata -E UTF8   # first time only
pg_ctl -D /tmp/opencode/pgdata -o "-p 5434 -k /tmp/opencode" -l /tmp/opencode/pg.log start
psql -h /tmp/opencode -p 5434 -U aidomex -d postgres \
  -c "CREATE ROLE sure_sente LOGIN PASSWORD 'sure_sente' SUPERUSER CREATEDB;" \
  -c "CREATE DATABASE sure_sente_dev OWNER sure_sente;"
```

## 2. Backend

```bash
mix deps.get
mix ecto.create && mix ecto.migrate
SEED_DEMO=true mix run priv/repo/seeds.exs   # pilot categories + labelled [DEMO] listing
mix phx.server                                # http://localhost:4000
mix test                                      # 12 passed
```

## 3. Frontend

```bash
npm install
npm run dev    # http://localhost:5173 (VITE_API_URL defaults to localhost:4000/api/v1)
npm run build
```

## 4. E2E smoke (verified 12 Oct 2026)

Phone OTP -> verify -> post listing -> publish -> apply -> versioned offer ->
accept/booking -> broker request -> approve -> accept agreement -> consented
referral -> attribution accepted -> outcome claim (10% of 200000 = 20000 UGX)
-> payment reported -> acknowledged. Idempotent referral retry returns the
same record; gated categories (vehicles/property/land/finance/health/
overseas-recruitment) rejected server-side with 422.

## Known limitations / launch dependencies

- Mock SMS adapter only (dev returns code in API response); no live provider.
- No live payments: direct-payment records only; reported vs received tracked
  separately, no wallet/escrow (per spec).
- Uploads: metadata + allowlist validation only; no virus scan/EXIF strip/
  signed download URLs yet.
- Missing (gated/future per roadmap): reviews, organisations, verification
  checks, notification delivery worker, geospatial index, PWA offline cache,
  `Expected-Version` concurrency header.
- Seed demo data excluded from production (requires SEED_DEMO=true).

## Backup / restore

```bash
pg_dump -h /tmp/opencode -p 5434 -U sure_sente sure_sente_dev > backup.sql
psql -h /tmp/opencode -p 5434 -U sure_sente sure_sente_dev < backup.sql
```
