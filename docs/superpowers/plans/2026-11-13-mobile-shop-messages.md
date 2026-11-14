# Mobile shop messages implementation plan

**Goal:** Connect buyer mobile Messages and product Chat to the existing web ShopChat conversations.

**Architecture:** Add Sanctum-protected mobile endpoints using the existing ShopChat controller and tables. Guard approved, verified marketplace accounts and validate seller identity for opening a conversation. Add a Flutter service, inbox, and thread with foreground-only polling, error recovery, and message deduplication. No database migrations or real-user test messages.

**Tech Stack:** Flutter, HTTP, Laravel, Sanctum, existing ShopChat models.

- [x] Test mobile conversation ownership, web/mobile shared history, read status, sending, and invalid recipients with isolated SQLite fixtures.
- [x] Expose guarded mobile chat endpoints without changing the web response shape.
- [x] Implement and test inbox/thread loading, polling, sending, failure recovery and seller conversation opening.
- [x] Connect Home, Account, Settings and product Chat to the native pages.
- [x] Run relevant backend and Flutter checks, build and install on connected phone.

Validation: 4 isolated backend tests (39 assertions), 21 Flutter tests, focused Home shortcut retest, clean Dart analysis, successful Android build/install. Reviewer retry finding fixed with persisted client UUID uniqueness; schema addition applied only to verified local MySQL. No real conversations received test messages.
