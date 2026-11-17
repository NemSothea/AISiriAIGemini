import SwiftUI

// Tier 2 — biometric required; data shown in-app only.

/// Locks content behind device auth. Re-locks when the app goes to background.
struct AuthLocked<Content: View>: View {
    let reason: String
    let action: String
    let tier: Tier
    @ViewBuilder let content: () -> Content

    @Environment(AuditLog.self) private var audit
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    @State private var error: String?

    var body: some View {
        Group {
            if unlocked {
                content()
            } else {
                ContentUnavailableView {
                    Label("Locked", systemImage: "lock.fill")
                } description: {
                    Text(error ?? "Authenticate to continue.")
                } actions: {
                    Button("Unlock") { Task { await unlock() } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .task { await unlock() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { unlocked = false }
        }
    }

    private func unlock() async {
        guard !unlocked else { return }
        do {
            try await AuthGate.authenticate(reason: reason)
            unlocked = true
            error = nil
            audit.record(source: "app", action: action, tier: tier, result: "auth_ok")
        } catch {
            self.error = error.localizedDescription
            audit.record(source: "app", action: action, tier: tier, result: "auth_failed")
        }
    }
}

struct BalanceView: View {
    @Environment(BankStore.self) private var bank

    var body: some View {
        AuthLocked(reason: "View your balance", action: "checkBalance", tier: .authView) {
            List {
                Section("Accounts") {
                    ForEach(bank.accounts) { account in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(account.name)
                                Text(account.maskedNumber).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(account.balance.formatted(.currency(code: account.currency)))
                                .font(.headline)
                        }
                    }
                }
                Section("Recent transactions") {
                    ForEach(bank.transactions.prefix(10)) { tx in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(tx.detail)
                                Text(tx.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(tx.amount.formatted(.currency(code: tx.currency)))
                                .foregroundStyle(tx.amount < 0 ? Color.primary : Color.green)
                        }
                    }
                }
            }
        }
        .navigationTitle("Balance")
    }
}

struct CardView: View {
    @Environment(BankStore.self) private var bank
    @Environment(AuditLog.self) private var audit
    @State private var pendingCard: Card?

    var body: some View {
        AuthLocked(reason: "Manage your card", action: "freezeCard", tier: .authView) {
            List(bank.cards) { card in
                VStack(alignment: .leading, spacing: 12) {
                    Text(card.name).font(.headline)
                    Text(card.maskedNumber).monospaced()
                    Label(card.frozen ? "Frozen" : "Active",
                          systemImage: card.frozen ? "snowflake" : "checkmark.seal")
                        .foregroundStyle(card.frozen ? .blue : .green)
                    Button(card.frozen ? "Unfreeze card" : "Freeze card") { pendingCard = card }
                        .buttonStyle(.borderedProminent)
                        .tint(card.frozen ? .green : .blue)
                }
                .padding(.vertical, 8)
            }
            .confirmationDialog(
                pendingCard?.frozen == true ? "Unfreeze this card?" : "Freeze this card?",
                isPresented: Binding(get: { pendingCard != nil }, set: { if !$0 { pendingCard = nil } }),
                titleVisibility: .visible
            ) {
                Button(pendingCard?.frozen == true ? "Unfreeze" : "Freeze") {
                    if let card = pendingCard { Task { await toggle(card) } }
                }
            }
        }
        .navigationTitle("Card Controls")
    }

    private func toggle(_ card: Card) async {
        let freeze = !card.frozen
        let action = freeze ? "freezeCard" : "unfreezeCard"
        do {
            // Fresh auth for the state change itself, not just for viewing.
            try await AuthGate.authenticate(reason: freeze ? "Freeze your card" : "Unfreeze your card")
            bank.setFrozen(cardID: card.id, freeze)
            audit.record(source: "app", action: action, tier: .authView, result: "success")
        } catch {
            audit.record(source: "app", action: action, tier: .authView, result: "auth_failed")
        }
    }
}
