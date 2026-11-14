# Review upload fix

Confirmed diagnostic: the PHP process actually serving port 8000 (PID 25672, started Nov 11) loaded upload_max_filesize=2M, post_max_size=8M. Current CLI php.ini is 5M/8M and was modified Nov 12. A real multipart synthetic PNG of 2 MiB + 168 bytes returned PHP upload error 1 with size 0 before Laravel. Temp storage is writable. The existing reviews.media column and public storage link are present. No migration is needed or authorized to apply.

Scope: preserve review eligibility and buyer/product idempotency; keep 6 photos at 5 MiB each and 2 MP4 videos at 30 MiB each. Start the local server with explicit per-process 30M file / 96M request limits, keeping photo-specific 5 MiB validation in Laravel. Do not edit global PHP configuration or credentials.

- Add tests for PHP upload failures, friendly client errors, MIME headers, optional media, real media validation, retry and UI recovery.
- Validate attachment signatures, names, actual byte sizes and counts from the in-memory picker snapshots; send precise multipart MIME metadata.
- Add backend upload-specific validation messages, consistent extension/MIME checks, and preserve transactional cleanup.
- Require a confirmed review ID before reporting success; preserve the form and release loading on every failure.
- Restart only the verified local server; repeat real HTTP multipart probes, remove probe files, run isolated Laravel and Flutter tests, and update the mobile app.

## Verified implementation

- Added content-signature MIME validation and explicit multipart part types, using the existing picker byte snapshots instead of reopening temporary Android paths.
- Added friendly backend/client upload errors, consistent format/size/count validation, upload spinner, duplicate-tap protection, loading recovery, and saved-review-ID confirmation.
- Preserved existing ownership/approval checks, transaction locks, idempotent retries, and failed-save file cleanup.
- Added backend launcher with process-only limits; removed the verified stale Artisan server and child, then started a persistent loopback PHP server with the same flags.
- Updated mobile startup guidance to use the backend launcher.

## Verification

- Flutter: `flutter test test/buyer_review_media_test.dart test/buyer_order_layout_test.dart`: 16 passed.
- Dart analysis of the two affected implementation files and their two test files: no issues.
- Laravel: `php vendor/bin/phpunit tests/Feature/MobileBuyerProductRatingsTest.php tests/Feature/MobileBuyerReviewDisplayTest.php`: 12 passed, 93 assertions. SQLite in memory and temporary/fake storage only.
- Regression tests reproduced the raw PHP-upload error before the fix and passed afterward.
- Backend tests cover star-only, written review, single/multiple photos, MP4 MIME sniffing, exact 5 MiB photo and 30 MiB MP4 boundaries, 6+2 counts, invalid/oversized files, approval/ownership, idempotency, rollback cleanup, legacy media, and product API attachment URLs.
- Flutter tests cover indexed multipart fields, authentication, boundary generation, actual MIME metadata, optional media/text, missing saved-review confirmation, unreadable/temp files, type/count/size validation, timeouts/network errors, repeated taps, spinner, draft recovery, and successful order refresh.
- Actual local PHP HTTP probes accepted 2 MiB + 168-byte and 5 MiB photo payloads and a 30 MiB MP4 payload with upload error 0. These transport fixtures test PHP parsing rather than playable video contents.
- Android debug APK built, installed, and launched on connected device PRR8NNCEHUU8YHX8 with API_BASE_URL=http://127.0.0.1:8000/api/mobile and USB forwarding.
- Read-only code review found no critical or important issues.

## Remaining manual verification

Use a real eligible purchase on the phone to select a gallery photo and a playable MP4, submit, then check their display/playback on the product page. Automated work did not submit any review using existing user orders. Production hosting/FPM/proxy settings were not changed. No credentials or real database migrations were changed.

## Files changed for this fix

Mobile:
- lib/features/buyer/data/services/buyer_order_service.dart
- lib/features/buyer/presentation/pages/buyer_item_rating_page.dart
- pubspec.yaml and pubspec.lock (existing cached MIME/HTTP-parser packages made direct dependencies)
- test/buyer_review_media_test.dart
- test/buyer_order_layout_test.dart (saved-review response fixture)
- scripts/run-local-mobile.ps1 (backend startup instruction)
- docs/local-mobile-development.md
- this diagnostic/verification report

Backend:
- app/Http/Controllers/Api/MobileBuyerOrderController.php (review validation only)
- scripts/serve-mobile.ps1
- docs/mobile-review-uploads.md
- tests/Feature/MobileBuyerProductRatingsTest.php
- tests/Feature/MobileBuyerReviewDisplayTest.php

## Combined-payload stress-test limitation

The 90 MiB combined live transport stress test did not complete within the probe timeouts. The final curl attempt sent 82,314,534 bytes in 150 seconds before timing out; a separate direct HTTP multipart probe also timed out awaiting a response. Neither created a review record. This is an unresolved large combined-upload performance check on the local PHP development server; do not claim that the entire 90 MiB live request has passed. Individual exact-limit 5 MiB photos and 30 MiB MP4 transfers did pass, as did isolated Laravel validation/storage at exact per-file limits with maximum attachment counts. The app retains its existing three-minute media timeout and now preserves the draft and supports safe idempotent retries on failure. Actual phone gallery selection, video playback, maximum combined-payload performance, and production proxy/FPM limits remain manual/environment-specific verification items. All temporary probe files were removed.
