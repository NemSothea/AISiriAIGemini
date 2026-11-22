---
name: verify-demo
description: Build, unit-test and smoke-test VoiceBank on the iOS simulator and Android emulator, firing the D1–D5 demo deep links. Use when asked to verify, test, run or check that the demo still works after a change.
argument-hint: "[ios|android|all]"
---

# Verify the VoiceBank demo

Platform: $ARGUMENTS (empty = all). HarmonyOS can't be built on this machine (no DevEco Studio), so always say that it was skipped.

## Android
1. Run unit tests and the build:
   ```
   cd android && ./gradlew :app:testDebugUnitTest :app:assembleDebug
   ```
2. Check the AppFunctions schema was generated:
   ```
   find android/app/build -name 'voicebank_function_service*.xml'
   ```
   Every `@AppFunctionDeclaration` in `BaseVoiceBankFunctionService.kt` should appear in it.
3. If a device or emulator is running (`adb devices`):
   - Install: `adb install -r android/app/build/outputs/apk/debug/app-debug.apk`
   - Fire each deep link (see "D1–D5 deep links" below):
     ```
     adb shell am start -a android.intent.action.VIEW -d "<url>"
     ```
   - Optionally run `adb shell cmd app_function list-app-functions`. Some images don't support it; report that, it isn't a failure.

## iOS
1. Generate the project and pick a simulator:
   ```
   cd ios && xcodegen generate
   xcrun simctl list devices available | grep iPhone
   ```
2. Run tests:
   ```
   xcodebuild test -project ios/VoiceBank.xcodeproj -scheme VoiceBank -destination 'platform=iOS Simulator,id=<sim-id>'
   ```
3. Smoke test the deep links:
   - Boot the simulator and build/install the app.
   - Fire each deep link (see "D1–D5 deep links" below):
     ```
     xcrun simctl openurl booted "<url>"
     ```

## D1–D5 deep links
| Demo | URL | Expect |
|---|---|---|
| D1 | `voicebank://qr` | QR screen, no auth |
| D2 | `voicebank://rates` | rates screen, no auth |
| D3 | `voicebank://balance` | biometric prompt **before** any balance is visible |
| D4 | `voicebank://freeze` | biometric prompt; freeze needs in-app confirmation |
| D5 | `voicebank://transfer?payee=Dara&amount=20` | review screen prefilled; biometric + PIN `1234` to submit |

Negative checks:
- `voicebank://transfer?payee=Dara&amount=500`: draft creation fails with the over-cap error (100 USD).
- `voicebank://bogus`: rejected and audited as `unknown`.

## Report
For each platform, list:
- tests passed/failed (with the failing test name and its shortest assertion line)
- build result
- which deep links were exercised

Biometric and PIN prompts need a person to confirm on screen. List those as "needs manual check" unless you actually saw them. Never claim a step passed if you didn't run it.
