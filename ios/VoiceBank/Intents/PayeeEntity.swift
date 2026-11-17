import AppIntents
import Foundation

/// Saved payee that Siri can resolve by name ("send money to Dara").
/// Only saved payees are exposed — new payees are never reachable by voice.
struct PayeeEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Payee"
    static let defaultQuery = PayeeQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        // Name only — no account number spoken or shown by Siri.
        DisplayRepresentation(title: "\(name)")
    }
}

struct PayeeQuery: EntityStringQuery {
    @Dependency private var bank: BankStore

    @MainActor
    func entities(for identifiers: [String]) async throws -> [PayeeEntity] {
        bank.payees.filter { identifiers.contains($0.id) }.map(PayeeEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [PayeeEntity] {
        bank.payees.filter { $0.name.localizedCaseInsensitiveContains(string) }.map(PayeeEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [PayeeEntity] {
        bank.payees.map(PayeeEntity.init)
    }
}

extension PayeeEntity {
    init(_ payee: Payee) {
        id = payee.id
        name = payee.name
    }
}
