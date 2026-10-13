# Categories and listing schemas

## Broad taxonomy
| Family | Examples | Transaction modes | Activation |
| --- | --- | --- | --- |
| Work | Cleaning, loading, gardening, farm labour, events, admin | Task, shift, fixed-term | Pilot |
| Services | Repairs, trades, tailoring, beauty, tutoring, digital work, logistics | Quote, booking, sourcing | Selected pilot categories |
| Household goods | Furniture, appliances, clothing, electronics | Sale, rental, authorised referral | Selected pilot categories |
| Business goods | Tools, equipment, machinery, supplies | Sale, rental, bulk sourcing | Category review |
| Agriculture | Produce, inputs, livestock, equipment | Sale, sourcing, rental | Per-subcategory review |
| Vehicles | Cars, motorcycles, bicycles, commercial vehicles | Sale, rental, hire | Authority/transaction gate |
| Property | Rooms, homes, commercial space | Rent, sale, lease | Property gate |
| Land | Residential, agricultural, commercial plots | Sale, lease | Land gate |
| Events and hospitality | Catering, venues, equipment, accommodation | Booking, rental | Selected categories |
| Specialised services | Health, finance, legal, overseas recruitment | Professional referral only where approved | Disabled until reviewed |

Hire purchase, rent-to-own and instalment arrangements are modelled as future modes. Do not activate credit or legally significant ownership workflows without approved terms and relevant partners. No implication that every category is permitted.

## Common fields
Owner; type; category; title; description; currency; price/pay basis; approximate location; dates; availability; photos; status; brokerage enabled; timestamps. Store integer minor monetary units, not floating-point prices. Missing price must say Quote required, not zero.

## Type-specific fields
- Work: tasks, total/hour/day pay, hours, dates, required skills, tools supplied, physical requirements, payment timing, number of workers.
- Service: scope, exclusions, service area, travel/material costs, pricing basis, availability.
- Goods: condition, quantity, unit, delivery/pickup, warranty statement, seller authority.
- Vehicle: type, make/model/year, condition, registration evidence private, ownership/agency basis; exact identifiers redacted publicly.
- Property/land: sale/rent/lease, area, size and units, asking price and billing period, authority basis, viewing arrangements, evidence private. Do not collect exact location publicly by default.
- Brokerage: commission rule, payer, trigger, due date rule, attribution window, duplicate/pre-existing lead rules, cancellation policy, eligible brokers and authorisation.

## Listing states
Draft → pending_review → published → paused / closed / expired. rejected and removed are moderation outcomes. Revisions to published critical terms are reviewed and versioned. Closed listings cannot accept new applications or referrals.

## Category configuration
Versioned category records define required fields, allowed modes, verification level, moderation policy, country and enabled flag. Admin cannot turn on a gated category without a recorded approval and checklist.
