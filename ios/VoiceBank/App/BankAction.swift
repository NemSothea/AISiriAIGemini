import Foundation
import Observation

/// Canonical actions shared by touch, deep links, and (Phase 2) Siri intents — PLAN.md §4.
enum BankAction: Hashable {
    case showQR
    case rates
    case branches
    case balance
    case freezeCard
    case transfer(payee: String?, amount: Decimal?)

    var name: String {
        switch self {
        case .showQR: "showQR"
        case .rates: "getRates"
        case .branches: "findBranch"
        case .balance: "checkBalance"
        case .freezeCard: "freezeCard"
        case .transfer: "prepareTransfer"
        }
    }

    var tier: Tier {
        switch self {
        case .showQR, .rates, .branches: .publicInfo
        case .balance, .freezeCard: .authView
        case .transfer: .authConfirm
        }
    }

    /// voicebank://qr | rates | branches | balance | freeze | transfer?payee=Dara&amount=20
    init?(url: URL) {
        guard url.scheme == "voicebank", let host = url.host() else { return nil }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ key: String) -> String? { query.first { $0.name == key }?.value }

        switch host {
        case "qr": self = .showQR
        case "rates": self = .rates
        case "branches": self = .branches
        case "balance": self = .balance
        case "freeze": self = .freezeCard
        case "transfer":
            self = .transfer(payee: value("payee"), amount: value("amount").flatMap { Decimal(string: $0) })
        default: return nil
        }
    }
}

@MainActor
@Observable
final class AppRouter {
    var path: [BankAction] = []

    func open(_ action: BankAction, source: String, audit: AuditLog) {
        audit.record(source: source, action: action.name, tier: action.tier, result: "opened")
        path = [action]
    }
}
