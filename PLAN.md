# PLAN — Voice Banking Demo (Siri · Gemini · Huawei)

_Last updated: 2026-11-17. Supersedes the VoiceTasks concept. Assistant APIs and regulations change fast; re-check cited sources before each phase. **[uncertain]** = not confirmed in official docs; **[check]** = must be confirmed with the bank's risk/compliance team._

---

## 1. WHAT — Demo scope

Internal proof-of-concept for the bank: customers start everyday banking tasks by voice through each platform's native assistant. **Voice starts the action; anything touching money or account data finishes inside the app behind biometric auth.**

Working app name: **"VoiceBank"** (neutral demo name; no real bank branding).

### Feature tiers

| Tier | Rule | Features |
|------|------|----------|
| **1 — Public / receive-only** | Runs from voice; no auth | Find nearest ATM/branch · USD↔KHR exchange rate · Show my KHQR to receive · Open feature (bill pay, transfer) · Call support |
| **2 — Auth to view** | Voice opens app → biometric → result shown **in app only**, never spoken or shown on lock screen | Check balance · Recent transactions · Freeze card · Bill due date |
| **3 — Voice prepares, app confirms** | Voice fills a draft → app opens → user reviews → biometric + PIN → submit | Transfer to **saved** payee · Pay **saved** biller |
| **Excluded** | Never via voice | New payees, limit/PIN/password changes, loan applications, reading full account/card numbers |

### Demo set (5 commands, all 3 platforms)

| # | Command | Tier |
|---|---------|------|
| D1 | "Show my VoiceBank QR" | 1 |
| D2 | "VoiceBank exchange rate" | 1 |
| D3 | "Check my balance in VoiceBank" | 2 |
| D4 | "Freeze my card in VoiceBank" | 2 |
| D5 | "Send 20 dollars to Dara with VoiceBank" | 3 (headline) |

---

## 2. WHY

- **For the bank:** shows the bank is ready for the agentic-OS shift (Apple App Intents, Android AppFunctions, Huawei Intents Kit). Apps that expose no actions become invisible to system assistants.
- **For customers:** faster everyday tasks (receive via KHQR, check rates, freeze a lost card) with no new security model to learn — same biometric/PIN as today.
- **For risk teams:** the tier model shows voice convenience **without** weakening transaction security; it's a reference design for a production decision.
- **Platform contrast it surfaces:** Siri = declared phrases + auth policy; Gemini = LLM agent choosing functions by KDoc; Huawei = China-centric intent framework vs. Cambodia device reality.

---

## 3. HOW — Per platform

### 3.1 iOS → Siri (Swift, App Intents)

- **Mechanism:** `AppIntent` per demo command, `AppShortcutsProvider` for zero-setup phrases, `AppEntity` for saved payees ("Dara"). Assistant schemas for Apple Intelligence where a finance domain exists **[uncertain]**.
- **Security hooks:**
  - Tier 2–3 intents: `authenticationPolicy = .requiresAuthentication` (device must be unlocked) **and** `openAppWhenRun` / open-app intent so data renders in-app after Face ID (LocalAuthentication).
  - Intent dialogs for Tier 2–3 contain **no amounts or balances**.
- **Min OS:** iOS 18.0 (current scaffold target).
- **Limits:**
  - Siri has **no Khmer** — English only.
  - Reports say Apple may restrict banking apps from new Siri AI features at launch **[uncertain]**.
  - EU/China Apple Intelligence gaps **[uncertain]**.
- **Flow (D5):**
  ```
  "Send 20 dollars to Dara with VoiceBank"
     │ Siri resolves payee entity + amount
     ▼
  PrepareTransferIntent ──► TransferDraft(payee, 20 USD) stored locally
     │ opens app
     ▼
  Review screen ──► Face ID + PIN ──► Mock API /transfer ──► receipt + audit log
  ```
- **Effort:** M. **Risks:** banking restriction on Siri AI; English-only; phrase brittleness with Khmer names.

### 3.2 Android → Gemini (Kotlin, AppFunctions)

- **Mechanism:**
  - `@AppFunctionDeclaration` functions per demo command, plus `findPayee(query)` for payee lookup.
  - Gemini access needs **Connected Apps Platform developer preview** + Android 16 (API 36)+. Experimental API.
- **Security hooks:**
  - AppFunctions execute **without UI**. Tier 2–3 functions MUST NOT return balances or transaction data. They return only "opened app for verification" and launch an Activity that requires BiometricPrompt.
  - Tier 1 functions may return data (rates, branch list).
- **Fallback:** deep links `voicebank://qr|rates|balance|freeze|transfer?payee=&amount=` for pre-Android-16 devices and for use before preview approval.
- **Min SDK:** app API 29+. AppFunctions active only on API 36+.
- **Limits:**
  - Gemini Khmer voice support **[uncertain — test]**.
  - Only preview testers can use it until published.
- **Effort:** M. **Risks:** preview approval delay; API changes; payee-name resolution by LLM.

### 3.3 Huawei (ArkTS / Android)

- **Reality for Cambodia:**
  - Xiaoyi Intents Kit appears **China-centric** (Chinese voice, Huawei acceptance process, HarmonyOS 5.0.5+).
  - Huawei phones sold in Cambodia likely run international EMUI / HarmonyOS 4.x (AOSP-based, no GMS). They have no Gemini and no known third-party Celia API **[uncertain]**.
- **Decision (2026-11-17): target a China HarmonyOS NEXT phone.** Build a native ArkTS app + Intents Kit (Xiaoyi Dialogue entry), HarmonyOS 5.0.5+, DevEco Studio 5.0.5+. Expect the Huawei acceptance step for intent sharing and a Chinese-only Xiaoyi voice **[uncertain whether English utterances work]**.
  - Cambodian-market Huawei devices (no GMS) remain covered only by the in-app voice fallback (§5, Approach 3).
- **Effort:** M (fallback) / L (Intents Kit). **Risks:** no native assistant on target devices; HMS speech service availability **[uncertain]**.

---

## 4. Shared architecture

```
 Siri / Gemini / Xiaoyi / In-app mic
              │  (action name + params only)
              ▼
     VoiceAction router  ──► Tier check ──► Auth gate (biometric / +PIN)
              │                                   │
              ▼                                   ▼
       Action layer (per platform) ───────► Mock Bank API
              │                                   │
              └──────── Audit log (local + API) ◄─┘
```

- **Domain model:** `Account(id, maskedNumber, currency, balance)`, `Payee(id, name, bank, maskedAccount)`, `TransferDraft(payeeId, amount, currency, expiresAt)`, `ExchangeRate(pair, buy, sell, asOf)`, `Branch(name, lat, lng, type)`, `Card(id, masked, frozen)`, `AuditEvent(source, action, result, timestamp)`.
- **Canonical actions:**

  | Action | Tier | iOS intent | Android function | Deep link |
  |--------|------|-----------|------------------|-----------|
  | showQR | 1 | `ShowQRIntent` | `showReceiveQr()` | `voicebank://qr` |
  | getRates | 1 | `ExchangeRateIntent` | `getExchangeRate()` | `voicebank://rates` |
  | checkBalance | 2 | `CheckBalanceIntent` | `openBalance()` | `voicebank://balance` |
  | freezeCard | 2 | `FreezeCardIntent` | `requestCardFreeze()` | `voicebank://freeze` |
  | prepareTransfer | 3 | `PrepareTransferIntent` | `prepareTransfer(payee, amount)` | `voicebank://transfer?payee=&amount=` |
  | findPayee | — | `PayeeEntity` query | `findPayee(query)` | — |

- **Mock Bank API:** local JSON fixtures first. Optional tiny HTTP mock later. **No connection to the bank's core banking or real customer data.**
- **Transfer draft rules:** saved payees only, amount cap (e.g. 100 USD in demo), 5-minute expiry, single use.
- **KHQR:** demo shows a **static sample** QR image. Real KHQR/Bakong generation needs NBC/Bakong SDK access **[check]**.

---

## 5. Build approaches

| Approach | Description | Effort | Demo impact | Reach in Cambodia | Risk |
|----------|-------------|--------|-------------|-------------------|------|
| 1. Deep-link only | Assistant opens screen; user finishes by touch | S | Low | All | Low |
| 2. Native assistant integration | App Intents + AppFunctions (+ Intents Kit) with tier gating | M–L | High | iPhone (EN), Android 16 + Gemini preview | Med–High |
| 3. In-app voice fallback | Mic → on-device STT → intent parse → action layer. Optional LLM parse sends **utterance text only**, never account data | M | Medium | All incl. Huawei; Khmer possible | Med (compliance) |
| **4. Hybrid (2 + 3)** | Native where available, fallback everywhere | L | **Highest** | **All** | Med |

**Recommendation: Approach 4.** Use rule-based parsing first for the 5 demo commands. Add an LLM parser only after compliance sign-off.

---

## 6. Security & compliance (gate before any pilot)

1. **Assistant data flow:** utterances go to Apple/Google/Huawei servers. The bank's risk/compliance team must approve against NBC technology-risk requirements **[check exact regulation]**.
2. **No account data in assistant responses** for Tier 2–3. Data only rendered in-app after auth.
3. **Auth:** biometric for Tier 2; biometric + PIN for Tier 3. Re-auth on every voice-started Tier 3 action.
4. **LLM fallback:** utterance text only, no PII/account data. Prefer on-device. Cloud LLM needs written approval **[check]**.
5. **Audit log:** every voice-started action (source assistant, action, tier, result, timestamp).
6. **Demo data only:** mock accounts, fictional payees ("Dara", "Sokha"), sample QR.
7. **Branding/legal:** demo stays unbranded; any real bank name/logo only with internal approval **[check]**.

---

## 7. Phased roadmap

| Phase | Scope | Done when |
|-------|-------|-----------|
| **0. Environment** ✅ partial | Xcode 27 + sims ✅, Android Studio + API 36/37 ✅, DevEco Studio ❌, devices ❌, accounts ❌ | All toolchains + 1 real device per platform; Gemini preview applied |
| **1. iOS rework** 🟡 built, touch-flow not yet verified | Replace VoiceTasks scaffold: domain model, mock fixtures, 5 screens, auth gate, audit log | D1–D5 work by touch in simulator with Face ID simulation |
| **2. iOS Siri** 🟡 6 intents + payee entity built, metadata verified; needs real-iPhone voice test | 5 intents + payee entity + shortcuts, tier gating | D1–D5 by Siri on real iPhone; Tier 2–3 never speak data |
| **3. Android core + AppFunctions** 🟡 built; 7 AppFunctions in generated schema; deep links + auth gate verified on API 36 emulator; `list-app-functions` unavailable on that image | Same model/screens; AppFunctions; deep links | `list-app-functions` shows functions; deep links pass D1–D5 |
| **4. Gemini** | Connected Console tester track | Gemini runs D2 + D5 (draft → app) for a tester |
| **4b. HarmonyOS NEXT + Xiaoyi** 🟡 ArkTS app + 6 InsightIntents written, **not compiled** (no DevEco on dev Mac) | `harmony/`: same model/screens, userAuth gate, privacy window, InsightIntentEntry per command | Builds in DevEco; D1–D5 by touch on HarmonyOS NEXT phone; Xiaoyi triggers intents after Huawei acceptance |
| **5. In-app voice fallback** 🟡 iOS + Android built: on-device STT only, rule parser (6/6 tests each); HarmonyOS pending; not yet tried with a real voice | STT + rule parser on iOS/Android; older Huawei (EMUI/HarmonyOS ≤4) runs the `android/` APK | D1–D5 by in-app mic on an older Huawei device |
| **6. Compliance review + demo polish** | Data-flow diagram, audit export, script, recording | Risk team sign-off on demo; 3-min recording |

---

## 8. Open questions

1. ~~Languages~~ **Decided: English only for now.** Khmer later via the in-app fallback. Note: Xiaoyi is Chinese-first, so the HarmonyOS demo may need Chinese utterances **[uncertain]**.
2. ~~Huawei target~~ **Decided: China HarmonyOS NEXT phone (Intents Kit).**
3. **Compliance owner:** who at the bank reviews assistant data flow and LLM usage?
4. **KHQR:** use a static sample QR, or is Bakong/KHQR SDK sandbox access available?
5. **Devices/accounts:** Apple Developer team, Google Connected Apps preview, Huawei developer account. Who enrolls?

---

## Sources

- Android AppFunctions (official): https://developer.android.com/ai/appfunctions
- AppFunctions + Gemini: https://9to5google.com/2026/02/25/android-appfunctions-gemini/
- Apple App Intents: https://developer.apple.com/documentation/appintents
- Siri AI developer preview: https://www.eweek.com/news/apple-siri-ai-developer-preview/
- Siri banking-app restriction report: https://www.iclarified.com/98115/everyone-missed-the-biggest-disappointment-of-apples-siri-delay-gurman
- HarmonyOS Intents Kit overview: https://dev.to/harmonyos/what-is-intents-kit-in-harmonyos-next-what-does-it-offer-differently-compared-to-android-3kg4
- Huawei Intents Kit sample (version reqs, acceptance): https://gitee.com/harmonyos_samples/IntentsKitVideoContinue/pulls/2.patch
- Huawei Celia: https://consumer.huawei.com/cn/mobileservices/celia/
