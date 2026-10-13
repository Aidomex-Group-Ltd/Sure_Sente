# Acceptance criteria and QA

## Critical scenarios
| ID | Scenario | Required result |
| --- | --- | --- |
| Q01 | Guest selects town and opens work | Pay, scope, time and requirements visible before sign-in |
| Q02 | Worker applies without CV | Minimal application accepted; employer alone sees details |
| Q03 | Owner changes offered pay | New version; earlier acceptance not silently reused |
| Q04 | Provider and customer accept quote | Same immutable scope/cost shown to both |
| Q05 | Unauthorised broker submits lead | Server denies action; no commission claim created |
| Q06 | Broker accepts terms; buyer consents | Correct version and consent stored before sharing |
| Q07 | Two concurrent referrals share contact | Reviewable duplicate handling; no double automatic payout |
| Q08 | Seller ignores lead | Remains pending; no automatic commission entitlement |
| Q09 | Seller edits commission | Existing agreement and calculation unchanged |
| Q10 | Seller reports payment | Not received until payee acknowledgement or reconciled provider evidence |
| Q11 | Buyer cancels qualifying deal | Agreed cancellation rule and audited adjustment applied |
| Q12 | Another user requests private document | Denied; access attempt logged appropriately |
| Q13 | Disabled property category posted by API | Server rejects, even if UI manipulated |
| Q14 | Network drops during submit | Draft preserved; no false success; retry idempotent |
| Q15 | OTP brute force/replay | Limits enforced; verified code not reusable |
| Q16 | User reports nonpayment | Case created with evidence, progress and appeal route |

## UI verification
320px/360px/768px/desktop; budget Android browser; 200% zoom; keyboard; screen-reader labels and announcements; touch targets; contrast; long titles; UGX amounts; no location permission; slow connection; empty/loading/error states. No nested scroll traps.

## Technical checks
Unit/domain tests for attribution, terms, commission rounding, transitions and permissions. Integration tests for concurrency, idempotency, uploads, callbacks and recipient privacy. E2E three primary journeys and dispute. Verify backup restore and redacted logs. Test live providers only with approved test accounts, never real customer payments by accident.

## Release evidence
Record build/commit, test outcomes, known limitations, category gates, support ownership and rollback procedure. Do not claim security/legal compliance or successful deployment without evidence.

## Guest-first acceptance (12 Oct 2026)
Fresh visitor browses all public modules, deep links, search/filters and manual location with no account or permission prompts. Dismissed auth sheet never blocks browsing. Signup restores listing/filters/draft/action with revalidation; nothing consequential auto-submits; closed listings handled. Guest requests get 401 on protected mutations and no private fields. Sign-out clears private state, keeps public browsing. Verified 12 Oct 2026: guest 200s, 401s, draft 404/owner 200, no-leak projection, mix test 10 passed, web build ok.
