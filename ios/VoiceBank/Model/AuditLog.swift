import Foundation
import Observation

struct AuditEvent: Codable, Identifiable, Sendable {
    var id = UUID()
    let timestamp: Date
    let source: String   // touch | deeplink | app | siri (Phase 2)
    let action: String
    let tier: Tier
    let result: String
}

/// Records every action and its outcome (PLAN.md §6.5). Persisted locally as JSON.
/// Never store balances or full account numbers here.
@MainActor
@Observable
final class AuditLog {
    private(set) var events: [AuditEvent] = []
    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("audit_log.json")
        if let data = try? Data(contentsOf: fileURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            events = (try? decoder.decode([AuditEvent].self, from: data)) ?? []
        }
    }

    func record(source: String, action: String, tier: Tier, result: String) {
        events.insert(AuditEvent(timestamp: .now, source: source, action: action, tier: tier, result: result), at: 0)
        save()
    }

    func clear() {
        events.removeAll()
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(events) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
