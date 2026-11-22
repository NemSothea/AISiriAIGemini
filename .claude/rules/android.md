---
paths:
  - "android/**"
---

# Android (Kotlin, Compose, minSdk 29, compile/target 37)

- **Dependencies**: versions live in `android/gradle/libs.versions.toml`. They mirror Google's official AppFunctions sample, so don't bump `agp`, `kotlin`, `ksp` or `appfunctions` independently of each other.
- **AppFunctions**:
  - `BaseVoiceBankFunctionService` is abstract and `@RequiresApi(36)`. The KSP compiler generates the concrete `VoiceBankFunctionService` registered in `AndroidManifest.xml` and the `voicebank_function_service.xml` schema.
  - Don't hand-write either generated file. After changes, run `./gradlew :app:assembleDebug` and check the generated schema under `app/build/`.
- **Runs below API 36**: the app runs on API 29+, so never call AppFunctions code unguarded from shared paths. On older devices, deep links are the fallback.
- **Return types**:
  - Use `@AppFunctionSerializable(isDescribedByKDoc = true)` data classes. Document every field in KDoc.
  - Errors use `AppFunctionInvalidArgumentException` / `AppFunctionElementNotFoundException`, with a message telling the agent what to do next.
- **Money**: use `BigDecimal` with scale 2, `RoundingMode.HALF_UP`. Never use `Double` for amounts past the function boundary.
- **Biometrics**: `androidx.biometric` via `security/AuthGate.kt`. This requires a `FragmentActivity` host.
- **Deep links / source**:
  - `MainActivity` reads `EXTRA_SOURCE`; it defaults to `deeplink`.
  - Test with `adb shell am start -a android.intent.action.VIEW -d "voicebank://balance"`.
- **Agent testing (verified 2026-11-22 on the `VoiceBank_API37` emulator, Android 17, device PIN `1111`)**:
  - `adb shell cmd app_function ...` needs Android 17 (API 37). On the API 36 image it answers "No shell command implementation".
  - List: `adb shell cmd app_function list-app-functions --package com.example.voicebank`.
  - Execute: `adb shell cmd app_function execute-app-function --package com.example.voicebank --function 'com.example.voicebank.appfunctions.BaseVoiceBankFunctionService#getExchangeRate' --parameters '{}' --brief-yaml`.
  - `Double` parameters must be sent as decimals (`20.0`). An integer `20` is rejected with code 1001.
  - The adb tool prints `{}` for `PendingIntent` results and does not launch them. Use Google's AppFunctions Testing Agent (github.com/android/appfunctions, `agent/run_privileged.sh`) to run a function and follow it into the app.
  - Secure screens set screenshot blocking, so `adb exec-out screencap` is black there. Use `adb emu screenrecord screenshot <dir>` instead.
