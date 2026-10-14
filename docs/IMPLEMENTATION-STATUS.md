# IMPLEMENTATION-STATUS (12 Oct 2026, updated: guest-first)

Rule: "Browse all public content freely; authenticate when taking a protected action."

Stack: Phoenix 1.8 API in `backend/`, React+TS Vite in `web/`, Postgres.
Source docs 01–16 are the authority; conflicts resolved per README
(PRD > categories > brokerage > data model > UI > acceptance).

## Decisions recorded

1. Local Postgres runs as user instance (socket /tmp/opencode:5434) instead
   of system service (no sudo). Config uses `socket_dir`. No doc change needed.
2. Auth tokens: `Phoenix.Token` Bearer (no extra dep) — satisfies 10/12 session
   requirements for pilot.
3. Referral API accepts `consent_ref` (spec name) and `buyer_consent_ref`
   alias; attribution accepts `accept`/`accepted`. Frontend sends spec names.
4. Listing filters: `q`/`area` aliases added alongside `town`/`category_id`/`kind`.

## Requirement status

| ID | Source | Feature | Status | Location | Evidence |
|----|--------|---------|--------|----------|----------|
| F01 | 01,03,04 | Guest discovery + town/category filter | verified | backend/catalog.ex, web Home/Find | curl filter n=5 |
| F02 | 01,10 | Phone OTP (expiry/replay/rate-limit) | verified | backend/accounts.ex | mix test 8 passed |
| F03 | 01,02 | Profiles/skills/areas/availability | implemented | backend accounts, web Me | code only |
| L02 | 01,05,06 | Draft→preview→publish + versions | verified | catalog.ex, PostWizard | E2E publish ok |
| W01 | 01,02 | Apply + immutable versioned offers | verified | work.ex | E2E offer v1 + accept |
| W03 | 01,02 | Quotes/bookings + completion/cancel | implemented | work.ex, web screens | code only |
| M01 | 01,03 | Participant-scoped messaging | implemented | chat_ops.ex | E2E conv create ok |
| B01 | 01,07 | Commission terms + broker approve | verified | brokerage.ex | E2E ok |
| B03 | 07 | Consented referral + attribution | verified | brokerage.ex | E2E + idempotent dup |
| B05 | 01,07 | Claim + reported vs received | verified | brokerage.ex | E2E 20000 UGX earned→reported→received |
| O01 | 01,08 | Reports/disputes/appeals + audit | implemented | chat_ops.ex, web | code only |
| O02 | 01,10 | Notifications dedupe + admin queues | implemented | schemas, web Admin | code only |
| G13 | 09,06 | Category gates server-enforced | verified | catalog gate_check | 422 on gated |
| UX | 04,05 | Mobile UI 320px+, 16px, 44px, states | implemented | web/src | vite build ok |

Blocked/deferred (per roadmap Ph7): live SMS, live payments,
organisations, verification checks, delivery worker, geo-index, PWA cache —
all documented in LOCAL-SETUP.md; nothing falsely marked live. (Public
reviews read + authed create are implemented; deeper eligibility rules pending.)

## Guest-first update (12 Oct 2026, instruction §1–8)

| Item | Status | Location | Evidence |
|------|--------|----------|----------|
| Guest landing SSOT (ivory/clay, Explore primary) | verified | web/src/screens/main.tsx, index.css | vite build ok |
| Shared shell Home/Find/Post/Inbox/Me, no guest catalogue fork | verified | web/src/lib/ui.tsx, App.tsx | build ok |
| Auth at action boundary (bottom sheet, focus restore) | implemented | ui.tsx AuthSheet + requireAuth | code review |
| Intent preservation (allowlisted returnTo, safe draft, no auto-submit) | implemented | rest.tsx Auth, ui.tsx pending | code review |
| Public projections (no phone/owner_id/address leak) | verified | plugs.ex public_listing/owner_public | curl no-leak True |
| Public profiles + reviews endpoints | verified | router, api_controller | 200s; 10 mix tests pass |
| Drafts hidden from guests (404) / visible to owner | verified | listing_show | curl 404/200 |
| Guest 401 on apply/referral/report/messages | verified | RequireUser pipeline | curl 4×401 |
| Invalid UUID → 404 (profiles + listings) | verified | api_controller | curl 404 |
| Manual town persisted through login; geo tap-only | implemented | TownPill | code review |
| Spec updates (01,02,03,04,05,12,14,16) + decision G-20261012 | done | docs | appended |

Remaining gaps: tab-cycle focus trap is first-focus/restore only; closed-after-login
notice surfaces on fetch error without version-diff UI; 320px assured by CSS rules
(min-width:0, ellipsis, fluid SVG) without a device run.

## Backend home page (12 Oct 2026, polished)
`GET /` serves a full responsive landing (PageController + home.html.eex):
sticky nav, two-column desktop hero → stacked mobile (≤860px), live counts,
category cards, live listing grid with per-kind thumbnails, how-it-works,
trust band, footer. Six images.unsplash.com photos verified HTTP 200 with
gradient fallbacks, lazy-loading, and an Unsplash credit line. Verified 200,
12.9KB, all sections present. Interactive flows stay in the React app (:5173).

## Gap-close run (14 Oct 2026)

| Item | Spec | Status | Evidence |
|------|------|--------|----------|
| Invalid UUID / missing record → 404, never 500 (CastError mapped 400→404) | 12-API | verified | curl: /bookings|/referrals|/conversations bad+empty UUIDs and PATCH /listings all 404 |
| Payment-report payer-only (principal), claim earned→reported state | 12-API, Q10 | verified | mix test guards test |
| Acknowledge payee-only (broker), reported→received state | 12-API, Q10 | verified | mix test guards test |
| Outcome participants-only + attribution-accepted-before-claim; deal_event+claim atomic | 07, 11-DATA | verified | mix test; duplicate trigger rolls both back |
| Seller cannot broker-request own listing | 12-API (eligible broker) | verified | mix test |
| GET /applications: worker + employer views with cover-note scope | 03-IA ownership, Q02 | verified | curl 200; projected fields |
| GET /conversations participant-scoped inbox | 03-IA /messages | verified | curl 200 |
| Earnings separated: expected/earned/reported/received buckets | 03-IA, 07 | verified | controller groups by attribution+status |
| Listing create: default open pilot category by kind; pay_minor/area aliases | 06, Q01 | verified | curl draft w/o category 201, pay+location persisted |
| PostWizard: kind deal not goods; category select; pay_amount_minor + coarse_location | 04, 05 | implemented | web build ok |
| Profile save via PUT /me/profile with display_name/skills/service_areas | F03 | implemented | web build ok (was POST /me/profile → 404) |
| Detail actions functional when authed: message → conversation, quote, broker request, referral | 04/05 | implemented | build ok |
| Applications + Messages screens list real scoped records | 03-IA | implemented | build ok |
| AuthSheet full Tab-cycle focus trap (+ Esc, focus restore) | 04-UI | implemented | code review (was first-focus only) |
| Profile public roles render from {worker/prov…: bool} projection | 04/12 | implemented | build ok |
| Review uniqueness (per listing / per profile) + friendly 422 duplicate | 08-TRUST | verified | migration + mix test |
| Error envelope {error:{code,message,fields?}, request_id} | 12-API | verified | Helpers.err used by all paths |

Known remaining limitations (unchanged, deferred per roadmap Ph7): live SMS,
live payments, organisations, verification checks, delivery worker, geo-index,
PWA cache, Expected-Version header, uploads malware scan. mix test: 12 passed.
web: tsc -b && vite build ok.
