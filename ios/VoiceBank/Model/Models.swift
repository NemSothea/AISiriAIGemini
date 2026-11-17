import Foundation

// Domain model — PLAN.md §4. Demo data only; never real customer data.

struct Account: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let maskedNumber: String
    let currency: String
    var balance: Decimal
}

struct Payee: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let bank: String
    let maskedAccount: String
}

struct ExchangeRate: Codable, Identifiable, Sendable {
    var id: String { pair }
    let pair: String
    let buy: Decimal
    let sell: Decimal
    let asOf: Date
}

struct Branch: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let type: String // "atm" | "branch"
    let address: String
    let lat: Double
    let lng: Double
}

struct Card: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let maskedNumber: String
    var frozen: Bool
}

struct Transaction: Codable, Identifiable, Sendable {
    let id: String
    let date: Date
    let detail: String
    let amount: Decimal
    let currency: String
}

/// Voice-prepared transfer. Saved payees only, capped, short-lived, single use.
struct TransferDraft: Identifiable, Sendable {
    let id = UUID()
    let payee: Payee
    let amount: Decimal
    let currency = "USD"
    let expiresAt: Date

    var isExpired: Bool { Date.now >= expiresAt }
}

/// Security tier — PLAN.md §1.
enum Tier: Int, Codable, Sendable {
    case publicInfo = 1   // no auth
    case authView = 2     // biometric, data shown in-app only
    case authConfirm = 3  // biometric + PIN
}

struct MockBankFixture: Codable {
    var accounts: [Account]
    var payees: [Payee]
    var rates: [ExchangeRate]
    var branches: [Branch]
    var cards: [Card]
    var transactions: [Transaction]
}
