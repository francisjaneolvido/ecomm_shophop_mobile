# Category carousel synchronization implementation plan

**Goal:** Show every category supplied by Laravel in a compact mobile horizontal row, preserving Web carousel and existing filtered catalog navigation.

**Spec:** User's pasted ShopHop synchronize categories + compact swipeable UI request, 2026-11-13.

**Architecture:** Keep `config/shophop_categories.php` as the single category source; existing `/api/mobile/buyer/home` already maps all records in order through `BuyerHomeData`. Remove the presentation-only seven-item limit and unused hard-coded Dart category file. Introduce a focused carousel widget using backend slugs as stable identifiers, themed icons and readable labels. Reuse current Home loading, refresh and error handling, with explicit empty-category and retry states.

**Constraints:** No category data, schema, credentials, seller forms, APIs, standalone directory pages, or commerce flows changed. Keep Web carousel implementation. Preserve uncommitted unrelated work. No migrations/seeders, including database-backed test setup.

**Review focus:** Reachability of last category; consistent ordered slug/name/subcategory mapping; small-screen and enlarged-text overflow; safe empty/network handling; preserved filtered listing and homepage vertical scroll.

- [ ] Add regression tests that reach/tap all 14 API-provided categories via horizontal scrolling; test 320/390/480px and larger text, empty/retry, initial error/loading, failed refresh, live category updates, and zero-product listing navigation.
- [ ] Add database-free Laravel parity tests against actual category endpoints and Web homepage data/markup, with schema absence mocked and in-memory authenticated user; test runtime configuration changes so fixed lists cannot pass.
- [ ] Implement compact carousel, remove seven-item limit and dead hard-coded category list, preserve navigation callbacks, expose refresh failures and empty-category retry.
- [ ] Run focused and full Flutter suites, analyzer, database-free Laravel category suites, PHP/JS checks, Blade compile and whitespace checks. Report unrelated pre-existing test failures separately.
- [ ] Request focused independent review, resolve findings, update report, build and run on connected Android phone using the established local-backend launch script.

Ruling: Backend production code already returns all configured categories and Web already consumes the same source. Add parity coverage instead of adding an unnecessary endpoint or category service. Current configuration has no numeric category IDs; existing slug identity must be preserved, not replaced with invented IDs.
