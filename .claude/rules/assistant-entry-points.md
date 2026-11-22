---
paths:
  - "ios/VoiceBank/Intents/**"
  - "android/app/src/main/kotlin/com/example/voicebank/appfunctions/**"
  - "harmony/entry/src/main/ets/intents/**"
---

# Assistant entry points (Siri intents, Gemini AppFunctions, Xiaoyi InsightIntents)

Whatever these return goes to Apple, Google or Huawei servers. Treat every return value, dialog, title, description, KDoc and `llmDescription` as public.

## Per tier

**Tier 1 (`showQR`, `getRates`, `findBranch`)**
- May return or speak public data (rates, branch list).
- QR only opens the app; it never returns QR payload data.

**Tier 2 (`checkBalance`, `freezeCard`)**
- Open the app only. Never return balances, transactions or card numbers.
- Freeze is never executed here; the user confirms it in-app.
- iOS: `openAppWhenRun = true` + `authenticationPolicy = .requiresAuthentication`.
- Android: return a `PendingIntent` from `openApp(...)`.
- Harmony: `ExecuteMode.UI_ABILITY_FOREGROUND` + `ok('opened_app_for_verification')`.

**Tier 3 (`prepareTransfer`, `findPayee`)**
- Only builds a draft and opens the review screen. Never submits the transfer.
- Never repeat the amount back in a dialog.
- Saved payees only. Reject unknown payees with an error message that tells the assistant to ask the user; never offer to add a payee.
- Validate `0 < amount <= TRANSFER_CAP` (100 USD) before opening the app.
- `findPayee` returns name + id only, never an account number.

## Always
- Write an audit event for every outcome, including failures (`not_found`, `invalid_amount`, `unknown_payee`, `no_data`).
- Audit source per platform: `siri`, `agent` (Gemini), `xiaoyi`. In-app sources: `touch`, `voice`, `deeplink`.
- Route through the canonical action (`router.open(...)` / `openApp(BankAction...)` / `Router.shared().open(...)`). Never navigate to a screen directly.
- Descriptions are prompts:
  - Android KDoc (`isDescribedByKDoc = true`) and Harmony `llmDescription` are what the LLM reads.
  - For Tier 2–3, state explicitly what is NOT returned or done ("Does NOT return the balance", "Do not tell the user the transfer is complete").
- Android `PendingIntent`s stay explicit (our own `MainActivity`), `FLAG_IMMUTABLE | FLAG_ONE_SHOT`. Use a unique request code per function.
- Never add a voice entry point for an excluded action: new payee, limit/PIN/password change, loan, full account/card number.
