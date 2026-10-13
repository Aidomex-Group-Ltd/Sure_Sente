# Atomic implementation plan

Each item should be a reviewable change with migration, UI, validation and acceptance evidence where relevant. Complete one vertical slice before expanding scope.

| Phase | Atomic deliverables | Exit criterion |
| --- | --- | --- |
| 0 Discovery | Select pilot area/categories; interview buyers; settle decisions; inspect existing code if any | Named pilot sponsor and agreed workflows |
| 1 Foundation | App shell; accessible components; phone auth; profiles; category configuration; permissions | Guest browse and secure account work on phone |
| 2 Listings | Draft wizard; preview; publish/review; images; search/location; detail screens | Real pilot listings posted and discoverable |
| 3 Work/services | Applications; offers; quotes; accepted booking; scoped chat; completion | End-to-end paid-work record, payment status separate |
| 4 Brokerage | Terms versioning; authorisation; consented lead; attribution; outcomes; claims | Referral to received commission passes QA |
| 5 Operations | Report queues; decisions/appeals; notifications; audit; export; support scripts | Staff can resolve pilot scenarios |
| 6 Pilot release | Backups; restore exercise; mobile QA; monitoring; gates; onboarding | Release checklist signed; production pilot |
| 7 Expansion | Enabled-category reviews; vehicles/property; provider payments; languages | Separate approval and QA per added capability |

## Suggested tickets
F01 shell/navigation; F02 OTP; F03 profile; L01 taxonomy; L02 wizard; L03 review; L04 search; W01 apply; W02 offer/version; W03 booking/outcome; M01 messaging; B01 agreement; B02 authorisation; B03 consent/lead; B04 duplicate/attribution; B05 commission; B06 payment acknowledgement; O01 disputes; O02 admin; O03 notifications; O04 backups/observability.

## Dependencies
B03 requires B01/B02 and consent storage. B05 requires accepted attribution and qualifying outcome. Provider settlement requires approved payment gate. Property requires private evidence, authority review, country gate and category QA. No front-end-only fake persistence counted as complete.

## Change discipline
Read repository instructions first, reuse existing theme and auth where compatible, preserve unrelated functionality, keep migrations reversible where practical, and never deploy/push from the scaffold alone. Actual implementation follows user-authorised repository workflow.
