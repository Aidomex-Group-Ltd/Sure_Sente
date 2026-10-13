# API and integrations

API prefix /api/v1; JSON; UTC storage and locale display. All mutations authenticate except OTP requests. Server validates schemas and permissions independently of UI.

| Method/path | Purpose | Guard |
| --- | --- | --- |
| POST /auth/request-code | Send OTP | Rate limited; generic response |
| POST /auth/verify-code | Establish session | Expiry, attempts, replay protection |
| GET /categories | Enabled taxonomy | Country-specific public projection |
| GET /listings | Paginated discovery | Public published only |
| POST /listings | Draft listing | Owner + enabled category |
| POST /listings/:id/publish | Submit/publish | Validation + moderation gate |
| POST /listings/:id/applications | Apply for work | Open listing, no self-apply |
| POST /applications/:id/offers | Offer scope and pay | Listing owner |
| POST /offers/:id/accept | Accept immutable version | Intended participant + version |
| POST /listings/:id/quotes | Request/propose service | Scoped participants |
| POST /bookings/:id/events | Progress/complete/cancel | Allowed transition + evidence |
| POST /listings/:id/broker-requests | Request authorisation | Eligible broker |
| POST /broker-requests/:id/approve | Authorise | Principal only |
| POST /agreements/:id/accept | Accept terms | Broker + immutable version |
| POST /agreements/:id/referrals | Introduce buyer | Consent + authorised agreement |
| POST /referrals/:id/attribution | Accept/contest | Principal + evidence |
| POST /referrals/:id/outcome | Record qualifying outcome | Participants + validation |
| POST /claims/:id/payment-report | Report direct payment | Payer only |
| POST /claims/:id/acknowledge | Acknowledge receipt | Payee only |
| POST /disputes | Open case | Authorised participant/reporter |
| GET /me/earnings | Separated commission totals | Owner only |
| POST /conversations/:id/messages | Send text/attachment refs | Participant only |
| POST /admin/cases/:id/decisions | Record decision | Scoped moderator |

## Contract
Cursor pagination; explicit error code, human-readable message, field errors, request ID. Idempotency-Key for agreement acceptance, referral submission and payment actions. Expected version for critical edits; conflict returns current version without overwriting. Return minimum necessary personal data.

## Providers
SMS OTP/notifications: configurable provider; delivery reports, opt-out rules and cost tracking. WhatsApp link sharing can be manual first; automated WhatsApp requires proper account/API setup and recipient permission. Payments disabled until provider selected. Webhooks signed, replay checked, idempotent, reconciled; browser redirect alone never proves payment.

## Media
Allowlisted types and size limits; malware scan; private direct uploads with short-lived signed URLs; strip image location metadata; public resized images only after approval. No unauthenticated access to evidence.

## Public vs private API (12 Oct 2026)
Public (no token): GET /categories, /listings, /listings/:id (published only; drafts 404 for non-owners), /listings/:id/reviews, /profiles/:id, /profiles/:id/reviews. Public listing/projection excludes phone/email, owner_id, contact keys, consent refs, identity docs, precise addresses. Private mutations (applications, offers, quotes, bookings, broker requests/agreements, referrals, messages, reports, reviews POST, earnings, admin) require Bearer auth + object-level checks. Invalid UUIDs return 404, never 500.
