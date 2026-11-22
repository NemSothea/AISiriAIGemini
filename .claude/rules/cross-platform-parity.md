---
paths:
  - "ios/VoiceBank/App/BankAction.swift"
  - "android/app/src/main/kotlin/com/example/voicebank/BankAction.kt"
  - "harmony/entry/src/main/ets/services/Router.ets"
  - "**/VoiceCommandParser*"
  - "**/mock_bank.json"
  - "ios/VoiceBank/Model/**"
  - "android/app/src/main/kotlin/com/example/voicebank/model/**"
  - "harmony/entry/src/main/ets/model/**"
---

# Cross-platform parity

iOS, Android and HarmonyOS implement the same app. A change to any file here almost always needs the same change on the other two platforms, in the same session. If one platform can't be done, say so explicitly. Never leave it silently out of sync.

## Must stay identical
- **Action names**: `showQR`, `getRates`, `findBranch`, `checkBalance`, `freezeCard`, `prepareTransfer`, plus the tier of each one.
- **Deep link hosts and params**: `qr | rates | branches | balance | freeze | transfer?payee=&amount=`.
- **`mock_bank.json`**: byte-identical in all 3 locations. Edit the iOS copy, then:
  ```
  cp ios/VoiceBank/Resources/mock_bank.json android/app/src/main/assets/mock_bank.json
  cp ios/VoiceBank/Resources/mock_bank.json harmony/entry/src/main/resources/rawfile/mock_bank.json
  ```
  Model decoders on all 3 platforms must accept any new field.
- **Transfer rules**:
  - Cap 100 USD: `transferCap` / `TRANSFER_CAP` / `TRANSFER_CAP`.
  - Draft lifetime 5 minutes, single use, saved payees only.
  - Demo PIN `1234`.
- **Error strings** shown to the user, e.g. "This transfer request expired. Start again."
- **`VoiceCommandParser`**: same keyword rules in the same order. Order matters: QR is checked before transfer, so "pay me" means receive. Payee matches on whole words only.
- **Parser tests**: `ios/VoiceBankTests/VoiceCommandParserTests.swift` and `android/app/src/test/.../VoiceCommandParserTest.kt` contain the same cases. Add each new case to both. HarmonyOS has no parser yet (PLAN.md phase 5).

## Domain model
`Account`, `Payee`, `TransferDraft`, `ExchangeRate`, `Branch`, `Card`, `AuditEvent` (PLAN.md §4). Keep field names aligned across platforms. The audit log never stores balances or amounts.
