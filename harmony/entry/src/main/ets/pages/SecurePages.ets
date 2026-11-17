import { promptAction } from '@kit.ArkUI';
import { AuditLog } from '../model/AuditLog';
import { BankStore } from '../model/BankStore';
import { Account, Card, Tier, Transaction, money } from '../model/Models';
import { AuthGate } from '../security/AuthGate';
import { SecureGate } from './Common';

// Tier 2 — biometric required; data shown in-app only.

@ComponentV2
export struct BalancePage {
  private bank: BankStore = BankStore.shared();

  @Builder
  details() {
    List() {
      ListItemGroup({ header: this.header('Accounts') }) {
        ForEach(this.bank.accounts, (a: Account) => {
          ListItem() {
            Row() {
              Column() {
                Text(a.name)
                Text(a.maskedNumber).fontSize(12).fontColor('#888888')
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(money(a.balance, a.currency)).fontWeight(FontWeight.Bold)
            }.padding(16)
          }
        }, (a: Account) => `${a.id}-${a.balance}`)
      }
      ListItemGroup({ header: this.header('Recent transactions') }) {
        ForEach(this.bank.transactions.slice(0, 10), (t: Transaction) => {
          ListItem() {
            Row() {
              Column() {
                Text(t.detail)
                Text(t.date.substring(0, 16).replace('T', ' ')).fontSize(12).fontColor('#888888')
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(money(t.amount, t.currency)).fontColor(t.amount < 0 ? Color.Black : '#2E7D32')
            }.padding(16)
          }
        }, (t: Transaction) => t.id)
      }
    }
  }

  @Builder
  header(title: string) {
    Text(title).fontSize(14).fontWeight(FontWeight.Medium).padding(16)
  }

  build() {
    NavDestination() {
      SecureGate({ title: 'View your balance', action: 'checkBalance', tier: Tier.AUTH_VIEW }) {
        this.details()
      }
    }
    .title('Balance')
  }
}

@ComponentV2
export struct CardPage {
  private bank: BankStore = BankStore.shared();

  private toggle(card: Card): void {
    const freeze = !card.frozen;
    const action = freeze ? 'freezeCard' : 'unfreezeCard';
    promptAction.showDialog({
      title: freeze ? 'Freeze this card?' : 'Unfreeze this card?',
      buttons: [{ text: 'Cancel', color: '#888888' }, { text: freeze ? 'Freeze' : 'Unfreeze', color: '#0A59F7' }]
    }).then((res: promptAction.ShowDialogSuccessResponse) => {
      if (res.index !== 1) {
        return;
      }
      // Fresh auth for the state change itself, not just for viewing.
      AuthGate.authenticate(freeze ? 'Freeze your card' : 'Unfreeze your card').then(() => {
        this.bank.setFrozen(card.id, freeze);
        AuditLog.shared().record('app', action, Tier.AUTH_VIEW, 'success');
      }).catch(() => {
        AuditLog.shared().record('app', action, Tier.AUTH_VIEW, 'auth_failed');
      });
    });
  }

  @Builder
  cards() {
    List() {
      ForEach(this.bank.cards, (card: Card) => {
        ListItem() {
          Column({ space: 10 }) {
            Text(card.name).fontSize(18).fontWeight(FontWeight.Medium)
            Text(card.maskedNumber).fontFamily('monospace')
            Text(card.frozen ? 'Frozen' : 'Active').fontColor(card.frozen ? '#1565C0' : '#2E7D32')
            Button(card.frozen ? 'Unfreeze card' : 'Freeze card').onClick(() => this.toggle(card))
          }.alignItems(HorizontalAlign.Start).padding(16)
        }
      }, (card: Card) => `${card.id}-${card.frozen}`)
    }
  }

  build() {
    NavDestination() {
      SecureGate({ title: 'Manage your card', action: 'freezeCard', tier: Tier.AUTH_VIEW }) {
        this.cards()
      }
    }
    .title('Card Controls')
  }
}
