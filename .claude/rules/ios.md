---
paths:
  - "ios/**"
---

# iOS (Swift 6, SwiftUI, iOS 18+)

- **XcodeGen**: `ios/project.yml` is the project source; `*.xcodeproj` is gitignored.
  - After adding, removing or moving files, run `cd ios && xcodegen generate`.
  - Put Info.plist keys, URL schemes and usage strings in `project.yml` (`info.properties`), not by hand in Info.plist.
- **Concurrency**: Swift 6 strict concurrency.
  - `AppRouter`, `BankStore` and `AuditLog` are `@MainActor @Observable`.
  - Intent `perform()` is `@MainActor`. Intents get shared objects via `@Dependency`, not singletons.
- **Tests**: Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest.
  - Single test: `-only-testing:VoiceBankTests/VoiceCommandParserTests/publicCommands()`.
- **Siri phrases** (`VoiceBankShortcuts.swift`):
  - English only. Every phrase must contain `\(.applicationName)`.
  - Phrase parameters may only be entities/enums, so the amount is never in a phrase; Siri asks for it.
- **Saved payees**: resolve through `PayeeEntity` (`AppEntity` + query over saved payees). Never accept free-text payee names in intents.
- **Face ID**: `LocalAuthentication` via `AuthGate`. Test in the simulator with Features ▸ Face ID ▸ Enrolled / Matching Face.
- **Deep links** in the simulator: `xcrun simctl openurl booted "voicebank://transfer?payee=Dara&amount=20"`.
