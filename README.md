# VoiceBank — voice banking demo

A demo banking app driven by each platform's native assistant: Siri on iOS, Gemini on Android and Xiaoyi on HarmonyOS. It also has an in-app voice button that works on-device. It uses mock data only. See [PLAN.md](PLAN.md) for the scope, the security tiers and the roadmap.

| Folder | Platform | Assistant hook | Build |
|---|---|---|---|
| `ios/` | iOS 18+ (Swift, SwiftUI) | App Intents (Siri) | `cd ios && xcodegen generate`, then open `VoiceBank.xcodeproj` |
| `android/` | Android 10+ (Kotlin, Compose) | AppFunctions (Gemini, Android 16+) | `cd android && ./gradlew :app:assembleDebug` |
| `harmony/` | HarmonyOS NEXT, API 20+ (ArkTS) | InsightIntents (Xiaoyi) | Open in DevEco Studio. Not compiled yet; see `harmony/README.md` |

Tests:
- iOS: `xcodebuild test -project ios/VoiceBank.xcodeproj -scheme VoiceBank -destination 'platform=iOS Simulator,id=<sim-id>'`
- Android: `cd android && ./gradlew :app:testDebugUnitTest`

Security model: voice only starts an action. Balance and card screens need biometrics, transfers need biometrics plus a PIN, and assistants never receive account data.
