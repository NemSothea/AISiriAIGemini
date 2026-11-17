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
import { Tier } from '../model/Models';
import { Route, Router, TransferArgs } from '../services/Router';
import { ok, fail } from './IntentResults';

@InsightIntentEntry({
  intentName: 'PrepareTransfer',
  domain: 'FinanceDomain',
  intentVersion: '1.0.0',
  displayName: 'Send Money to Saved Payee',
  displayDescription: 'Prepare a transfer you confirm in the app with biometrics and PIN',
  icon: $r('app.media.startIcon'),
  llmDescription: 'Opens a prefilled transfer review for a SAVED payee (max 100 USD). Nothing is sent until the user confirms with biometrics and PIN. Never say the transfer is complete.',
  keywords: ['send money', 'transfer', 'pay'],
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_FOREGROUND],
  parameters: {
    'type': 'object',
    'properties': {
      'payeeName': { 'type': 'string', 'description': 'Name of a saved payee, e.g. Dara', 'minLength': 1, 'maxLength': 50 },
      'amountUsd': { 'type': 'number', 'description': 'Amount in US dollars, greater than 0 and at most 100' }
    },
    'required': ['payeeName'],
    'additionalProperties': false
  }
})
export default class PrepareTransferIntent extends InsightIntentEntryExecutor<string> {
  payeeName: string = '';
  amountUsd?: number = undefined;

  onExecute(): Promise<insightIntent.IntentResult<string>> {
    const audit = AuditLog.shared();
    const payee = BankStore.shared().payeeNamed(this.payeeName);
    if (!payee) {
      audit.record('xiaoyi', 'prepareTransfer', Tier.AUTH_CONFIRM, 'unknown_payee');
      return fail('Only saved payees can receive voice transfers. Ask the user to check the name.');
    }
    const amount = this.amountUsd;
    if (amount !== undefined && (!(amount > 0) || amount > BankStore.TRANSFER_CAP)) {
      audit.record('xiaoyi', 'prepareTransfer', Tier.AUTH_CONFIRM, 'invalid_amount');
      return fail(`Amount must be between 0 and ${BankStore.TRANSFER_CAP} USD.`);
    }
    // Amount only prefills the review screen; nothing executes here.
    Router.shared().open(Route.TRANSFER, 'xiaoyi', new TransferArgs(payee.name, amount));
    return ok('opened_app_for_confirmation');
  }
}
