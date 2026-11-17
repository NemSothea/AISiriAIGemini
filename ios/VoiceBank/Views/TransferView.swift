import SwiftUI

// Tier 3 — voice prepares, app confirms. Saved payees only; biometric + PIN to submit.

struct TransferView: View {
    let prefillPayee: String?
    let prefillAmount: Decimal?

    @Environment(BankStore.self) private var bank
    @Environment(AuditLog.self) private var audit

    private enum Step {
        case form
        case review(TransferDraft)
        case done(Transaction)
    }

    @State private var payeeID: String?
    @State private var amountText = ""
    @State private var step: Step = .form
    @State private var pin = ""
    @State private var showPIN = false
    @State private var error: String?
    @State private var didPrefill = false

    var body: some View {
        Form {
            switch step {
            case .form: formSection
            case .review(let draft): reviewSection(draft)
            case .done(let tx): doneSection(tx)
            }
            if let error {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Transfer")
        .onAppear(perform: prefill)
        .sheet(isPresented: $showPIN) { pinSheet }
    }

    // MARK: Steps

    @ViewBuilder private var formSection: some View {
        Section("To (saved payees only)") {
            Picker("Payee", selection: $payeeID) {
                Text("Choose…").tag(String?.none)
                ForEach(bank.payees) { payee in
                    Text("\(payee.name) · \(payee.bank) \(payee.maskedAccount)").tag(Optional(payee.id))
                }
            }
        }
        Section {
            TextField("Amount (USD)", text: $amountText)
                .keyboardType(.decimalPad)
        } footer: {
            Text("Limit \(BankStore.transferCap.formatted(.currency(code: "USD"))) per transfer in this demo.")
        }
        Section {
            Button("Review") { review() }
                .disabled(payeeID == nil || amountText.isEmpty)
        }
    }

    @ViewBuilder private func reviewSection(_ draft: TransferDraft) -> some View {
        Section("Review") {
            LabeledContent("To", value: draft.payee.name)
            LabeledContent("Account", value: "\(draft.payee.bank) \(draft.payee.maskedAccount)")
            LabeledContent("Amount", value: draft.amount.formatted(.currency(code: draft.currency)))
            LabeledContent("Expires in") { Text(draft.expiresAt, style: .timer) }
        }
        Section {
            Button("Confirm with Face ID + PIN") { Task { await confirm(draft) } }
                .buttonStyle(.borderedProminent)
            Button("Cancel", role: .cancel) {
                audit.record(source: "app", action: "prepareTransfer", tier: .authConfirm, result: "cancelled")
                step = .form
            }
        }
    }

    @ViewBuilder private func doneSection(_ tx: Transaction) -> some View {
        Section {
            Label("Transfer sent (demo)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            LabeledContent("Detail", value: tx.detail)
            LabeledContent("Amount", value: tx.amount.formatted(.currency(code: tx.currency)))
            LabeledContent("Reference", value: String(tx.id.prefix(8)))
        }
    }

    private var pinSheet: some View {
        NavigationStack {
            Form {
                SecureField("Demo PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                Button("Submit") { submitWithPIN() }
                    .disabled(pin.count < 4)
            }
            .navigationTitle("Enter PIN")
            .toolbar {
                Button("Cancel") { showPIN = false; pin = "" }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: Actions

    private func prefill() {
        guard !didPrefill else { return }
        didPrefill = true
        if let name = prefillPayee {
            if let payee = bank.payee(named: name) {
                payeeID = payee.id
            } else {
                error = "\"\(name)\" is not a saved payee. Voice transfers only go to saved payees."
                audit.record(source: "app", action: "prepareTransfer", tier: .authConfirm, result: "unknown_payee")
            }
        }
        if let amount = prefillAmount { amountText = "\(amount)" }
    }

    private func review() {
        error = nil
        guard let payeeID, let amount = Decimal(string: amountText) else {
            error = BankStore.BankError.invalidAmount.localizedDescription
            return
        }
        do {
            step = .review(try bank.createDraft(payeeID: payeeID, amount: amount))
            audit.record(source: "app", action: "prepareTransfer", tier: .authConfirm, result: "draft_created")
        } catch {
            self.error = error.localizedDescription
            audit.record(source: "app", action: "prepareTransfer", tier: .authConfirm, result: "draft_rejected")
        }
    }

    private func confirm(_ draft: TransferDraft) async {
        error = nil
        guard !draft.isExpired else {
            error = BankStore.BankError.draftExpired.localizedDescription
            step = .form
            return
        }
        do {
            try await AuthGate.authenticate(reason: "Confirm transfer to \(draft.payee.name)")
            pin = ""
            showPIN = true
        } catch {
            self.error = error.localizedDescription
            audit.record(source: "app", action: "submitTransfer", tier: .authConfirm, result: "auth_failed")
        }
    }

    private func submitWithPIN() {
        guard case .review(let draft) = step else { return }
        defer { pin = "" }
        do {
            try AuthGate.verifyPIN(pin)
            let tx = try bank.submit(draft)
            showPIN = false
            step = .done(tx)
            audit.record(source: "app", action: "submitTransfer", tier: .authConfirm, result: "success")
        } catch {
            showPIN = false
            self.error = error.localizedDescription
            audit.record(source: "app", action: "submitTransfer", tier: .authConfirm, result: "failed")
        }
    }
}
