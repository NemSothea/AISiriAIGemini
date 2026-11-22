# Android real-device test guide

Use this to repeat the Android demo checks on a real phone. It records what was already verified on an emulator on 2026-11-22, what still needs a real device, and the exact steps for each.

## Status on 2026-11-22

Verified on the `VoiceBank_API37` emulator (Android 17, API 37):

- The app builds and all 6 parser unit tests pass.
- Deep links open the right screens (QR, rates, balance, freeze, transfer).
- adb lists all 7 AppFunctions and runs them.
- Rates and payee lookup return data. Balance and card freeze return an empty result to the caller.
- Google's AppFunctions Testing Agent ran `requestCardFreeze` and VoiceBank opened on the locked Card Controls screen.
- The transfer flow completed: review, device PIN, demo PIN `1234`, then "Transfer sent (demo)".
- The app uses the stable `androidx.appfunctions` `1.0.0` library. The build, unit tests and adb agent calls were rerun after the upgrade from `1.0.0-rc01`.

Not verified yet:

- Anything on a real phone.
- Fingerprint login. The emulator had no fingerprint, so the device PIN was used instead.
- The in-app mic with a real voice.
- The balance screen after login.
- `prepareTransfer` started from the Testing Agent (it was started from a deep link).
- The Testing Agent's chat mode (needs a Gemini API key).
- The real Gemini assistant (needs Google's developer preview).

## What to bring

- An Android phone. Android 10 or later runs the app. Android 16 or later is needed for AppFunctions. Android 17 is needed for the `adb shell cmd app_function` commands.
- A USB cable and a computer with the Android SDK (`adb`) and this repository.
- A screen lock and at least one fingerprint enrolled on the phone.
- For chat mode only: a Gemini API key from https://aistudio.google.com/apikey. Use a personal Google account, not a bank account.

## 1. Prepare the phone

1. Open Settings ▸ About phone and tap **Build number** seven times to turn on Developer options.
2. Open Settings ▸ System ▸ Developer options and turn on **USB debugging**.
3. Connect the cable and accept the "Allow USB debugging" prompt.
4. Check the connection and write down the Android version:
   ```
   adb devices
   adb shell getprop ro.build.version.release
   adb shell getprop ro.build.version.sdk
   ```

## 2. Build and install

```
cd android
./gradlew :app:testDebugUnitTest :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Expect `BUILD SUCCESSFUL`, 6 tests passed, and `Success` from the install.

## 3. Touch test (any Android 10+ phone)

Open VoiceBank and tap each tile on the home screen.

| # | Action | Expected |
|---|---|---|
| T1 | Receive (KHQR) | QR opens with no login. Red text says "Sample QR — not a valid KHQR". |
| T2 | Exchange Rates | Rates open with no login. |
| T3 | ATM & Branches | Branch list opens with no login. |
| T4 | Balance | Fingerprint prompt appears before any balance is visible. |
| T5 | Card Controls | Fingerprint prompt, then the card shows as Active with a Freeze button. |
| T6 | Transfer, pick Dara, enter 20, Review | Review shows Dara, $20.00 and an expiry countdown. |
| T7 | Confirm with biometrics + PIN, then PIN `1234` | "Transfer sent (demo)" with a reference. |
| T8 | Transfer 500 to Dara, Review | "Voice transfers are limited to USD 100 in this demo." |
| T9 | Open Balance, press Home, return to the app | The screen is locked again and needs login. |
| T10 | Take a screenshot on the Balance screen | The screenshot is blocked or black. |
| T11 | Open the audit log from the home screen | Every action above is listed with source `touch`. No balances are shown. |

## 4. Deep-link test (stands in for an assistant)

Run each command with the phone unlocked.

```
adb shell am start -a android.intent.action.VIEW -d "voicebank://qr"
adb shell am start -a android.intent.action.VIEW -d "voicebank://rates"
adb shell am start -a android.intent.action.VIEW -d "voicebank://balance"
adb shell am start -a android.intent.action.VIEW -d "voicebank://freeze"
adb shell am start -a android.intent.action.VIEW -d "'voicebank://transfer?payee=Dara&amount=20'"
adb shell am start -a android.intent.action.VIEW -d "'voicebank://transfer?payee=Sokha&amount=500'"
adb shell am start -a android.intent.action.VIEW -d "voicebank://bogus"
```

| # | Link | Expected |
|---|---|---|
| L1 | `qr` | QR screen, no login. |
| L2 | `rates` | Rates screen, no login. |
| L3 | `balance` | Locked until fingerprint. |
| L4 | `freeze` | Locked until fingerprint. The card is not frozen until you tap Freeze. |
| L5 | `transfer` Dara 20 | Form prefilled with Dara and 20. |
| L6 | `transfer` Sokha 500, sent while L5 is still open | Form changes to Sokha and 500. Review shows the 100 USD limit error. |
| L7 | `bogus` | Nothing opens. The audit log shows `unknown` / `rejected`. |

L6 checks a bug fixed on 2026-11-22: the form used to keep the old payee and amount.

## 5. In-app voice test

1. Tap the voice button on the home screen and allow the microphone.
2. Say each phrase clearly in English.

| # | Phrase | Expected |
|---|---|---|
| V1 | "Show my QR" | QR screen. |
| V2 | "What's the exchange rate" | Rates screen. |
| V3 | "Check my balance" | Locked balance screen. |
| V4 | "Freeze my card" | Locked card screen. |
| V5 | "Send 20 dollars to Dara" | Transfer form with Dara and 20. |
| V6 | "Send 30 to Bopha" | Transfer form with 30 and no payee. |
| V7 | "What's the weather" | Not understood; nothing opens. |

Speech recognition runs on the device. If the phone has no on-device English speech model, this test can fail for that reason; note the error text. On the `VoiceBank_API37` emulator the dialog showed "Speech recognition error (13)" as soon as it opened, so voice has to be tested on a real phone.

Screenshots of each screen from the emulator are in `docs/screenshots/`.

## 6. AppFunctions by adb (Android 17 phones only)

On Android 16 or older, `adb shell cmd app_function help` answers "No shell command implementation". Skip to section 7.

List the functions:

```
adb shell cmd app_function list-app-functions --package com.example.voicebank
```

Expect 7 functions: `showReceiveQr`, `getExchangeRate`, `findNearestBranches`, `openBalance`, `requestCardFreeze`, `findPayee`, `prepareTransfer`.

Run them:

```
P=com.example.voicebank
F=com.example.voicebank.appfunctions.BaseVoiceBankFunctionService
adb shell cmd app_function execute-app-function --package $P --function "'$F#getExchangeRate'" --parameters "'{}'" --brief-yaml
adb shell cmd app_function execute-app-function --package $P --function "'$F#findPayee'" --parameters "'{\"query\":\"Dara\"}'" --brief-yaml
adb shell cmd app_function execute-app-function --package $P --function "'$F#findPayee'" --parameters "'{\"query\":\"Bopha\"}'"
adb shell cmd app_function execute-app-function --package $P --function "'$F#openBalance'" --parameters "'{}'"
adb shell cmd app_function execute-app-function --package $P --function "'$F#prepareTransfer'" --parameters "'{\"payeeId\":\"p-dara\",\"amountUsd\":500.0}'"
adb shell cmd app_function execute-app-function --package $P --function "'$F#prepareTransfer'" --parameters "'{\"payeeId\":\"p-nobody\",\"amountUsd\":20.0}'"
```

| # | Call | Expected |
|---|---|---|
| A1 | `getExchangeRate` | Three demo rates, including USD/KHR 4080 / 4110. |
| A2 | `findPayee` Dara | `payeeId: p-dara`, `name: Dara`. No account number. |
| A3 | `findPayee` Bopha | Error: No saved payee named "Bopha". |
| A4 | `openBalance` | `{}`. No balance in the output. |
| A5 | `prepareTransfer` 500.0 | Error: Amount must be between 0 and 100 USD. |
| A6 | `prepareTransfer` unknown payee | Error: Unknown payeeId. Call findPayee first. |

Notes:

- Send amounts as decimals (`20.0`). The adb tool rejects `20` with code 1001.
- The adb tool prints `{}` for functions that open the app and does not open it. Use the Testing Agent for that.

## 7. AppFunctions Testing Agent (Android 16+)

This is Google's open-source stand-in for Gemini. It was only tried on the Android 17 emulator. Its launch script uses adb shell commands that may not work on a retail phone; if it fails, note the error.

```
git clone --depth 1 https://github.com/android/appfunctions
cd appfunctions/agent
./run_privileged.sh --build
```

Manual mode (no API key):

1. In the **Debug** tab, search for "VoiceBank" and select it.
2. Expand a function and tap **Run**.

| # | Function | Expected |
|---|---|---|
| G1 | `getExchangeRate` | The rates are shown in the agent. |
| G2 | `requestCardFreeze` | VoiceBank opens on the locked Card Controls screen. After login the card is still Active. |
| G3 | `openBalance` | VoiceBank opens on the locked Balance screen. The agent shows no balance. |
| G4 | `prepareTransfer` with `p-dara` and `20.0` | VoiceBank opens the transfer form with Dara and 20. |

Chat mode (needs the Gemini API key):

1. Open the **Settings** tab and paste the key.
2. Open the **Agent Demo** tab and type each prompt.

| # | Prompt | Expected |
|---|---|---|
| C1 | "What is the VoiceBank exchange rate?" | The agent answers with the demo rate. |
| C2 | "Check my balance in VoiceBank" | VoiceBank opens locked. The agent never states an amount. |
| C3 | "Send 20 dollars to Dara with VoiceBank" | The agent calls `findPayee`, then `prepareTransfer`. VoiceBank opens the form. The agent does not say the transfer is complete. |
| C4 | "Send 500 dollars to Dara with VoiceBank" | The agent reports the 100 USD limit. |
| C5 | "Send 20 dollars to Bopha with VoiceBank" | The agent says there is no saved payee and does not offer to add one. |

Watch C3 closely: if the model sends `20` instead of `20.0`, the call may fail. Record what happens.

On the free API tier Google may use prompts to improve its products. Use mock data only and tell the risk team.

## 8. Real Gemini (not possible yet)

Testing with the real Gemini app needs Google's Connected Apps Platform developer preview. Apply at https://connected.google.com/console/help/?apply.

The application needs:

- a Google Connected Console account and a Play Console account, with the app in the same account
- a signed release `.aab`
- a 512x512 icon and a description
- at least three capabilities and three example prompts
- a privacy policy URL and a terms URL
- testers with `@gmail.com` accounts, signed in to the Gemini app on an Android phone or tablet

Google's docs do not say whether an emulator works with the real Gemini app.

## Results to record

Fill this in at the company.

| Item | Value |
|---|---|
| Date | |
| Phone model | |
| Android version / API level | |
| Fingerprint enrolled (yes/no) | |
| Build and unit tests | |
| Touch test T1–T11 (failed items) | |
| Deep-link test L1–L7 (failed items) | |
| Voice test V1–V7 (failed items) | |
| adb AppFunctions A1–A6 (failed items, or "skipped: below Android 17") | |
| Testing Agent G1–G4 (failed items) | |
| Chat mode C1–C5 (failed items, or "skipped: no key") | |
| Notes and error texts | |

## Open decisions

- **Fingerprint or device PIN:** the login prompt accepts the device PIN when no fingerprint is used. A transfer can pass with device PIN plus demo PIN. Decide whether that is acceptable.
- **Account ownership:** who registers the Play Console, Connected Console and API key accounts.
