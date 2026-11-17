import AppIntents
import Foundation

// Siri entry points for the demo commands D1–D5 (PLAN.md §1).
// Rules:
//  - Tier 1 may answer in Siri (public data only).
//  - Tier 2–3 require an unlocked device, open the app, and never speak balances or amounts.
//    In-app Face ID (and PIN for Tier 3) still applies after the app opens.

// MARK: Tier 1

struct ShowQRIntent: AppIntent {
    static let title: LocalizedStringResource = "Show My Receive QR"
    static let description = IntentDescription("Opens your QR code so someone can pay you.")
    static let openAppWhenRun = true

    @Dependency private var router: AppRouter
    @Dependency private var audit: AuditLog

    @MainActor
    func perform() async throws -> some IntentResult {
        router.open(.showQR, source: "siri", audit: audit)
        return .result()
    }
}

struct ExchangeRateIntent: AppIntent {
    static let title: LocalizedStringResource = "Exchange Rate"
    static let description = IntentDescription("Tells you today's USD to KHR demo rate.")

    @Dependency private var bank: BankStore
    @Dependency private var audit: AuditLog

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let rate = bank.rates.first(where: { $0.pair == "USD/KHR" }) else {
            audit.record(source: "siri", action: "getRates", tier: .publicInfo, result: "no_data")
            return .result(dialog: "Exchange rates are not available right now.")
        }
        audit.record(source: "siri", action: "getRates", tier: .publicInfo, result: "answered")
        return .result(dialog: "Demo rate: one US dollar buys \(rate.buy.formatted()) riel and sells at \(rate.sell.formatted()) riel.")
    }
}

struct FindBranchIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Nearest ATM or Branch"
    static let openAppWhenRun = true

    @Dependency private var router: AppRouter
    @Dependency private var audit: AuditLog

    @MainActor
    func perform() async throws -> some IntentResult {
        router.open(.branches, source: "siri", audit: audit)
        return .result()
    }
}

// MARK: Tier 2

struct CheckBalanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Balance"
    static let description = IntentDescription("Opens VoiceBank. Your balance is shown only in the app after Face ID.")
    static let openAppWhenRun = true
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Dependency private var router: AppRouter
    @Dependency private var audit: AuditLog

    @MainActor
    func perform() async throws -> some IntentResult {
        router.open(.balance, source: "siri", audit: audit)
        return .result()
    }
}

struct FreezeCardIntent: AppIntent {
    static let title: LocalizedStringResource = "Freeze Card"
    static let description = IntentDescription("Opens card controls. You confirm the freeze in the app with Face ID.")
    static let openAppWhenRun = true
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Dependency private var router: AppRouter
    @Dependency private var audit: AuditLog

    @MainActor
    func perform() async throws -> some IntentResult {
        router.open(.freezeCard, source: "siri", audit: audit)
        return .result()
    }
}

// MARK: Tier 3

struct PrepareTransferIntent: AppIntent {
    static let title: LocalizedStringResource = "Send Money to Saved Payee"
    static let description = IntentDescription("Prepares a transfer to a saved payee. You review and confirm it in the app with Face ID and PIN.")
    static let openAppWhenRun = true
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Payee")
    var payee: PayeeEntity

    @Parameter(title: "Amount (USD)", requestValueDialog: "How many dollars?")
    var amount: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$amount) dollars to \(\.$payee)")
    }

    @Dependency private var router: AppRouter
    @Dependency private var audit: AuditLog

    @MainActor
    func perform() async throws -> some IntentResult {
        // Amount goes to the review screen only; it is never spoken back or executed here.
        let decimal = Decimal(string: String(format: "%.2f", amount)) ?? Decimal(amount)
        router.open(.transfer(payee: payee.name, amount: decimal), source: "siri", audit: audit)
        return .result()
    }
}
