# Technical architecture

## Proposed stack
Responsive React + TypeScript PWA; Phoenix JSON API and Channels; Ecto/PostgreSQL; background jobs through an established queue such as Oban; private object storage; configurable SMS/email provider. Confirm package versions during implementation. These are proposed defaults suited to the founder's existing skills.

## Deployment
Start with a modular monolith, one database, container deployment, HTTPS reverse proxy and automated backups. Avoid Kubernetes, microservices or self-hosted AI requirements for MVP. Existing infrastructure may be reused only after inventory and isolation review.

## Domain modules
Accounts, Profiles, Locations, Categories, Listings, Applications, Quotes/Bookings, Messaging, Brokerage, Notifications, Moderation, Audit, ProviderPayments. Each owns validation and state transitions. Calls share transactions where cross-module integrity is needed.

## Authentication and access
Phone OTP with abuse limits and replay protection; optional email. Secure session cookies, CSRF controls and scoped staff permissions. One user with multiple capabilities, not multiple credentials. Server-side object-level authorisation on every access. Sensitive changes require recent authentication.

## Reliability
Idempotent create/accept/outcome actions; transaction-safe lead acceptance and commission transitions; outbox for notifications; retry with deduplication; pagination; stale-data labels; optimistic locking of agreements and listings. Audit monetary actions append-only.

## Nonfunctional targets (proposed)
Readable at 320px; critical flows on budget Android browsers; text-first initial route budget ≤250KB compressed JS where feasible; measured p75 LCP ≤2.5 seconds under representative pilot conditions. Collect real measurements before claiming performance. No autoplay; responsive compressed image sizes.

## Operations
Health checks, structured redacted logs, error reporting, migration rollback planning, database backup restoration exercise and alert ownership. Separate production/staging keys; secrets outside source. Test realistic disconnects and provider timeouts.

## AI boundary
Optional drafting/help later, with user review. No AI-only identity verification, legal conclusions, entitlement adjudication or earnings claims. Initial matching uses transparent categories/location/availability filters.
