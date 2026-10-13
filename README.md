# Sure Sente — Product and implementation scaffold

Version 0.1 • 12 October 2026 • Owner: Omuut Tom

Working brand: **Sure Sente** (working brand; official registration and trademark clearance unconfirmed). Tagline: **Work. Connect. Earn.**
Status: proposed specification, not implemented software. Naming, integrations, pricing, and category activation require validation. All examples are illustrative.

## Product
A mobile-first marketplace for informal workers, households, businesses, sellers and authorised brokers. People earn through paid work, selling services, and introducing customers under explicit commission agreements. A single account can participate in all three.

## Read in order
1. [Product requirements](01-PRD.md)
2. [People and journeys](02-PERSONAS-AND-JOURNEYS.md)
3. [Information architecture](03-INFORMATION-ARCHITECTURE.md)
4. [UI/UX and accessibility](04-UI-UX-SPEC.md)
5. [Screens and microcopy](05-SCREEN-SPEC.md)
6. [Categories and listing fields](06-CATEGORIES-AND-LISTINGS.md)
7. [Brokerage rules](07-BROKERAGE-WORKFLOWS.md)
8. [Trust, disputes and moderation](08-TRUST-AND-SAFETY.md)
9. [Country and category launch gates](09-COMPLIANCE-AND-LAUNCH-GATES.md)
10. [Architecture](10-TECHNICAL-ARCHITECTURE.md)
11. [Data model](11-DATA-MODEL.md)
12. [API and integrations](12-API-AND-INTEGRATIONS.md)
13. [Atomic implementation roadmap](13-IMPLEMENTATION-PLAN.md)
14. [Acceptance and testing](14-ACCEPTANCE-AND-QA.md)
15. [Pilot and operating model](15-PILOT-AND-OPERATIONS.md)
16. [Decisions](16-DECISIONS-AND-OPEN-QUESTIONS.md)
17. [Agent implementation brief](IMPLEMENTATION-PROMPT.md)

## Specification authority
PRD owns scope; categories own fields; brokerage owns commission logic; data model owns persisted states; UI spec owns interaction patterns; acceptance owns release checks. Resolve conflicts before coding, record the decision, and update affected documents together.

## Launch boundary
Design supports broad categories. Initial launch: one Ugandan locality, adult users, paid tasks, service bookings and selected ordinary-goods brokerage. Property and specialised transactions are supported in the taxonomy but stay disabled until their launch gates pass. No self-operated wallet, credit, or escrow in the first release.
