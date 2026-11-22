---
name: security-check
description: Audit VoiceBank's voice/assistant entry points and secure screens against the tier security model (no account data to assistants, auth gates, audit logging, transfer limits). Use before committing changes to intents, AppFunctions, InsightIntents, AuthGate, BankAction/Router or transfer code, or when asked for a security/compliance review.
---

# VoiceBank tier security check

Review the current diff (`git diff HEAD`, plus untracked files). If there's no diff, review all entry points. Read the code; don't rely on grep hits alone.

## Files in scope
- Entry points:
  - `ios/VoiceBank/Intents/*`
  - `android/.../appfunctions/*`
  - `harmony/entry/src/main/ets/intents/*`
- Routing: `BankAction.swift`, `BankAction.kt`, `Router.ets`
- Auth: `AuthGate.*`, secure screens/pages, `TransferView` / `TransferScreen` / `TransferPage`
- Data: `BankStore` / `BankRepository`, `AuditLog.*`

## Checks
1. **No data leak to assistants.** Every return value, dialog, `IntentResult`, KDoc and `llmDescription` of a Tier 2/3 entry point must be free of:
   - balances and transactions
   - account or card numbers (masked ones included)
   - the transfer amount spoken back

   Tier 1 may return only public data: rates and branches.
2. **Tier 2/3 opens the app** and does nothing else:
   - iOS: `openAppWhenRun` + `.requiresAuthentication`
   - Android: returns a `PendingIntent`
   - Harmony: `UI_ABILITY_FOREGROUND`

   No freeze or transfer is executed inside the entry point.
3. **Auth gates:**
   - Secure screens call `AuthGate` before rendering data.
   - Transfer submit requires biometric **and** PIN.
   - Secure screens are dropped when the app backgrounds.
   - Harmony sets privacy mode on secure pages.
4. **Transfer rules** are enforced in the model layer, not only in the UI:
   - saved payee only
   - `0 < amount <= 100`
   - 5-minute expiry
   - single use (the draft is cleared after submit or failure)
5. **Deep links** are untrusted input:
   - Payee and amount only prefill the review form.
   - Unknown hosts are rejected and audited.
   - No deep link skips auth.
6. **Audit**:
   - Every entry point records an event for success and failure, with the correct source (`siri`, `agent`, `xiaoyi`, `touch`, `voice`, `deeplink`).
   - Audit events contain no balances or amounts.
7. **Excluded actions** have no voice path: new payee, limits/PIN/password, loans, full numbers.
8. **Android specifics**:
   - `PendingIntent`s are explicit, `FLAG_IMMUTABLE`, with unique request codes.
   - The AppFunction service keeps `android:permission="android.permission.BIND_APP_FUNCTION_SERVICE"`.
9. **Parity**: the same rule holds on all three platforms. Flag any platform that is weaker than the others.
10. **No real branding or data**: fictional payees only, "VoiceBank" name only, no real bank name or logo.

## Output
One line per finding:

```
path:line: <severity: block|warn|note>: <problem>. <fix>.
```

Order by severity. End with an overall verdict: block / ok with warnings / clean.
