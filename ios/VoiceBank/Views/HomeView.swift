import SwiftUI

struct HomeView: View {
    @Environment(AuditLog.self) private var audit
    @Environment(AppRouter.self) private var router
    @State private var showVoice = false

    private let tiles: [(BankAction, String, String)] = [
        (.showQR, "Receive (KHQR)", "qrcode"),
        (.rates, "Exchange Rates", "dollarsign.arrow.circlepath"),
        (.branches, "ATM & Branches", "mappin.and.ellipse"),
        (.balance, "Balance", "lock.shield"),
        (.freezeCard, "Card Controls", "creditcard"),
        (.transfer(payee: nil, amount: nil), "Transfer", "arrow.left.arrow.right"),
    ]

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            ScrollView {
                Text("Demo build · mock data only")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(tiles, id: \.1) { action, title, icon in
                        Button {
                            router.open(action, source: "touch", audit: audit)
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: icon).font(.title)
                                Text(title).font(.subheadline.weight(.medium))
                                TierBadge(tier: action.tier)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .background(.background.secondary, in: .rect(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("VoiceBank")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showVoice = true
                    } label: {
                        Label("Voice", systemImage: "mic.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Audit") { AuditLogView() }
                }
            }
            .sheet(isPresented: $showVoice) { VoiceSheet() }
            .navigationDestination(for: BankAction.self) { action in
                switch action {
                case .showQR: QRView()
                case .rates: RatesView()
                case .branches: BranchesView()
                case .balance: BalanceView()
                case .freezeCard: CardView()
                case .transfer(let payee, let amount): TransferView(prefillPayee: payee, prefillAmount: amount)
                }
            }
        }
    }
}

struct TierBadge: View {
    let tier: Tier

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: .capsule)
            .foregroundStyle(color)
    }

    private var label: String {
        switch tier {
        case .publicInfo: "Public"
        case .authView: "Face ID"
        case .authConfirm: "Face ID + PIN"
        }
    }

    private var color: Color {
        switch tier {
        case .publicInfo: .green
        case .authView: .orange
        case .authConfirm: .red
        }
    }
}
