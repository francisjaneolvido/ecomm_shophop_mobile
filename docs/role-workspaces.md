# Mobile role workspaces

All operational workspaces reuse the buyer navigation component and Poppins fonts. Operational headers use the web teal palette `#21C3A6` / `#18A98E`. Rounded white navigation bars highlight only the selected icon and label in teal, without a selected-tab pill. The central Scan button remains raised. Buyer and shared app accents use the same web teal tokens, including Cart, Checkout and Likes. Buyer and all operational roles use the same rounded white bar, spacing and Poppins labels. Pointer hover, keyboard focus and press do not paint a tab background or ripple; selection is conveyed by the teal icon and label. Shared role headers and metrics live in `lib/shared/widgets/shop_hop_role_layout.dart`.

| Role | Tabs |
| --- | --- |
| Seller | Home, Orders, Products, Earnings, Account |
| Logistics / branch staff | Home, Manifests, Scan, Activity, Account |
| Linehaul driver | Trips, Vehicle, Scan, History, Account |
| Pickup / delivery rider | Home, Tasks, Scan, Wallet, Account |

Pickup and delivery share the rider workspace. Assigned records and server-provided capability flags determine the visible actions. Navigation does not grant permissions.

## Behavior

- Seller Orders and Products have separate search values, preserved across tab switches and refreshes. Product review status is separate from archive status. New products and full edits still require Admin product approval.
- Rider active tasks can be searched by tracking code, recipient/shop name and address. Pickup actions open the QR scanner; delivery proof and failed-attempt actions follow API permissions. Existing loaded data remains visible if session validation temporarily loses its connection.
- Linehaul lists a trip already in transit first, then scheduled trips in ascending ID order. Errors appear on every tab with Retry. Destination arrival remains an action for destination Logistics, not the driver.
- Logistics staff retain their assigned branch restrictions. Manifest loading, inbound manifest receiving and individual parcel scanning use the existing API and confirmation flows.
- Tappable account rows now paint feedback on their own Material surface. Compact layouts support 320px and 390px phone widths.

## Automatic refresh

This is foreground polling, not a WebSocket push connection.

- Seller, Rider and Logistics: every 15 seconds.
- Linehaul: every 10 seconds.
- Pauses when the app is backgrounded or the workspace is covered by another route/dialog. The shared refresh helper also refreshes on resume when eligible.
- Rider pauses on Scan and while delivery/return/COD writes are pending.
- Logistics polls Home/Activity only; it preserves scanner inputs and parcel previews. Staff branch selection stays locked.
- Linehaul pauses on Scan, during camera activity and while a manifest preview remains open.
- Concurrent workspace refresh reads are serialized. Explicit refresh after an action waits for any earlier read and then requests fresh data.

## Verification

Mobile regression command:

```powershell
flutter test --reporter expanded
```

Current backend contracts and seller parity checks (isolated SQLite `:memory:` database):

```powershell
php artisan test tests/Feature/MobileRoleWorkspaceContractTest.php tests/Feature/SellerWorkspaceSyncTest.php tests/Feature/MobileScannerRouteContractTest.php
```

The current API checks cover role boundaries, owned trips, branch restrictions, assignment capability flags, QR bypass rejection, required delivery proof/COD confirmation, and seller approval/profile/password parity. No production controller, schema or database changes were needed for this UI batch.

`build/role_design_preview.dart` uses read-only sample data to preview the actual workspace widgets. It blocks all writes. Screenshots are in `build/role-*-390.png` and `build/role-*-320.png`; they are design previews, not evidence of live deliveries.

## Existing test limitations

An exploratory run of `LogisticsOperationsJourneyTest` and `RiderDeliveryEvidenceJourneyTest` found five existing failures/errors. Their assignment setup does not satisfy the current pickup-booking/service-area checks, so expected delivery records are not created. These files and production rules were not changed for this UI batch.

`tests/Feature/SellerChatJourneyTest.php` currently contains a Blade template instead of a PHP test. Whole-directory PHPUnit discovery prints that template and exits nonzero even when filtered assertions pass. The explicit three-file command above excludes it and exits successfully.

Actual device camera permission, QR capture, proof photo/file upload and physical custody flows still need device acceptance testing. Keep the local Laravel server reachable from the phone (USB reverse or a configured LAN URL). After adding the audio plugin, stop the current Flutter run and run the app again so the native plugin and bundled audio assets are included.


## Raised Scan navigation and scanner feedback

- Rider, Linehaul and Logistics place Scan in the middle (index 2 of five tabs). The raised button remains inside the navigation hit-test area and supports enlarged text. Seller shares the teal header and white navigation without a Scan item.
- Logistics Manifests groups the existing inbound receiving and outbound loading screens. No extra API writes occur on tab selection.
- Poppins 400 is used for body copy, 500-600 for labels/actions and 600-700 for headings/totals. Explicit 800/900 weights were removed from the redesigned operational screens.
- Seller summary counters open orders/inventory; rider counters open the corresponding task filter. Seller inventory offers All, Pending review, Low stock and Archived filters.
- The shared camera panel includes a QR frame, flashlight where supported, processing/paused states and camera controls. Linehaul/inbound scans identify Manifest QR; rider and individual Logistics scans identify parcel waybills.
- The three locally generated WAV assets provide verified, confirmed and error tones. A valid server preview produces the short verified cue. Completion cues follow successful server confirmations, including arrival, intact receipt, loading and custody. Preview/cancel never produce a completion cue.
- Sound and vibration preferences are shared for the current app session. They can be toggled on scanner screens. No network fetch is needed for the sounds; phone volume/hardware/browser playback policies still apply.
- Repeated copies of the same feedback event/reference within 900ms are suppressed. Inbound arrival and receipt have separate operation references. Camera detections are locked before Rider preview awaits camera shutdown.
- Results scroll into view after a server confirmation. Failed writes retain details and require a new server preview before another confirmation. Outbound refresh preserves the successful result panel.

Additional checks: `test/scan_feedback_test.dart` validates feedback selection, duplicate suppression, preferences, unavailable hardware and WAV assets. `test/scanner_navigation_test.dart` checks raised navigation, Poppins/teal styling, verification versus confirmation, cancellation, retry/recheck, inbound arrival/receipt and outbound physical counts. Mock feedback outputs verify when cues are requested; actual speaker/vibration/camera behavior still needs phone acceptance testing.

- Verified review details replace the camera form and scroll into view. Switching Linehaul trips clears the prior manifest review. Entering Logistics Activity refreshes branch history immediately; choosing another outbound manifest reloads its current counts before confirmation.
