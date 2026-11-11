# Rider Management: actual Android device acceptance

Date: 2026-11-09 (Asia/Manila). Status: IN PROGRESS; not production sign-off.

## Preserved scope

Existing feature code, navigation, schema, seeders, credentials and production are unchanged. Tests use the retained isolated MariaDB restore, with source database writes blocked and a per-phase source fingerprint. New acceptance parcels were created through existing Branch batch services; no database seeder or migration was executed.

A separate debug APK uses application ID `com.example.shophop.acceptance` and the same app code/UI. The original `com.example.shophop` remains installed with its data/session intact. The API is explicitly `http://127.0.0.1:8011/api/mobile` over USB reverse to a loopback-only private server, not the production default.

## Emulator/environment diagnosis

- Host: Windows 11, AMD Ryzen 5 5500U, 6 cores/12 logical processors; virtualization enabled. Previous emulator logs confirm WHPX operational.
- Usable physical RAM: approximately 7.3 GiB. Before an emulator was started in this phase, available RAM was approximately 0.94 GiB.
- Existing AVD: Android API 36.1 Play Store x86_64, 6 configured vCPUs, 2048 MiB RAM, 1080x2400 display. Previous launches used SwiftShader software rendering.
- Previous evidence shows Android Pixel Launcher and System UI ANRs, including before successful app interaction and after cold boot with reduced RAM/cores. These are OS/launcher ANRs, not evidence of a ShopHop exception.
- The project config permits Gradle heap up to 8 GiB plus metaspace up to 4 GiB, above the host's physical memory. These are configured maxima, not a measurement of actual allocation. Combined with the low available RAM and software-rendered emulator, host memory/CPU pressure is the leading diagnosis.
- The acceptance APK built successfully using a private Gradle init script and temporary command-line limits: 1536 MiB heap, 512 MiB metaspace, 128 MiB code cache, two workers. Project Gradle settings were not changed. No AVD wipe/reset was performed.
- Physical-phone comparison is being used to distinguish app behavior from the unstable emulator. A definitive root-cause trace for the old emulator ANR was not captured; do not claim that every possible app performance issue has been excluded.

## Physical device and build

- Phone model: 2311DRK48G; Android 16; arm64-v8a; 1220x2712 display, 480 dpi.
- USB debugging authorized; separate acceptance APK installed successfully and launched. Both package IDs were verified.
- Acceptance APK SHA256: `0F0B5DBCBB9DADB389FE8E27BA43019C308C5741B78C99DA71C8F45D1EDD2C57`.
- Private artifact: `.codex/backups/shophop-rider-management/20261108T145301Z/device-acceptance-20261109/ShopHop-device-acceptance.apk`.
- The phone OS currently rejects remote taps with `SecurityException: INJECT_EVENTS`. The user is enabling USB debugging (Security settings), or manual tapping can be used. This is an Android automation permission blocker, not a confirmed app defect.
- A personal floating window was minimized by the user; the initial screenshot containing it was removed from the private evidence. Later evidence should contain only acceptance app/system permission UI.

## Acceptance matrix

Previous automated tests remain baseline evidence; they do not count as a Passed actual-device case.

| ID | Actual-device case | Status | Evidence / expected result |
| --- | --- | --- | --- |
| D01 | Separate APK build/install and USB connection | PASSED | Separate ID installed; original package retained; isolated API HTTP 200 |
| D02 | App launch/render on Android 16 | PASSED | App activity and native Flutter accessibility controls available; no observed app crash at launch |
| D03 | Rider login and session | NOT YET VERIFIED | Private test rider must log in through actual UI; correct role and token |
| D04 | Company, Branch and barangay coverage | NOT YET VERIFIED | Dashboard/account must show isolated provider, assigned Branch and Real coverage |
| D05 | Availability and busy state | NOT YET VERIFIED | Assigned route shows busy; disallowed changes blocked; valid online/break round trip |
| D06 | One multi-parcel pickup batch | NOT YET VERIFIED | Two parcels/two stops displayed without duplicate task cards |
| D07 | Camera permission denial/retry | NOT YET VERIFIED | Denial gives useful message, no custody mutation; granting permits scanner |
| D08 | Physical camera QR decoding | NOT YET VERIFIED | Camera decodes each generated test label; no injected/manual barcode substitution |
| D09 | Custody preview, cancel and confirm | NOT YET VERIFIED | Preview/cancel do not mutate; confirmed physical custody records Rider handoff |
| D10 | Duplicate/invalid QR handling | NOT YET VERIFIED | No duplicate custody event or unrelated parcel mutation; clear error |
| D11 | Scan audio/haptic feedback | NOT YET VERIFIED | Tester confirms device feedback on verified/confirmed/error states |
| D12 | Pickup Branch receipt and route completion | NOT YET VERIFIED | Only physically collected test parcels can be received; route requires all outcomes |
| D13 | Multi-parcel delivery batch and Branch handoff QR | NOT YET VERIFIED | Separate delivery type; two parcels; only one active route |
| D14 | Proof-of-delivery file selection/upload | NOT YET VERIFIED | Actual Android picker returns image bytes; successful private proof upload |
| D15 | COD collection/amount/wallet/remittance | NOT YET VERIFIED | Explicit collection; server-derived amount; only correct Rider's COD |
| D16 | Failed delivery with independent parcel outcome | NOT YET VERIFIED | Required reason; other parcel stays valid; Branch return required before completion |
| D17 | Mobile actions update Branch and Main Hub | NOT YET VERIFIED | Read actual rendered monitoring responses after device commits; counts/status match |
| D18 | Foreground status/task refresh and notices | NOT YET VERIFIED | Updates arrive through existing foreground polling without manual app restart |
| D19 | Background/native push notifications | NOT YET VERIFIED | Current app code has foreground polling; native push pipeline is not configured in this scope |
| D20 | Navigation, keyboard, scrolling and responsive layout | NOT YET VERIFIED | All Rider tabs/actions usable at the physical phone's display/font settings |
| D21 | Network/loading/error/recovery | NOT YET VERIFIED | Stop isolated API only; retain data and show error; recover after API restart |
| D22 | Background/resume and session/logout | NOT YET VERIFIED | Resume refreshes safely; logout closes acceptance session |

## Isolated fixture and monitoring

- Existing test Rider: 2599, provider 126, Branch 1944. Credentials remain private; no existing credentials were changed.
- Pickup batch: 63 (`RB-01M6YT969N5N6SPJ1F64DP0TSR`), in progress, two parcels/two stops.
- Test labels: `SHP-20261108-000088` and `SHP-20261108-000089`. These are test waybills, not real shipments.
- Initial Branch and Main Hub JSON/rendered batch responses both returned HTTP 200 and displayed the expected batch. Source fingerprints matched before and after setup.
- Camera preview, custody confirmation, delivery completion and COD actions must originate from the phone to count as actual-device results. Branch receive/sort/dispatch actions may be driven through existing authorized services in the isolated database and will be labeled as such.
- QR labels use the same qrcodejs library as existing ShopHop waybills. They are diagnostic test assets, not changes to product UI.

## Manual fallback if the device becomes unavailable

Log in to the acceptance app with the private test account; verify company/Branch/coverage; open the two-parcel pickup route; deny camera then grant/retry; point the physical camera at each test QR; cancel then confirm custody; verify duplicate rejection and feedback. Check Branch/Main Hub updates. Receive both parcels at the Branch, close pickup, sort and dispatch a separate delivery batch. Scan Branch-to-Rider handoff, upload proof and explicitly collect COD on one parcel; record a failure/reason on the other; return failed custody before closing the route. Verify wallet/remittance, foreground updates, network failure/recovery, navigation and logout. Every unexecuted row remains NOT YET VERIFIED.

## Private evidence

Private folder: `C:/Users/HP 15s/.codex/backups/shophop-rider-management/20261108T145301Z/device-acceptance-20261109`.

Contains guarded API/build controls, source fingerprint, test fixture metadata, QR labels, Android accessibility snapshots and timestamped Branch/Main monitoring results. No production deployment or schema change is authorized by this report.
