import SwiftUI
import CoreImage.CIFilterBuiltins

// Tier 1 — public / receive-only. No authentication.

struct QRView: View {
    /// Static sample payload. Real KHQR needs Bakong/KHQR SDK access (PLAN.md §4).
    private let payload = "DEMO-KHQR-SAMPLE-NOT-FOR-PAYMENT"

    var body: some View {
        VStack(spacing: 20) {
            if let image = Self.qrImage(payload) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .padding()
                    .background(.white, in: .rect(cornerRadius: 16))
            }
            Text("Scan to pay me").font(.headline)
            Text("Sample QR — not a valid KHQR")
                .font(.footnote)
                .foregroundStyle(.red)
        }
        .padding()
        .navigationTitle("Receive")
    }

    private static func qrImage(_ string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct RatesView: View {
    @Environment(BankStore.self) private var bank

    var body: some View {
        List {
            Section {
                ForEach(bank.rates) { rate in
                    HStack {
                        Text(rate.pair).font(.headline)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Buy \(rate.buy.formatted())")
                            Text("Sell \(rate.sell.formatted())").foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                if let asOf = bank.rates.first?.asOf {
                    Text("Demo rates, not live · as of \(asOf.formatted(date: .abbreviated, time: .shortened))")
                }
            }
        }
        .navigationTitle("Exchange Rates")
    }
}

struct BranchesView: View {
    @Environment(BankStore.self) private var bank

    var body: some View {
        List {
            Section {
                ForEach(bank.nearestBranches(), id: \.0.id) { branch, km in
                    HStack {
                        Image(systemName: branch.type == "atm" ? "banknote" : "building.columns")
                        VStack(alignment: .leading) {
                            Text(branch.name)
                            Text(branch.address).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(km.formatted(.number.precision(.fractionLength(1))) + " km")
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Distances from a fixed demo location (Wat Phnom). Locations are fictional.")
            }
        }
        .navigationTitle("ATM & Branches")
    }
}
