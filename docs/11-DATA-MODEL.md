# Data model

## Core entities
| Entity | Essential fields / relations |
| --- | --- |
| users | UUID, phone/email, locale, status, eligibility declaration |
| profiles | user, display name, skills, service area, availability |
| organisations | name, owner, staff memberships and permissions |
| verification_checks | subject, type, scope, evidence ref, status, reviewer, expires_at |
| categories | parent, schema_version, modes, country, gate status |
| listings | owner, organisation optional, type, category, public fields, private location, status, version |
| listing_versions | immutable terms snapshot, author and timestamp |
| applications | listing, worker, message, availability, status |
| offers | application/booking, immutable scope/pay snapshot, version, accepted_at |
| bookings | participants, offer, schedule, completion and cancellation states |
| conversations/messages | authorised participants, booking/listing/referral link, attachment refs |
| brokerage_agreements | principal, broker, listing_version, terms snapshot, authorisation/acceptance states |
| referrals | agreement, buyer consent ref, protected contact key, attribution state, timestamps |
| deal_events | referral, actor, milestone, evidence refs, timestamp |
| commission_claims | referral, amount_minor, currency, calculation snapshot, state |
| payment_records | claim/booking, amount, payer, payee, provider ref optional, reported/confirmed status |
| disputes | subject, participants, reason, evidence, decision, appeal |
| reviews | confirmed transaction, author, recipient, moderation state |
| notifications | event, recipient, channel, delivery state, dedupe key |
| audit_events | actor, subject, action, redacted change, timestamp, request ID |

## State invariants
Booking: requested → quoted → accepted → in_progress → completion_requested → completed; cancelled/disputed are explicit branches. Payment state is separate from booking completion.
Application: submitted → shortlisted → offered → accepted/rejected/withdrawn/expired. Offer acceptance creates or links a booking atomically.
Listings and referrals follow categories and brokerage specifications. Disputed states retain prior state for audited resolution.

## Constraints
Money integer minor units + ISO currency; no currency arithmetic across currencies. Quantity/percentage ranges validated. One accepted offer per application/version. Commission claim unique by referral and qualifying trigger. Duplicate provider reference forbidden. Foreign keys on participant relations. Unique dedupe keys for event-driven actions.

## Privacy
Identity evidence and precise locations stored separately from public projections. HMAC-normalised phone keys may assist duplicate referral detection, but they are still protected personal data and shared-phone matches need human review. Avoid plain hashes vulnerable to enumeration. Encrypt sensitive fields; support deletion/redaction according to approved retention policy while retaining permitted accounting/audit evidence.

## Indexes
Published listing type/category/location/date; user-owned listings; participant conversation timestamps; pending referrals per seller; open dispute status; notification dedupe. Start with town/area filters; add geospatial indexing only when a measured requirement exists.
