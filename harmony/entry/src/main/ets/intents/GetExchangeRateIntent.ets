// Xiaoyi entry points for demo commands D1–D5 (PLAN.md §1) via InsightIntent decorators (API 20+).
// Rules (same as Siri / Gemini):
//  - Tier 1 may return public data to Xiaoyi.
//  - Tier 2–3 NEVER return balances, transactions or account numbers. They open the app in the
//    foreground; the user continues behind biometrics (+PIN for Tier 3).
//
// [uncertain] `domain` values: Huawei publishes standard intent verticals; a custom finance domain may
// need to be mapped to an official one during Huawei's Intents Kit acceptance review.
// [uncertain] Executor parameter binding: entry parameters are read from same-named class properties,
// per the community sample this is based on — verify against official docs in DevEco.

import { insightIntent, InsightIntentEntry, InsightIntentEntryExecutor } from '@kit.AbilityKit';
import { BankStore } from '../model/BankStore';
import { AuditLog } from '../model/AuditLog';
import { ExchangeRate, Tier } from '../model/Models';
import { ok, fail } from './IntentResults';

@InsightIntentEntry({
  intentName: 'GetExchangeRate',
  domain: 'FinanceDomain',
  intentVersion: '1.0.0',
  displayName: 'Exchange Rate',
  displayDescription: 'Tell today\'s USD to KHR demo rate',
  icon: $r('app.media.startIcon'),
  llmDescription: 'Returns the bank\'s demo USD/KHR buy and sell rate. Public information, safe to read aloud.',
  keywords: ['exchange rate', 'dollar rate', 'USD KHR'],
  abilityName: 'EntryAbility',
  // Background: returns data to Xiaoyi without showing the app. EntryAbility.onCreate loads the stores.
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_BACKGROUND],
  parameters: { 'type': 'object', 'properties': {}, 'additionalProperties': false }
})
export default class GetExchangeRateIntent extends InsightIntentEntryExecutor<string> {
  onExecute(): Promise<insightIntent.IntentResult<string>> {
    const rate = BankStore.shared().rates.find((r: ExchangeRate) => r.pair === 'USD/KHR');
    if (!rate) {
      AuditLog.shared().record('xiaoyi', 'getRates', Tier.PUBLIC, 'no_data');
      return fail('Exchange rates are not available right now.');
    }
    AuditLog.shared().record('xiaoyi', 'getRates', Tier.PUBLIC, 'answered');
    return ok(`Demo rate: 1 USD buys ${rate.buy} KHR, sells at ${rate.sell} KHR.`);
  }
}
