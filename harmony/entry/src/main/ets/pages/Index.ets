import { Router, Route, TransferArgs, tierOf } from '../services/Router';
import { TierBadge } from './Common';
import { QRPage, RatesPage, BranchesPage } from './PublicPages';
import { BalancePage, CardPage } from './SecurePages';
import { TransferPage } from './TransferPage';
import { AuditPage } from './AuditPage';

class Tile {
  route: Route;
  title: string;

  constructor(route: Route, title: string) {
    this.route = route;
    this.title = title;
  }
}

@Entry
@ComponentV2
struct Index {
  private router: Router = Router.shared();
  private tiles: Tile[] = [
    new Tile(Route.QR, 'Receive (KHQR)'),
    new Tile(Route.RATES, 'Exchange Rates'),
    new Tile(Route.BRANCHES, 'ATM & Branches'),
    new Tile(Route.BALANCE, 'Balance'),
    new Tile(Route.CARD, 'Card Controls'),
    new Tile(Route.TRANSFER, 'Transfer')
  ];

  @Builder
  routeMap(name: string, param: Object) {
    if (name === Route.QR) {
      QRPage()
    } else if (name === Route.RATES) {
      RatesPage()
    } else if (name === Route.BRANCHES) {
      BranchesPage()
    } else if (name === Route.BALANCE) {
      BalancePage()
    } else if (name === Route.CARD) {
      CardPage()
    } else if (name === Route.TRANSFER) {
      TransferPage({ args: param as TransferArgs })
    } else if (name === Route.AUDIT) {
      AuditPage()
    }
  }

  build() {
    Navigation(this.router.stack) {
      Column({ space: 12 }) {
        Text('Demo build · mock data only')
          .fontSize(13)
          .fontColor('#888888')
          .width('100%')

        Grid() {
          ForEach(this.tiles, (tile: Tile) => {
            GridItem() {
              Column({ space: 10 }) {
                Text(tile.title).fontSize(16).fontWeight(FontWeight.Medium)
                TierBadge({ tier: tierOf(tile.route) })
              }
              .width('100%')
              .height(120)
              .justifyContent(FlexAlign.Center)
              .backgroundColor('#F2F2F7')
              .borderRadius(16)
              .onClick(() => this.router.open(tile.route, 'touch'))
            }
          }, (tile: Tile) => tile.route)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(16)
        .rowsGap(16)
      }
      .padding(16)
    }
    .title('VoiceBank')
    .titleMode(NavigationTitleMode.Full)
    .menus([{ value: 'Audit', action: () => this.router.open(Route.AUDIT, 'touch') }])
    .mode(NavigationMode.Stack)
    .navDestination(this.routeMap)
  }
}
