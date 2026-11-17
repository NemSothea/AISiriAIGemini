import SwiftUI

/// Mic sheet: listen → parse → open the matching screen (source "voice").
/// Tier 2–3 screens still require Face ID (+PIN) exactly as for touch.
struct VoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BankStore.self) private var bank
    @Environment(AuditLog.self) private var audit
    @Environment(AppRouter.self) private var router
    @State private var listener = VoiceListener()
    @State private var notUnderstood = false

    private let examples = [
        "Show my QR",
        "Exchange rate",
        "Find nearest ATM",
        "Check my balance",
        "Freeze my card",
        "Send 20 dollars to Dara",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: listener.isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 56))
                    .symbolEffect(.variableColor.iterative, isActive: listener.isListening)
                    .foregroundStyle(listener.isListening ? .red : .accentColor)

                Text(listener.transcript.isEmpty ? (listener.isListening ? "Listening…" : "Tap the mic and speak") : listener.transcript)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 60)

                if let error = listener.error {
                    Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
                } else if notUnderstood {
                    Text("Sorry, I didn't catch a banking command. Try one below.")
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }

                Button(listener.isListening ? "Done" : "Start listening") {
                    if listener.isListening {
                        listener.stop()
                    } else {
                        notUnderstood = false
                        Task { await listener.start() }
                    }
                }
                .buttonStyle(.borderedProminent)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Try saying").font(.caption).foregroundStyle(.secondary)
                    ForEach(examples, id: \.self) { Text("“\($0)”").font(.callout) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Speech is processed on this device only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Close") {
                    listener.cancel()
                    dismiss()
                }
            }
        }
        .task { await listener.start() }
        .onChange(of: listener.isFinal) { _, final in
            if final { handle(listener.transcript) }
        }
        .onChange(of: listener.isListening) { wasListening, listening in
            // User tapped Done before the recognizer marked the result final.
            if wasListening, !listening, !listener.transcript.isEmpty, !listener.isFinal {
                handle(listener.transcript)
            }
        }
        .onDisappear { listener.cancel() }
    }

    private func handle(_ transcript: String) {
        guard !transcript.isEmpty else { return }
        // Transcript text is never written to the audit log.
        guard let action = VoiceCommandParser.parse(transcript, payeeNames: bank.payees.map(\.name)) else {
            notUnderstood = true
            audit.record(source: "voice", action: "unknown", tier: .publicInfo, result: "not_understood")
            return
        }
        dismiss()
        router.open(action, source: "voice", audit: audit)
    }
}
