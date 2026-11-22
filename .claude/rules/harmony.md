---
paths:
  - "harmony/**"
---

# HarmonyOS NEXT (ArkTS, API 20+)

- **Never compiled**: there is no DevEco Studio on this Mac. You can't verify anything here by building.
  - Keep the code conservative and close to the existing patterns.
  - Mark any API you aren't sure of with an `// [uncertain] ...` comment explaining what to verify. Never present guessed APIs as confirmed.
- **ArkTS strict rules** (stricter than TypeScript):
  - No `any`/`unknown`, no object literals without a declared type, no destructuring, no index-signature objects.
  - Explicit types on `Map`, arrays and lambdas, matching the style in `Router.ets`.
- **State management**: V2 decorators (`@ObservedV2`, `@Trace`, `@ComponentV2`, `@Local`, `@Param`). Don't mix them with V1 (`@Observed`, `@State`, `@Prop`) in the same component.
- **Navigation**: one `NavPathStack` in `Router.shared()`. Open screens with `Router.shared().open(route, source, args)`.
  - Secure routes (`BALANCE`, `CARD`, `TRANSFER`) are listed in `SECURE_ROUTES`. `dropSecureScreens()` clears them on background.
- **Intents**:
  - One `@InsightIntentEntry` class per file in `entry/src/main/ets/intents/`. Return results via `ok()` / `fail()` from `IntentResults.ets`.
  - Audit source is `xiaoyi`.
  - Xiaoyi is Chinese-first. Put English and Chinese terms in `keywords` where useful.
- **Security**:
  - Auth uses `userAuth` at ATL3 in `security/AuthGate.ets`.
  - Window privacy mode must be on while a secure page is visible.
  - The audit log lives in Preferences (`voicebank_audit`) and never holds balances.
- **Resources and pages**:
  - Strings go in `resources/base/element/string.json`.
  - `main_pages.json` lists only `pages/Index` (`@Entry`). Other screens are `NavDestination`s pushed through `Router`. Don't add them as new `@Entry` pages.
