import Foundation
import Observation

/// Mock bank API backed by bundled JSON. State resets on every launch.
/// No connection to any real core banking system.
@MainActor
@Observable
final class BankStore {
    nonisolated static let transferCap: Decimal = 100
    nonisolated static let draftLifetime: TimeInterval = 5 * 60

    enum BankError: LocalizedError {
        case unknownPayee
        case invalidAmount
        case overCap
        case draftExpired
        case draftUsed
        case insufficientFunds

        var errorDescription: String? {
            switch self {
            case .unknownPayee: "Only saved payees can receive voice transfers."
            case .invalidAmount: "Enter an amount greater than zero."
            case .overCap: "Voice transfers are limited to \(BankStore.transferCap.formatted(.currency(code: "USD"))) in this demo."
            case .draftExpired: "This transfer request expired. Start again."
            case .draftUsed: "This transfer request was already used."
            case .insufficientFunds: "Insufficient funds."
            }
        }
    }

    private(set) var accounts: [Account] = []
    private(set) var payees: [Payee] = []
    private(set) var rates: [ExchangeRate] = []
    private(set) var branches: [Branch] = []
    private(set) var cards: [Card] = []
    private(set) var transactions: [Transaction] = []
    private var usedDraftIDs: Set<UUID> = []

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "mock_bank", withExtension: "json") else {
            fatalError("mock_bank.json missing from bundle")
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let fixture = try decoder.decode(MockBankFixture.self, from: Data(contentsOf: url))
            accounts = fixture.accounts
            payees = fixture.payees
            rates = fixture.rates
            branches = fixture.branches
            cards = fixture.cards
            transactions = fixture.transactions.sorted { $0.date > $1.date }
        } catch {
            fatalError("Failed to load mock_bank.json: \(error)")
        }
    }

    // MARK: Tier 1

    /// Demo origin: Wat Phnom. No location permission requested.
    func nearestBranches(lat: Double = 11.5764, lng: Double = 104.9230) -> [(Branch, Double)] {
        branches
            .map { ($0, Self.distanceKm(lat, lng, $0.lat, $0.lng)) }
            .sorted { $0.1 < $1.1 }
    }

    // MARK: Tier 2

    func setFrozen(cardID: String, _ frozen: Bool) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        cards[index].frozen = frozen
    }

    // MARK: Tier 3

    func payee(named name: String) -> Payee? {
        payees.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }

    func createDraft(payeeID: String, amount: Decimal) throws -> TransferDraft {
        guard let payee = payees.first(where: { $0.id == payeeID }) else { throw BankError.unknownPayee }
        guard amount > 0 else { throw BankError.invalidAmount }
        guard amount <= Self.transferCap else { throw BankError.overCap }
        return TransferDraft(payee: payee, amount: amount, expiresAt: .now.addingTimeInterval(Self.draftLifetime))
    }

    func submit(_ draft: TransferDraft) throws -> Transaction {
        guard !usedDraftIDs.contains(draft.id) else { throw BankError.draftUsed }
        guard !draft.isExpired else { throw BankError.draftExpired }
        guard let index = accounts.firstIndex(where: { $0.currency == draft.currency }),
              accounts[index].balance >= draft.amount else { throw BankError.insufficientFunds }

        usedDraftIDs.insert(draft.id)
        accounts[index].balance -= draft.amount
        let transaction = Transaction(
            id: UUID().uuidString,
            date: .now,
            detail: "Transfer to \(draft.payee.name)",
            amount: -draft.amount,
            currency: draft.currency
        )
        transactions.insert(transaction, at: 0)
        return transaction
    }

    // MARK: Helpers

    private static func distanceKm(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Double {
        let r = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLng / 2) * sin(dLng / 2)
        return 2 * r * asin(sqrt(a))
    }
}
