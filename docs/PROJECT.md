# Can I Wear — Project Truth

> Status: ACTIVE
> Last updated: 2026-10-19
> Source of truth: YES

## Purpose

Can I Wear is a simple, recommendation-first mobile app answering weather-based questions about **items**. Its **first real-device milestone** focuses on “Can I wear my leather jacket today?” The broader app supports other predefined items by the first public release, and custom items later. The Phase 4 Home Screen communicates item-specific daily advice with explicit verdicts and timing (D-060); exact labels for the different item behaviors are deferred to custom-item configuration.

For the leather jacket specifically, the main concern is avoiding rain/fog damage and excessive heat, not maximizing comfort.

## Original leather-jacket foundation (Phases 0–3)

The initial vertical slice and its already approved rules:
- supports a leather jacket only;
- uses the user's current location;
- retrieves weather for that location;
- evaluates the day;
- can split the day into meaningful periods when conditions change;
- prioritizes rain protection;
- treats forecast fog/mist as an avoid condition because atmospheric moisture can damage leather;
- uses initial fixed thresholds stored in one centralized configuration;
- has no personal recommendation settings;
- has default-on Guided Home and Show How It Works presentation switches and an off-by-default Debug Enabled switch in Apple system Settings;
- gives an immediately understandable recommendation;
- must work on a real iPhone;
- is implemented natively for iOS using Swift + SwiftUI;
- uses a weather service through a thin replaceable provider abstraction; Open-Meteo is the development provider and the production provider remains to be confirmed before distribution;
- defers Android until the mature-iOS stage;
- targets App Store delivery.

## Product philosophy

This is a decision app, not a weather dashboard.

The user should not have to study weather information.

The product should answer quickly and correctly:
- Yes
- Maybe
- No
- or a small number of meaningful periods

with a very short reason.

For Phase 4 daily advice, D-060 replaces a universal daily Yes/Maybe/No label with an explicit verdict and time scope; hourly answers can retain those labels. See `PRODUCT_SPEC.md` and `UX.md` for the current presentation requirements.

D-063 and its D-064 amendment lock the two shared daily algorithms and the useful-hour minimum. For item/daily-advice work, read those decisions and [WEATHER_LOGIC.md](WEATHER_LOGIC.md#two-shared-daily-aggregation-policies-d-063); shared wording must not be mistaken for one universal algorithm. Agent handling is in `AI_RULES.md` §5.1.

## Primary product rule

**Rain protection beats comfort.**

The jacket should not be recommended simply because the temperature is good if meaningful rain is expected.

The approved leather-jacket thresholds and daily grouping rules are maintained in [WEATHER_LOGIC.md](WEATHER_LOGIC.md); they are centralized in the app and may be tuned after real-world testing only through an approved change.

## Quality bar

The project is judged by the final user experience:
- easy to understand and interpret
- correct recommendations;
- reliable weather/location;
- real-device reliability;
- fast startup;
- no unnecessary delays;
- no stutters;
- no annoying permission flows;
- no micro-frustrations;
- strong automated tests;
- successful App Store delivery.
- no frustrating ux issues

## First public release and deferred features

The first App Store release (Phases 4–7) **adds multiple predefined items and the iOS widget** to the already working leather-jacket foundation. The initial item collection, item-specific rules, multi-item screen and exact widget form are subject to user approval in Phases 4–5.

**Not required for the first public release:**
- custom/user-created items;
- multiple saved cities and recurring location schedules;
- notifications;
- adjustable per-item thresholds;
- recommendation history, accounts/sync or Android.

**Original core milestone non-goals (historical context):**
- multiple clothing items;
- personal weather preferences;
- accounts/profiles;
- wardrobe management;
- social features;
- recommendation history;
- background location tracking;
- broad settings.

The approved Guided Home and Show How It Works display preferences plus the technical debug switch form a focused system Settings surface; none alters recommendation policy.

## Future product scope

After release, the approved early sequence begins **basic custom items → editable thresholds → saved/multiple locations**. Later scope and provisional ordering are maintained in [ROADMAP.md](ROADMAP.md); social features remain excluded.

## Product name

**Can I Wear** is the locked official product/app name.

## Truth hierarchy

When sources conflict:
1. Approved decisions in `DECISIONS.md`
2. Current requirements in `PRODUCT_SPEC.md`
3. Technical constraints in `TECH_SPEC.md`
4. Weather logic in `WEATHER_LOGIC.md`
5. UX guidance in `UX.md`
6. Active defect records and verification state in `ISSUES.md`
7. Roadmap/TODO

`ISSUES.md` records observed behavior and fix status; it does not override approved expected behavior in items 1–5. If an issue requires different product behavior, it must go through the decision process before implementation.

AI must not convert a proposal or assumption into a decision.

## Document responsibilities

The hierarchy above resolves conflicts; this list says **where to maintain each kind of information**. A summary or link in another file does not become a second place to change the rule. Existing repetition can be consolidated separately without changing approved behavior.

| File | Maintains |
| --- | --- |
| `PROJECT.md` | Project purpose, milestone distinction, and truth hierarchy. |
| `AI_RULES.md` | Instructions for AI/developer work and decision handling. |
| `DECISIONS.md` | Approved decisions, supersession history, and explicitly undecided choices. |
| `PRODUCT_SPEC.md` | Current user-facing requirements and product scope; exact jacket classification and grouping rules belong in `WEATHER_LOGIC.md`. |
| `WEATHER_LOGIC.md` | Current item-specific weather rules, daily evaluation, missing-data and period grouping; distinguish the implemented leather-jacket foundation from approved/pending additional item policies. |
| `UX.md` | Approved presentation, interaction and accessibility requirements; open design questions stay labeled open. |
| `TECH_SPEC.md` | Technical architecture, integrations, caching implementation constraints and settings storage contracts. |
| `ISSUES.md` | Short, ID-based list of observed defects and their resolution/verification status; other files may refer to issue IDs. |
| `ROADMAP.md` | Feature scope, milestone sequence and future phase placement. |
| `IMPLEMENTATION_PLAN.md` | Subphase dependencies, decision gates and acceptance criteria; not new product approval. |
| `TODO.md` | Execution status, validation evidence and remaining work; not new product approval or a duplicate issue ledger. |
| `IMPLEMENTED_RULES_FLOWCHARTS.md` | Dated, non-authoritative description of implementation; not an approval or source of expected behavior. |
