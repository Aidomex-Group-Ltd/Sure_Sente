# Simple UI/UX specification

## Principles
One decision per step. Familiar words. Visible pay or commission. Save effort. Explain status. Never require a CV for casual work. Avoid financial jargon, unexplained icons and dashboards full of metrics.

## Visual system (proposed)
- Font: system sans-serif; body and editable controls 16px minimum; headings 20–28px.
- Background #F6F8FA; text #142235; primary #14633F; white surfaces; neutral #D5DDE5 dividers.
- Check every actual colour pairing for WCAG AA; colour alone never communicates status.
- Spacing scale 4, 8, 12, 16, 24, 32px; controls at least 44×44px; comfortable 48px primary actions.
- Cards: 12px radius, restrained border, no ornamental shadows. Icons accompanied by labels.
- Responsive from 320px; no horizontal scrolling except genuinely wide admin tables.
- Support browser zoom, keyboard focus, semantic controls and reduced motion.

## Home
Location selector at top. Search placeholder Find work, services or deals. Tabs Work / Services / Deals. Post a need and Offer a service are visible. Opportunity cards show title, approximate area, pay/price/commission, time and key requirement. Main feed uses text-first compact cards; photos support goods/services.

## Low literacy and language
English first; architecture allows reviewed Luganda and other languages. Avoid auto-translated contracts. Use pay examples and brief explanations: Commission = what the seller agrees to pay you for a successful introduction. Voice-note messaging is optional later; no voice-only requirements.

## Low data and connectivity
Progressive web app; compress photos; no autoplay video; paginated results. Keep drafts on the device with a clear shared-device option to delete them. Offline browsing shows cached timestamp. Network-dependent actions visibly fail or queue with explicit status; never show Submitted before server acknowledgement.

## Forms
Post wizard: choose type → essentials → optional photo/details → preview → publish. Three to five required fields per step. Required fields are labelled. Inline errors preserve input and identify how to fix it. Camera/location permission requested only when used; manual alternatives remain available.

## Accessibility and privacy
Focus visible, status changes announced, labels programmatic, no hover-only action. Never publish phone number, identity document or exact home address by default. Share exact job location only after agreement and with consent.

## Guest-first UX (12 Oct 2026)
Guest landing leads with "Explore opportunities"; Join/Sign in secondary. Same Home/Find/Post/Inbox/Me shell for guests and users. Auth prompt is an accessible bottom sheet (mobile) / dialog (desktop): "Create an account to [action]", actions Continue with phone / Sign in / Continue browsing, focus preserved and restored. No auto signup popups during browsing. Pending intent (listing + action + safe draft) restored after login with revalidation and explicit confirm; never auto-submit.
