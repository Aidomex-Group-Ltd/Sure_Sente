# Information architecture

## Mobile navigation
Five bottom items: **Home, Find, Post, Messages, Me**. Home includes Work / Services / Deals tabs. Find contains query, category and location. Earnings belongs under Me; show it only when relevant. No separate account registration per role.

## Page map
| Route | Purpose | Access |
| --- | --- | --- |
| / | Nearby listings and primary actions | Guest |
| /find | Search and filters | Guest |
| /listings/:id | Detail, terms and enquiry | Guest; action requires account |
| /post | Guided listing draft | Signed in |
| /applications | Work applications and offers | Owner |
| /bookings/:id | Agreed service/work and outcome | Participants |
| /messages | Conversation list | Signed in |
| /messages/:id | Participant messages | Participants |
| /deals | Authorised brokerage opportunities | Guest |
| /referrals/:id | Attribution and commission timeline | Participants |
| /me | Profile and task shortcuts | Owner |
| /me/earnings | Expected, confirmed and reported-paid amounts | Owner |
| /reports/:id | Own report/dispute updates | Reporter/participants |
| /help | Help and reporting routes | Guest |
| /admin | Review queues and configuration | Scoped staff |

## Ownership
Workers see their applications; employers see applications to their listings. Brokers see their leads; sellers see leads for their listings. General users cannot browse candidate contact lists. Staff access is permissioned and audited.

## Desktop
Reuse the same flows; sidebar may replace bottom navigation. Use detail and conversation panes only where width permits. No simulated phone frame in production.

## Guest-first routing (12 Oct 2026)
Public routes (no auth): /, /find, /services, /deals, /listings/:id, /profiles/:id, /help. Guest-aware shell screens: /post, /messages, /me explain the account need with "Continue browsing". Protected routes redirect to /auth with an allowlisted returnTo: /messages/:id, /applications, /broker, /earnings, /admin. Mutations always require auth + ownership/capability checks; sign-in alone never authorises brokerage or ownership.
