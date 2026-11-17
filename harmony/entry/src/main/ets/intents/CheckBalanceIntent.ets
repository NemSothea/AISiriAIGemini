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
import { Route, Router } from '../services/Router';
import { ok } from './IntentResults';

@InsightIntentEntry({
  intentName: 'CheckBalance',
  domain: 'FinanceDomain',
  intentVersion: '1.0.0',
  displayName: 'Check Balance',
  displayDescription: 'Open VoiceBank; balance is shown only in the app after verification',
  icon: $r('app.media.startIcon'),
  llmDescription: 'Opens the secure balance screen. Does NOT return the balance; never state an amount.',
  keywords: ['balance', 'check balance', 'how much money'],
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_FOREGROUND],
  parameters: { 'type': 'object', 'properties': {}, 'additionalProperties': false }
})
export default class CheckBalanceIntent extends InsightIntentEntryExecutor<string> {
  onExecute(): Promise<insightIntent.IntentResult<string>> {
    Router.shared().open(Route.BALANCE, 'xiaoyi');
    return ok('opened_app_for_verification');
  }
}
