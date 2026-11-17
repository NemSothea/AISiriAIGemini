# VoiceBank — HarmonyOS NEXT (ArkTS)

This is the HarmonyOS version of the demo app, using Xiaoyi InsightIntents. Its behaviour matches `ios/` and `android/`. See `../PLAN.md` §3.3 for the plan.

> **Not compiled yet.** This code was written without DevEco Studio. Expect to fix a few ArkTS compiler errors on the first build. API names follow a community InsightIntent sample (API 20+). Check every item marked `[uncertain]` against Huawei's official docs.

## Requirements
- DevEco Studio with HarmonyOS SDK 6.0 (API 20) or later. InsightIntent decorators need API 20+.
- A HarmonyOS NEXT phone (China), signed in with a Huawei ID that has developer mode on.
- The phone needs a lock screen and biometrics set up. There is no way around the login screens.

## Build and run
1. Open the `harmony/` folder in DevEco Studio and let it sync.
2. Go to File ▸ Project Structure ▸ Signing Configs and tick **Automatically generate signature**.
3. Run on the device.

## Deep links
```
hdc shell aa start -A ohos.want.action.viewData -U "voicebank://transfer?payee=Dara&amount=20"
```
Routes: `qr | rates | branches | balance | freeze | transfer?payee=&amount=`

## Xiaoyi intents
| Intent | Tier | Mode | Behaviour |
|---|---|---|---|
| ShowReceiveQr | Public | Foreground | Opens the QR screen |
| GetExchangeRate | Public | Background | Returns the USD/KHR demo rate as text |
| FindNearestBranch | Public | Foreground | Opens ATM & branches |
| CheckBalance | Biometric | Foreground | Opens the app only; never returns the balance |
| FreezeCard | Biometric | Foreground | Opens card controls; the freeze is confirmed in the app |
| PrepareTransfer | Biometric + PIN | Foreground | Saved payee, max 100 USD; opens the review screen |

Xiaoyi can't use these intents until Huawei's Intents Kit acceptance review approves them. Developers can't fully test intent sharing on their own; you request acceptance through Huawei's Intents Kit contact.

## Security behaviour (same as iOS and Android)
- **Login:** biometric or lock-screen PIN through `userAuth` (ATL3). Transfers also need the demo PIN `1234`.
- **Screenshot blocking:** window privacy mode is on while secure screens are shown, so they can't be screenshotted or seen in recents.
- **Background lock:** going to the background closes any open secure screen, so it needs login again on return.
- **Audit log:** every action is recorded in app-private Preferences. Balances are never stored there.
