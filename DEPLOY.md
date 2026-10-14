# Sure Sente — Production release & deployment

## Architecture (detected)
- `web/`: Vite 8 + React 19 + TypeScript SPA (`BrowserRouter`), build `tsc -b && vite build`, output `web/dist`. Deployed to Vercel via **native Vite preset** (see root `vercel.json`); `web/Dockerfile` (nginx) is for local reproducibility only.
- `backend/`: Phoenix 1.8 / Elixir ~> 1.17 API on port 4000 (`/api/v1`, Bandit), Postgres via `DATABASE_URL`. Deployed as a container (`backend/Dockerfile`, Mix release) on a container host — **not** on Vercel (Vercel hosts the frontend only).
- Homepage enhancement (dynamic hero carousel, featured deals/gigs) already implemented (commit `cceb624`).

## Local release
```bash
cp .env.example backend/.env   # fill secrets: openssl rand -base64 64
# frontend only:
cd web && npm ci && npm run build && npm run preview
# full stack:
docker compose -f compose.yaml up --build
# web http://localhost:8080, api http://localhost:4000/health
```

## Backend production config (Aiven Postgres + suresente.space)
- `DATABASE_URL`: `ecto://avnadmin:<PASSWORD>@sure-sente-sure-sente.e.aivencloud.com:20580/defaultdb` (password from Aiven console; never commit it). SSL is forced on in `config/runtime.exs`.
- `SECRET_KEY_BASE`: generate via `mix phx.gen.secret` (64+ bytes).
- `PHX_SERVER=true`, `PORT=4000` (or platform `PORT`), `PHX_HOST=<backend public host>`.
- `CORS_ORIGIN=https://suresente.space` (comma-separated list allowed; also add preview URLs as needed).
- Run migrations once connectivity is available:
  `MIX_ENV=prod DATABASE_URL='...' SECRET_KEY_BASE='...' mix ecto.migrate`
  (host verified reachable on port 20580; migration still pending — needs the real DB password).

## Domain: suresente.space
1. Frontend (Vercel): project Settings → Domains → add `suresente.space` (and `www.suresente.space` → redirect). At the registrar, point the apex A record to `76.76.21.21` (Vercel) or use ALIAS/CNAME per Vercel's instructions; add the `www` CNAME to `cname.vercel-dns.com`.
2. Backend API: expose the container host (Fly/Render/etc.) and either use `api.suresente.space` (CNAME to the host) with `PHX_HOST=api.suresente.space`, updating `VITE_API_URL=https://api.suresente.space/api/v1` and redeploying the frontend — or keep the platform-provided backend URL.
3. Ensure `CORS_ORIGIN` includes exactly the frontend origin (`https://suresente.space`).

## Vercel deploy (team `aidomex1`)
1. Open https://vercel.com/new?teamSlug=aidomex1, select team **aidomex1**.
2. Import the SureSente Git repo. Root directory: repository root (uses root `vercel.json`).
3. Framework preset: **Vite**. Build: `cd web && npm ci && npm run build`. Output: `web/dist`.
4. Env vars (Production + Preview): `VITE_API_URL=https://<backend-host>/api/v1`.
5. Deploy Preview first, test routes `/`, `/find`, `/deals`, `/auth`, and API connectivity. Promote to Production after green.
6. Backend: deploy `backend/` container separately (Fly/Render/etc.) with `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_SERVER=true`, `PHX_HOST=<backend-host>`, then point `VITE_API_URL` at it and redeploy frontend.

## Env reference
See `.env.example` (backend/server) and `web/.env.example` (frontend). Never commit real secrets.
