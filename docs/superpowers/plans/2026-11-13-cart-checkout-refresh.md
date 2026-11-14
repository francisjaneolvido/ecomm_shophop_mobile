# Cart and checkout implementation plan

Goal: Implement the user's detailed checkout/cart brief using the existing ShopHop Poppins, navy, pink and cream theme. Retain server totals, seller grouping, selected cart line IDs, stock checks, courier eligibility, COD, vouchers and address editing.

Approach: Refine existing screens and callbacks; share purchase typography, image and price presentation. Address first, seller order details, standard shipping, eligible couriers, optional note, existing vouchers, COD and backend order summary. Use white cards, 12px corners, 14–16px section/product titles and readable secondary text. Sticky bars adapt to narrow screens and scaled text. No new dependency or schema change.

- [x] Reproduce CartItem variantLabel's protected Eloquent attributes collision in an isolated test; read the actual cast attributes column and format only customer choices.
- [x] Add widget regressions for selected-line checkout, quantity/stock/delete, server preview/courier recalculation, duplicate Place Order taps, responsive layouts and keyboard insets.
- [x] Refine both existing screen presentations, reusing shared purchase widgets and the existing BuyerIconTile. Preserve all business callbacks and voucher options.
- [x] Guard the confirmation dialog/order request against repeated taps and block checkout during cart mutations.
- [x] Run scoped Flutter/Laravel tests and analyzer; review the changes; build/run on the connected phone if available. Do not create real orders for testing.

Root cause: CartItem and ProductVariant extend Eloquent Model, so `$variant->attributes` accessed from CartItem resolves the protected raw attribute bag. `getAttribute('attributes')` reads the intended JSON column. Both the mobile Cart API and checkout preview already call this shared formatter.

Validation: isolated model tests (no DB writes), HTTP-mocked Flutter widget tests and existing related voucher/theme tests. Existing unrelated workspace edits must remain intact. No production/shared data, credentials, migrations or financial rules may be changed.

## Final implementation and verification

The existing pages now use a compact address-first checkout layout, consistent Poppins type scale, white bordered cards on the existing cream background, navy prices/actions, shared image/price widgets, and existing pink/navy icon tiles. Technical Laravel, internal shipping fee-component, and admin-funding descriptions were removed from customer-facing text. Standard delivery, eligible courier choices, address editing, COD, shop/platform vouchers, seller notes and backend-calculated summaries remain available. The default address badge is conditional on the API flag.

The Cart retains selected line IDs/quantities, group/select-all, stock boundaries, unavailable states, deletion and synchronization. Checkout is disabled while cart mutations are pending. Repeated Place Order callbacks are guarded before both the confirmation dialog and the order request. Both bottom bars use responsive layouts and keyboard/safe-area insets.

### Changed files

Mobile:
- lib/features/buyer/presentation/pages/buyer_cart_page.dart
- lib/features/buyer/presentation/pages/buyer_checkout_page.dart
- lib/features/buyer/presentation/widgets/buyer_purchase_widgets.dart (new shared presentation)
- test/buyer_cart_checkout_layout_test.dart (new regression suite)
- this implementation/verification report

Backend:
- app/Models/Buyer/Cart/CartItem.php (variant presentation only)
- tests/Unit/CartVariantLabelTest.php (new isolated regression tests)

No dependencies, schemas, credentials, inventory records, shipping rules, financial calculations or unrelated role dashboards were changed.

### Checks

- The variant regression first reproduced the exact raw-row leak from the screenshot, then passed after the explicit JSON-column lookup fix.
- `php vendor/bin/phpunit tests/Unit/CartVariantLabelTest.php tests/Feature/CheckoutVerifiedNetworkEligibilityTest.php`: 9 passed, 34 assertions. No shared database writes.
- `flutter test test/buyer_cart_checkout_layout_test.dart test/buyer_voucher_v2_models_test.dart`: 10 passed. HTTP-mocked requests only; no real orders created.
- Responsive cases: 320/390/480 logical pixels, 1.0x/1.5x text, keyboard insets, long product/shop/courier names, larger cart prices and populated vouchers. Functional cases cover selection/quantity mapping, mutation lock, stock limits, unavailable items, group/select-all, deletion, courier recalculation/server totals, COD payload, confirmation/request duplicate guards and successful-order feedback.
- Scoped Dart analyzer (the three implementation files plus new test): no issues.
- `flutter analyze --no-pub`: one existing info in test/buyer_messages_test.dart:134 (curly_braces_in_flow_control_structures); files for that messages task were left unchanged.
- Additional shared-theme test run: the unrelated shared-navigation test fails its existing `99+` badge expectation. Shared navigation/theme implementation and that test are unchanged. This is not a passing whole-project test claim.
- Read-only code review found no confirmed functional regression. Its narrow-screen/voucher/stock/selection/deletion coverage gaps were addressed before final verification.
- Android debug APK built, installed and launched on PRR8NNCEHUU8YHX8 with the existing local API/USB forwarding.

### Remaining manual checks

Review My Cart and Checkout visually on the physical phone, including address editing and choosing a voucher for an eligible real cart. ADB screenshot capture worked, but device input injection is denied by the phone's INJECT_EVENTS security setting, so automated navigation for a physical-phone screenshot was unavailable. No phone security settings were changed. Real order creation was intentionally not exercised against shared user orders; automated tests verify the submission flow with isolated responses.
