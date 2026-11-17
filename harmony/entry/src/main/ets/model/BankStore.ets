import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import {
  Account, Branch, BranchDistance, Card, ExchangeRate, MockBankFixture, Payee, Transaction, TransferDraft
} from './Models';

export class BankError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'BankError';
  }
}

/**
 * Mock bank API backed by resources/rawfile/mock_bank.json. State resets on every launch.
 * No connection to any real core banking system.
 */
@ObservedV2
export class BankStore {
  static readonly TRANSFER_CAP: number = 100;
  static readonly DRAFT_LIFETIME_MS: number = 5 * 60 * 1000;
  private static instance?: BankStore;

  @Trace accounts: Account[] = [];
  @Trace cards: Card[] = [];
  @Trace transactions: Transaction[] = [];
  payees: Payee[] = [];
  rates: ExchangeRate[] = [];
  branches: Branch[] = [];
  private usedDraftIds: Set<string> = new Set<string>();
  private loaded: boolean = false;

  static shared(): BankStore {
    if (!BankStore.instance) {
      BankStore.instance = new BankStore();
    }
    return BankStore.instance;
  }

  /** Call once from EntryAbility.onCreate (and from intent executors, which may run first). */
  load(context: common.Context): void {
    if (this.loaded) {
      return;
    }
    const bytes: Uint8Array = context.resourceManager.getRawFileContentSync('mock_bank.json');
    const text: string = util.TextDecoder.create('utf-8').decodeToString(bytes);
    const fixture = JSON.parse(text) as MockBankFixture;
    this.accounts = fixture.accounts;
    this.payees = fixture.payees;
    this.rates = fixture.rates;
    this.branches = fixture.branches;
    this.cards = fixture.cards;
    this.transactions = fixture.transactions.sort((a, b) => b.date.localeCompare(a.date));
    this.loaded = true;
  }

  // Tier 1

  /** Demo origin: Wat Phnom. No location permission requested. */
  nearestBranches(lat: number = 11.5764, lng: number = 104.9230): BranchDistance[] {
    return this.branches
      .map((b: Branch): BranchDistance => ({ branch: b, km: BankStore.distanceKm(lat, lng, b.lat, b.lng) }))
      .sort((a, b) => a.km - b.km);
  }

  // Tier 2

  setFrozen(cardId: string, frozen: boolean): void {
    this.cards = this.cards.map((c: Card): Card => c.id === cardId ?
      { id: c.id, name: c.name, maskedNumber: c.maskedNumber, frozen: frozen } : c);
  }

  // Tier 3

  payeeNamed(name: string): Payee | undefined {
    const wanted = name.trim().toLowerCase();
    return this.payees.find((p: Payee) => p.name.toLowerCase() === wanted);
  }

  createDraft(payeeId: string, amount: number): TransferDraft {
    const payee = this.payees.find((p: Payee) => p.id === payeeId);
    if (!payee) {
      throw new BankError('Only saved payees can receive voice transfers.');
    }
    if (!(amount > 0)) {
      throw new BankError('Enter an amount greater than zero.');
    }
    if (amount > BankStore.TRANSFER_CAP) {
      throw new BankError(`Voice transfers are limited to USD ${BankStore.TRANSFER_CAP} in this demo.`);
    }
    const rounded = Math.round(amount * 100) / 100;
    return new TransferDraft(util.generateRandomUUID(), payee, rounded, Date.now() + BankStore.DRAFT_LIFETIME_MS);
  }

  submit(draft: TransferDraft): Transaction {
    if (this.usedDraftIds.has(draft.id)) {
      throw new BankError('This transfer request was already used.');
    }
    if (draft.isExpired()) {
      throw new BankError('This transfer request expired. Start again.');
    }
    const account = this.accounts.find((a: Account) => a.currency === draft.currency && a.balance >= draft.amount);
    if (!account) {
      throw new BankError('Insufficient funds.');
    }
    this.usedDraftIds.add(draft.id);
    this.accounts = this.accounts.map((a: Account): Account => a.id === account.id ?
      { id: a.id, name: a.name, maskedNumber: a.maskedNumber, currency: a.currency,
        balance: Math.round((a.balance - draft.amount) * 100) / 100 } : a);
    const tx: Transaction = {
      id: util.generateRandomUUID(),
      date: new Date().toISOString(),
      detail: `Transfer to ${draft.payee.name}`,
      amount: -draft.amount,
      currency: draft.currency
    };
    this.transactions = [tx].concat(this.transactions);
    return tx;
  }

  private static distanceKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const r = 6371;
    const rad = (d: number): number => d * Math.PI / 180;
    const dLat = rad(lat2 - lat1);
    const dLng = rad(lng2 - lng1);
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    return 2 * r * Math.asin(Math.sqrt(a));
  }
}
