# ShopHop category directory removal — 2026-11-13

Natanggal ang standalone buyer category directories sa Web at Flutter. Walang kapalit na page: ang lumang Web URLs ay HTTP 301 redirects sa existing `/search`. Na-build, na-install, at na-launch ang Android debug app sa connected `2311DRK48G` gamit ang local backend at USB port forwarding.

May existing uncommitted category-removal at unrelated changes na sa parehong workspace bago nagsimula ang audit. Kinompleto at ni-review ang removal; hindi ni-revert ang ibang ongoing work.

## Removed UI at navigation

- Mobile: `BuyerCategoriesPage` kasama ang directory search, cards, chips, counts; Home All Categories tile at directory See all link; `_openAllCategories` route builder, callback, import, at exclusive `getCategories` client helper.
- Web: `buyer/category/index.blade.php`, controller `index()` action at count query; desktop/mobile navbar at footer Categories links; directory-only homepage links, search footer destination, Help link, category breadcrumb, at local preview menu link.
- Nilinis ang directory-only CSS at JavaScript. Shared Help/Search styles at search category suggestions ay retained.
- Legacy category-targeted banners open existing search. Individual Home category shortcuts still open filtered product listings.

## Routes at retained dependencies

- `/buyer/categories` at `/categories`: HTTP 301 to `/search`, kasama ang old directory URLs na may query string.
- Local `/__dev/preview/buyer/categories`: redirect to `/search`.
- Retained ang `buyer.category.index` route name bilang compatibility redirect; wala na itong page/controller index action.
- Retained ang `/buyer/category/{category}`, subcategory/price/sort filters, category configuration, product relationships, seller category validation at forms, shared mobile category model/icon, at mobile category metadata API.
- Walang named mobile category-directory route o Android category deep-link handler dati; ang removed screen ay binubuksan sa `MaterialPageRoute`. Legacy banner targets now use search.
- Hindi binago ang schema, category/product records, `.env`, o credentials. Walang migrations o seeders na pinatakbo. Existing unrelated migration files in the working tree were left alone.

## Files sa removal scope

Relative paths sa `ecomm_shophop_mobile`:

- Deleted: `lib/features/buyer/presentation/pages/buyer_categories_page.dart`
- `lib/features/buyer/data/services/buyer_catalog_service.dart`
- `lib/features/buyer/presentation/pages/buyer_home_page.dart`
- `lib/features/buyer/presentation/screens/buyer_home_screen.dart`
- `test/buyer_redesign_test.dart`
- `docs/superpowers/plans/2026-11-13-remove-category-directory.md`
- `docs/category-directory-removal-report.md`

Relative paths sa `ecomm_shophop_web`:

- Deleted: `resources/views/buyer/category/index.blade.php`
- `app/Http/Controllers/Buyer/CategoryController.php`
- `routes/buyer.php`, `routes/web.php`, `routes/debug.php`
- `resources/views/partials/shopper-header.blade.php`, `resources/views/partials/footer.blade.php`
- `resources/views/home/part-1.blade.php`, `resources/views/home/part-2.blade.php`
- `resources/views/buyer/category/show.blade.php`, `resources/views/buyer/help/index.blade.php`
- `resources/views/search/index.blade.php`, `resources/views/dev/account-switcher.blade.php`
- `public/css/shophop-buyer-discovery.css`, `public/css/shophop-buyer-marketplace-v3.css`, `public/css/shophop-compact-ui.css`
- `public/js/shophop-buyer-discovery.js`, `public/js/shophop-search-suggestions.js`
- `tests/Feature/BuyerDiscoveryJourneyTest.php`, `tests/Feature/BuyerCategoryDirectoryRemovalTest.php`

May ibang pre-existing edits sa ilan sa mga files na ito; hindi lahat ng buong Git diff ay parte ng category removal.

## Verification

- Focused Flutter suite: **28 passed** across buyer redesign, catalog realtime, cart/checkout layout, variants, product gallery, and video catalog tests. Kasama ang no All Categories entry, banner-to-search callback, Home category shortcut, subcategory request filtering, search response handling, product details, Buy Now/cart connection, at checkout submission.
- Full `flutter test --no-pub`: **136 passed, 2 failed**. Failures: `rider_management_test.dart` — `changed Branch requires explicit rider coverage acceptance`; `shared_theme_widgets_test.dart` — `Shared navigation keeps hover, focus and press clear while supporting counts and tab changes` (missing `99+` badge). Nasa labas ng removal scope ang dalawang ito; hindi ginalaw ang rider/shared navigation implementation.
- `flutter analyze --no-pub`: **0 errors, 0 warnings, 1 info**, nonzero exit dahil sa existing style notice `curly_braces_in_flow_control_structures` sa `test/buyer_messages_test.dart:134`.
- Laravel database-free regression suite: **5 passed, 27 assertions**. Verified redirects, actual navbar/footer rendering, seller canonical subcategory options, category listing Blade/subcategory links, at existing search Blade rendering. Redirect tests bypass only maintenance middleware, na nangangailangan ng `platform_settings` database fixture.
- Laravel `route:list --path=categories --except-vendor`: compatibility redirects at preserved metadata API present.
- `php artisan view:cache`: successful. PHP syntax checks for affected routes/controller/new test: successful. Both edited JS files pass `node --check`.
- `git diff --check`: clean sa parehong projects. Source reference audit: walang removed mobile class/callback o web directory view links/styles sa active UI.
- Physical Android: debug APK built, installed, launched, and synced successfully. Local API probe and USB reverse succeeded. Build emitted existing Gradle/AGP/Kotlin future-support warnings.

Hindi pinatakbo ang database-backed Laravel journey/seller/full suites dahil gumagamit ang mga iyon ng migrations/RefreshDatabase. Kaya ang live database search results, seller create/edit writes, at buong Web cart/checkout transactions ay hindi claimed na end-to-end tested. Preserved ang code paths at na-check ang views/configuration; walang real purchase o seller write na ginawa.
