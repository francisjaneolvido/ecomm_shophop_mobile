# Remove standalone category directories

Goal: Remove only the Web Browse Categories and Mobile All Categories directory screens and their entry points. Preserve category data/configuration, seller category forms, home category shortcuts, filtered product listings, search, recommendations and commerce flows. No schema, credential or real data changes.

- [x] Add regression checks for legacy redirects, no directory navigation, preserved category/subcategory product filtering and seller category options.
- [x] Mobile: delete BuyerCategoriesPage, its exclusive fetch helper, navigation callback/route builder and All Categories shortcut/See all link. Preserve home category product shortcuts and shared icon/model components. Route legacy category-targeted banners to existing search.
- [x] Web: remove the directory Blade, index-only controller code, desktop/mobile navbar/footer links and exclusive page links. Redirect the existing named /buyer/categories route (and local preview URL) to /search. Keep /buyer/category/{category} as the existing filtered product listing.
- [x] Clean directory-only JS/CSS; retain shared Help/Search styling and category suggestions. Point banners, help and product-list breadcrumbs to existing product search without redesigning those pages.
- [x] Run database-free Laravel checks, Flutter browsing/commerce regression tests and analyzer; check route/view references; install and launch updated mobile build on the connected phone.

Ruling: Existing Laravel discovery/seller suites use migrations or RefreshDatabase. Honor the user's explicit no-migrations restriction: run separate database-free route/view/configuration tests instead and report the unverified database-backed journeys. No real data or schema writes.

Verification: focused Flutter 28 passed; full Flutter 136 passed / 2 unrelated failed; analyzer 1 unrelated style info; Laravel database-free 5 passed / 27 assertions; PHP/JS syntax, Blade compilation, route listing and diff whitespace checks passed. Android debug build installed and launched on connected 2311DRK48G. Details and remaining limitations: ../../category-directory-removal-report.md.

Mobile has no registered named category route or Android category deep-link handler: the directory is currently opened only through MaterialPageRoute from BuyerHomeScreen. The Web category metadata API remains available for backwards compatibility; it returns data and is not the removed directory UI.
