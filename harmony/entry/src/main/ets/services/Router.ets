import { AuditLog } from '../model/AuditLog';
import { Tier } from '../model/Models';

/** Canonical actions shared by touch, deep links and Xiaoyi intents — PLAN.md §4. Same names as iOS/Android. */
export enum Route {
  QR = 'QR',
  RATES = 'Rates',
  BRANCHES = 'Branches',
  BALANCE = 'Balance',
  CARD = 'Card',
  TRANSFER = 'Transfer',
  AUDIT = 'Audit'
}

export class TransferArgs {
  payee?: string;
  amount?: number;

  constructor(payee?: string, amount?: number) {
    this.payee = payee;
    this.amount = amount;
  }
}

export function actionName(route: Route): string {
  switch (route) {
    case Route.QR: return 'showQR';
    case Route.RATES: return 'getRates';
    case Route.BRANCHES: return 'findBranch';
    case Route.BALANCE: return 'checkBalance';
    case Route.CARD: return 'freezeCard';
    case Route.TRANSFER: return 'prepareTransfer';
    default: return 'viewAudit';
  }
}

export function tierOf(route: Route): Tier {
  switch (route) {
    case Route.BALANCE:
    case Route.CARD:
      return Tier.AUTH_VIEW;
    case Route.TRANSFER:
      return Tier.AUTH_CONFIRM;
    default:
      return Tier.PUBLIC;
  }
}

const SECURE_ROUTES: string[] = [Route.BALANCE, Route.CARD, Route.TRANSFER];

@ObservedV2
export class Router {
  private static instance?: Router;
  @Trace stack: NavPathStack = new NavPathStack();

  static shared(): Router {
    if (!Router.instance) {
      Router.instance = new Router();
    }
    return Router.instance;
  }

  open(route: Route, source: string, args?: TransferArgs): void {
    if (route !== Route.AUDIT) {
      AuditLog.shared().record(source, actionName(route), tierOf(route), 'opened');
    }
    this.stack.clear();
    this.stack.pushPath({ name: route, param: args ?? new TransferArgs() });
  }

  back(): void {
    this.stack.pop();
  }

  /** Called when the app goes to background: secure screens must re-authenticate on return. */
  dropSecureScreens(): void {
    const names: string[] = this.stack.getAllPathName();
    if (names.some((n: string) => SECURE_ROUTES.includes(n))) {
      this.stack.clear();
    }
  }

  /** voicebank://qr | rates | branches | balance | freeze | transfer?payee=Dara&amount=20 */
  openUri(uri: string, source: string): boolean {
    const match = uri.match(new RegExp('^voicebank://([a-z]+)(\\?(.*))?$'));
    if (!match) {
      AuditLog.shared().record(source, 'unknown', Tier.PUBLIC, 'rejected');
      return false;
    }
    const host = match[1];
    const query = match[3] ?? '';
    const routes: Map<string, Route> = new Map<string, Route>([
      ['qr', Route.QR], ['rates', Route.RATES], ['branches', Route.BRANCHES],
      ['balance', Route.BALANCE], ['freeze', Route.CARD], ['transfer', Route.TRANSFER]
    ]);
    const route = routes.get(host);
    if (route === undefined) {
      AuditLog.shared().record(source, 'unknown', Tier.PUBLIC, 'rejected');
      return false;
    }
    let payee: string | undefined = undefined;
    let amount: number | undefined = undefined;
    for (const pair of query.split('&')) {
      const kv: string[] = pair.split('=');
      if (kv.length === 2 && kv[0] === 'payee') {
        payee = decodeURIComponent(kv[1]);
      } else if (kv.length === 2 && kv[0] === 'amount') {
        const n = Number(kv[1]);
        amount = Number.isFinite(n) ? n : undefined;
      }
    }
    this.open(route, source, new TransferArgs(payee, amount));
    return true;
  }
}
