# Brokerage and commission specification

## Definitions
Seller/principal owns or is authorised to offer the listing. Broker is authorised to introduce customers. Buyer is the prospective customer. Platform records agreed terms and evidence; it does not guarantee an outcome or ownership.

## Agreement
Seller publishes terms; broker requests access; seller approves; broker accepts the exact immutable version. No commission opportunity is advertised as seller-authorised before approval. Link sharing before authorisation does not create entitlement.

Agreement includes listing/principal/broker IDs, version, fixed or percentage commission, currency, calculation base, earning trigger, payment deadline, attribution window, exclusions, cancellation/refund rule, evidence requirements and dispute route. Proposal default attribution window: 30 days; deadline: 7 days after accepted qualifying completion. Both are configurable and must be visibly accepted, not treated as law.

## Attribution
- Link click is interest, not a payable lead.
- Buyer chooses to submit details and consents to sharing with the named seller and broker.
- Lead has server timestamp and agreed contact identifiers protected at rest.
- First accepted eligible introduction within the window is the pilot default.
- Seller accepts or contests lead within a configurable period (proposed 48 hours).
- Silence remains pending and triggers reminders; it never automatically proves entitlement.
- Pre-existing customer exclusions require documented evidence dated before introduction.
- Suspected duplicates queue for review; shared phones do not automatically identify the same person.
- Multi-broker splits are excluded from MVP; later require a signed allocation totalling 100%.

## Referral and commission states
Referral: submitted → pending_attribution → accepted / rejected / disputed → negotiating → completed / cancelled / expired.
Commission: pending → earned → payment_reported → received; disputed can interrupt pending, earned or payment_reported. refunded/reversed applies to a previously earned/received claim with an audited adjustment.
No expected commission is counted as received income.

## Completion
Seller submits qualifying evidence with unnecessary personal details redacted. Broker can acknowledge or contest. Disputed claims freeze platform settlement automation where integration permits; staff record reasons and evidence. Admin cannot silently rewrite the agreement or claim a legal judgment.

## Money
Pilot commissions paid directly by principal to broker; platform records payer report and recipient acknowledgement separately. Verified provider transactions can confirm receipt later. No pooled deposits, withdrawable app wallet, or advertised escrow without approved provider support.

## Changes and abuse
New terms apply only to new agreements. Existing accepted versions survive listing edits. Self-referrals, fake buyer identities and fabricated sales are prohibited. Referrals to job candidates cannot be used to impose applicant fees. Preserve audit history and appeal routes.
