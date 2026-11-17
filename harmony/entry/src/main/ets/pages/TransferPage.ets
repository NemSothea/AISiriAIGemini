import { AuditLog } from '../model/AuditLog';
import { BankStore } from '../model/BankStore';
import { Payee, Tier, Transaction, TransferDraft, money } from '../model/Models';
import { AuthGate } from '../security/AuthGate';
import { TransferArgs } from '../services/Router';
import { AppWindow } from '../entryability/EntryAbility';

// Tier 3 — voice prepares, app confirms. Saved payees only; biometric + PIN to submit.

enum Step { FORM, REVIEW, DONE }

@ComponentV2
export struct TransferPage {
  @Param args: TransferArgs = new TransferArgs();
  private bank: BankStore = BankStore.shared();
  private audit: AuditLog = AuditLog.shared();
  private timerId: number = -1;

  @Local payeeId: string = '';
  @Local amountText: string = '';
  @Local step: Step = Step.FORM;
  @Local draft: TransferDraft | undefined = undefined;
  @Local done: Transaction | undefined = undefined;
  @Local error: string = '';
  @Local showPin: boolean = false;
  @Local pin: string = '';
  @Local remaining: number = 0;

  aboutToAppear(): void {
    if (this.args.amount !== undefined) {
      this.amountText = `${this.args.amount}`;
    }
    if (this.args.payee !== undefined) {
      const payee = this.bank.payeeNamed(this.args.payee);
      if (payee) {
        this.payeeId = payee.id;
      } else {
        this.error = `"${this.args.payee}" is not a saved payee. Voice transfers only go to saved payees.`;
        this.audit.record('app', 'prepareTransfer', Tier.AUTH_CONFIRM, 'unknown_payee');
      }
    }
  }

  aboutToDisappear(): void {
    clearInterval(this.timerId);
    AppWindow.setPrivacy(false);
  }

  private review(): void {
    this.error = '';
    const amount = Number(this.amountText);
    try {
      this.draft = this.bank.createDraft(this.payeeId, amount);
      this.step = Step.REVIEW;
      AppWindow.setPrivacy(true);
      this.startCountdown();
      this.audit.record('app', 'prepareTransfer', Tier.AUTH_CONFIRM, 'draft_created');
    } catch (e) {
      this.error = (e as Error).message;
      this.audit.record('app', 'prepareTransfer', Tier.AUTH_CONFIRM, 'draft_rejected');
    }
  }

  private startCountdown(): void {
    clearInterval(this.timerId);
    const update = (): void => {
      this.remaining = this.draft ? Math.max(0, Math.floor((this.draft.expiresAt - Date.now()) / 1000)) : 0;
    };
    update();
    this.timerId = setInterval(update, 1000);
  }

  private confirm(): void {
    this.error = '';
    if (!this.draft || this.draft.isExpired()) {
      this.error = 'This transfer request expired. Start again.';
      this.step = Step.FORM;
      return;
    }
    AuthGate.authenticate(`Confirm transfer to ${this.draft.payee.name}`).then(() => {
      this.pin = '';
      this.showPin = true;
    }).catch((e: Error) => {
      this.error = e.message;
      this.audit.record('app', 'submitTransfer', Tier.AUTH_CONFIRM, 'auth_failed');
    });
  }

  private submitWithPin(): void {
    this.showPin = false;
    try {
      AuthGate.verifyPin(this.pin);
      if (!this.draft) {
        return;
      }
      this.done = this.bank.submit(this.draft);
      this.step = Step.DONE;
      clearInterval(this.timerId);
      this.audit.record('app', 'submitTransfer', Tier.AUTH_CONFIRM, 'success');
    } catch (e) {
      this.error = (e as Error).message;
      this.audit.record('app', 'submitTransfer', Tier.AUTH_CONFIRM, 'failed');
    } finally {
      this.pin = '';
    }
  }

  @Builder
  formView() {
    Text('To (saved payees only)').fontWeight(FontWeight.Medium)
    ForEach(this.bank.payees, (p: Payee) => {
      Button(`${p.name} · ${p.bank} ${p.maskedAccount}`)
        .type(ButtonType.Capsule)
        .backgroundColor(this.payeeId === p.id ? '#0A59F7' : '#F2F2F7')
        .fontColor(this.payeeId === p.id ? Color.White : Color.Black)
        .onClick(() => { this.payeeId = p.id; })
    }, (p: Payee) => p.id)
    TextInput({ text: this.amountText, placeholder: 'Amount (USD)' })
      .type(InputType.NUMBER_DECIMAL)
      .onChange((v: string) => { this.amountText = v; })
    Text(`Limit USD ${BankStore.TRANSFER_CAP} per transfer in this demo.`).fontSize(12).fontColor('#888888')
    Button('Review')
      .enabled(this.payeeId.length > 0 && this.amountText.length > 0)
      .onClick(() => this.review())
  }

  @Builder
  reviewView() {
    if (this.draft) {
      Text('Review').fontSize(18).fontWeight(FontWeight.Medium)
      Text(`To: ${this.draft.payee.name}`)
      Text(`Account: ${this.draft.payee.bank} ${this.draft.payee.maskedAccount}`)
      Text(`Amount: ${money(this.draft.amount, this.draft.currency)}`)
      Text(`Expires in ${Math.floor(this.remaining / 60)}:${(this.remaining % 60).toString().padStart(2, '0')}`)
      Button('Confirm with biometrics + PIN').onClick(() => this.confirm())
      Button('Cancel')
        .type(ButtonType.Normal)
        .backgroundColor('#F2F2F7')
        .fontColor(Color.Black)
        .onClick(() => {
          this.audit.record('app', 'prepareTransfer', Tier.AUTH_CONFIRM, 'cancelled');
          clearInterval(this.timerId);
          this.step = Step.FORM;
        })
      if (this.showPin) {
        Column({ space: 8 }) {
          Text('Enter PIN').fontWeight(FontWeight.Medium)
          TextInput({ text: this.pin, placeholder: 'Demo PIN' })
            .type(InputType.NUMBER_PASSWORD)
            .maxLength(6)
            .onChange((v: string) => { this.pin = v; })
          Row({ space: 12 }) {
            Button('Cancel').onClick(() => { this.showPin = false; this.pin = ''; })
            Button('Submit').enabled(this.pin.length >= 4).onClick(() => this.submitWithPin())
          }
        }
        .padding(12)
        .borderRadius(12)
        .backgroundColor('#F2F2F7')
      }
    }
  }

  @Builder
  doneView() {
    if (this.done) {
      Text('Transfer sent (demo)').fontColor('#2E7D32').fontSize(18).fontWeight(FontWeight.Medium)
      Text(this.done.detail)
      Text(`Amount: ${money(this.done.amount, this.done.currency)}`)
      Text(`Reference: ${this.done.id.substring(0, 8)}`)
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          if (this.step === Step.FORM) {
            this.formView()
          } else if (this.step === Step.REVIEW) {
            this.reviewView()
          } else {
            this.doneView()
          }
          if (this.error.length > 0) {
            Text(this.error).fontColor('#C62828')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .padding(16)
      }
    }
    .title('Transfer')
  }
}
