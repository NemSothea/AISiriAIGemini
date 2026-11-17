import { BankStore } from '../model/BankStore';
import { BranchDistance, ExchangeRate } from '../model/Models';

// Tier 1 — public / receive-only. No authentication.

/** Static sample payload. Real KHQR needs Bakong/KHQR SDK access (PLAN.md §4). */
const SAMPLE_QR_PAYLOAD: string = 'DEMO-KHQR-SAMPLE-NOT-FOR-PAYMENT';

@ComponentV2
export struct QRPage {
  build() {
    NavDestination() {
      Column({ space: 16 }) {
        QRCode(SAMPLE_QR_PAYLOAD)
          .width(240)
          .height(240)
          .backgroundColor(Color.White)
          .padding(12)
        Text('Scan to pay me').fontSize(18).fontWeight(FontWeight.Medium)
        Text('Sample QR — not a valid KHQR').fontColor('#C62828')
      }
      .width('100%')
      .padding(24)
    }
    .title('Receive')
  }
}

@ComponentV2
export struct RatesPage {
  private bank: BankStore = BankStore.shared();

  build() {
    NavDestination() {
      List() {
        ForEach(this.bank.rates, (rate: ExchangeRate) => {
          ListItem() {
            Row() {
              Text(rate.pair).fontSize(18).fontWeight(FontWeight.Medium).layoutWeight(1)
              Column() {
                Text(`Buy ${rate.buy}`)
                Text(`Sell ${rate.sell}`).fontColor('#888888')
              }.alignItems(HorizontalAlign.End)
            }.padding(16)
          }
        }, (rate: ExchangeRate) => rate.pair)
        ListItem() {
          Text(`Demo rates, not live · as of ${this.bank.rates.length > 0 ? this.bank.rates[0].asOf : ''}`)
            .fontSize(12).fontColor('#888888').padding(16)
        }
      }
    }
    .title('Exchange Rates')
  }
}

@ComponentV2
export struct BranchesPage {
  private bank: BankStore = BankStore.shared();

  build() {
    NavDestination() {
      List() {
        ForEach(this.bank.nearestBranches(), (item: BranchDistance) => {
          ListItem() {
            Row() {
              Column() {
                Text(item.branch.type === 'atm' ? 'ATM' : 'Branch').fontSize(12).fontColor('#888888')
                Text(item.branch.name).fontSize(16)
                Text(item.branch.address).fontSize(12).fontColor('#888888')
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(`${item.km.toFixed(1)} km`).fontColor('#888888')
            }.padding(16)
          }
        }, (item: BranchDistance) => item.branch.id)
        ListItem() {
          Text('Distances from a fixed demo location (Wat Phnom). Locations are fictional.')
            .fontSize(12).fontColor('#888888').padding(16)
        }
      }
    }
    .title('ATM & Branches')
  }
}
