// Domain model — PLAN.md §4. Same shape as iOS/Android. Demo data only.
// Amounts are plain numbers rounded to cents (demo); production would use integer minor units.

export interface Account {
  id: string;
  name: string;
  maskedNumber: string;
  currency: string;
  balance: number;
}

export interface Payee {
  id: string;
  name: string;
  bank: string;
  maskedAccount: string;
}

export interface ExchangeRate {
  pair: string;
  buy: number;
  sell: number;
  asOf: string;
}

export interface Branch {
  id: string;
  name: string;
  type: string; // "atm" | "branch"
  address: string;
  lat: number;
  lng: number;
}

export interface Card {
  id: string;
  name: string;
  maskedNumber: string;
  frozen: boolean;
}

export interface Transaction {
  id: string;
  date: string;
  detail: string;
  amount: number;
  currency: string;
}

export interface MockBankFixture {
  accounts: Account[];
  payees: Payee[];
  rates: ExchangeRate[];
  branches: Branch[];
  cards: Card[];
  transactions: Transaction[];
}

export interface BranchDistance {
  branch: Branch;
  km: number;
}

/** Voice-prepared transfer. Saved payees only, capped, short-lived, single use. */
export class TransferDraft {
  readonly id: string;
  readonly payee: Payee;
  readonly amount: number;
  readonly currency: string = 'USD';
  readonly expiresAt: number;

  constructor(id: string, payee: Payee, amount: number, expiresAt: number) {
    this.id = id;
    this.payee = payee;
    this.amount = amount;
    this.expiresAt = expiresAt;
  }

  isExpired(): boolean {
    return Date.now() >= this.expiresAt;
  }
}

/** Security tier — PLAN.md §1. */
export enum Tier {
  PUBLIC = 'Public',
  AUTH_VIEW = 'Biometric',
  AUTH_CONFIRM = 'Biometric + PIN'
}

export function money(amount: number, currency: string): string {
  const sign = amount < 0 ? '-' : '';
  const abs = Math.abs(amount);
  return currency === 'KHR' ? `${sign}${abs.toFixed(0)} KHR` : `${sign}$${abs.toFixed(2)}`;
}
