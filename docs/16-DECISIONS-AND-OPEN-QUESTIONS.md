# Decisions and open questions

## Working decisions
D01 working brand Sure Sente (changed from Tugeza Links on 2026-10-13); legal availability unconfirmed.
D02 mobile-first, one account, Work / Services / Deals.
D03 simplified profiles; no required CV for casual work.
D04 seller-authorised brokerage, accepted immutable commission terms.
D05 broad taxonomy; gated category activation.
D06 pilot direct payments; no custodial wallet or self-operated escrow.
D07 React/TypeScript + Phoenix/PostgreSQL proposed; inspect existing project before adopting.
D08 English first; reviewed localisation later.
D09 adult-only pilot and free work applications.

## Resolve before implementation/release
| Question | Owner | Deadline |
| --- | --- | --- |
| New repository or extension of Joblite/Omfix? | Founder | Before implementation |
| Pilot locality and anchor businesses? | Founder | Before pilot recruitment |
| Initial categories and transaction modes? | Product owner | Before category configuration |
| Phone OTP provider and cost budget? | Engineering | Before live auth |
| Official name/trademark and operating entity? | Founder/adviser | Before launch |
| Commission defaults and dispute policy? | Product/adviser | Before brokerage pilot |
| Payment partner if integrated? | Founder/provider | Before payment activation |
| Retention periods and evidence processing? | Privacy owner | Before live personal data |
| Staff support capacity and hours? | Operations | Before launch |
| Property/vehicle/legal review evidence? | Category owner | Before enabling those categories |

## Decision log template
ID; date; issue; alternatives; chosen approach; rationale; affected files; reviewer; revisit trigger. Keep assumptions explicit; change the source document as well as this log.

## Decision log
- G-20261012; 12 Oct 2026; guest-first browsing; blanket auth wall vs action-boundary auth; action-boundary with shared shell + pending-intent restore; browsing converts better and spec already required guest discovery; 01,02,03,04,05,12,14 + code; Omuut Tom; revisit if abuse of public endpoints observed.
- G-20261013; 13 Oct 2026; working brand rename; keep Tugeza Links vs adopt Sure Sente; Working brand changed from Tugeza Links to Sure Sente. Display/UI/docs updated; tugeza_* storage keys, DB role/names, migration module and API routes kept as compatibility identifiers; Sure Sente registration/trademark unconfirmed; README, 16-DECISIONS, IMPLEMENTATION-PROMPT, LOCAL-SETUP, web UI, backend home/plugs, index.html SEO + PWA manifest; Omuut Tom; revisit on trademark clearance / replacement domain-email settings.
