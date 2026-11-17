import AppIntents
import SwiftUI

@main
struct VoiceBankApp: App {
    @State private var bank: BankStore
    @State private var audit: AuditLog
    @State private var router: AppRouter

    init() {
        let bank = BankStore()
        let audit = AuditLog()
        let router = AppRouter()
        _bank = State(initialValue: bank)
        _audit = State(initialValue: audit)
        _router = State(initialValue: router)

        // Same instances for the UI and Siri intents (single action layer).
        AppDependencyManager.shared.add(dependency: bank)
        AppDependencyManager.shared.add(dependency: audit)
        AppDependencyManager.shared.add(dependency: router)
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(bank)
                .environment(audit)
                .environment(router)
                .onOpenURL { url in
                    guard let action = BankAction(url: url) else {
                        audit.record(source: "deeplink", action: "unknown", tier: .publicInfo, result: "rejected")
                        return
                    }
                    router.open(action, source: "deeplink", audit: audit)
                }
        }
    }
}
