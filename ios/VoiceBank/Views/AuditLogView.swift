import SwiftUI

struct AuditLogView: View {
    @Environment(AuditLog.self) private var audit

    var body: some View {
        List {
            if audit.events.isEmpty {
                Text("No events yet.").foregroundStyle(.secondary)
            }
            ForEach(audit.events) { event in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(event.action).font(.headline)
                        Spacer()
                        TierBadge(tier: event.tier)
                    }
                    Text("\(event.source) · \(event.result)")
                        .font(.subheadline)
                    Text(event.timestamp.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Audit Log")
        .toolbar {
            Button("Clear", role: .destructive) { audit.clear() }
                .disabled(audit.events.isEmpty)
        }
    }
}
