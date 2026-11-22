---
name: add-bank-action
description: Add a new voice banking action (e.g. "recent transactions", "pay biller") to VoiceBank across iOS, Android and HarmonyOS — canonical action, deep link, assistant entry point, screen, voice parser, tests and PLAN.md. Use when the user asks to add or extend a voice command or assistant action.
argument-hint: "<action description>"
---

# Add a bank action to all three platforms

Action to add: $ARGUMENTS

## 1. Decide the tier first (PLAN.md §1). Stop and ask if it's unclear.
- **Excluded**: never via voice. Refuse and explain. Covers new payees, limit/PIN/password changes, loans, full account/card numbers.
- **Tier 1, public**: the assistant may return data.
- **Tier 2, auth to view**: the assistant only opens the app; biometric gate.
- **Tier 3, voice prepares, app confirms**: draft → review → biometric + PIN.

Choose:
- A camelCase action name, e.g. `recentTransactions`.
- A deep-link host, e.g. `transactions`.
- An audit name.

These three must be identical on every platform.

## 2. Canonical action + deep link
- iOS: `ios/VoiceBank/App/BankAction.swift`. Add an enum case and update `name`, `tier` and `init?(url:)`.
- Android: `android/.../BankAction.kt`. Add a sealed subclass and update `toUri()` and `fromUri()`.
- Harmony: `harmony/.../services/Router.ets`. Update the `Route` enum, `actionName`, `tierOf`, the `openUri` route map, and `SECURE_ROUTES` if the action is Tier 2/3.
- Update the deep-link doc comments: `voicebank://qr | ...` appears in all three files plus the AndroidManifest comment.

## 3. Screen
- iOS: `Views/`, under `PublicViews` or `SecureViews`. Add the case to the navigation destination switch in `HomeView`.
- Android: `ui/`, under `PublicScreens.kt` or `SecureScreens.kt`. Add it to the `Root.kt` routing.
- Harmony: `pages/`, under `PublicPages.ets` or `SecurePages.ets`. Add it to the `Index.ets` NavDestination builder.
- Tier 2/3 screens must go through `AuthGate` before showing data. Harmony also needs privacy-window handling, like the existing secure pages.
- If new data is needed, extend `mock_bank.json` and the models (see `.claude/rules/cross-platform-parity.md`).

## 4. Assistant entry point
Follow `.claude/rules/assistant-entry-points.md`, and copy the closest existing action of the same tier.
- iOS: a new `AppIntent` in `Intents/BankIntents.swift`, plus an `AppShortcut` with phrases containing `\(.applicationName)` in `VoiceBankShortcuts.swift`.
- Android: a new `@AppFunctionDeclaration` in `BaseVoiceBankFunctionService.kt`. Give it a full KDoc and the next unused `PendingIntent` request code.
- Harmony: a new file `intents/<Name>Intent.ets` with an `@InsightIntentEntry`. Write the `llmDescription` and `keywords`.

## 5. In-app voice parser + tests
- Update `VoiceCommandParser.swift` and `VoiceCommandParser.kt` with the same keywords in the same position. Check that the new rule doesn't steal phrases from an earlier rule.
- Add the same test cases to `VoiceCommandParserTests.swift` and `VoiceCommandParserTest.kt`.

## 6. Docs
- `PLAN.md` §4: add a row to the canonical actions table.
- `PLAN.md` §1: update the feature tiers if needed.
- `harmony/README.md`: add a row to the Xiaoyi intents table.
- `README.md`: only if the build or test commands change.

## 7. Verify
- Run the `verify-demo` skill, or at least:
  ```
  cd android && ./gradlew :app:testDebugUnitTest :app:assembleDebug
  cd ios && xcodegen generate
  xcodebuild test -project ios/VoiceBank.xcodeproj -scheme VoiceBank -destination 'platform=iOS Simulator,name=<sim>'
  ```
- Run the `security-check` skill on the new entry points.
- Harmony can't be built here. Say so in the summary, and list any `[uncertain]` markers you added.
