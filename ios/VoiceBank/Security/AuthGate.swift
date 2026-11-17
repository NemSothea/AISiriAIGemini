import Foundation
import LocalAuthentication

/// Tier 2: biometric (passcode fallback). Tier 3: biometric + app PIN.
/// No bypass in any build — in Simulator enable Features ▸ Face ID ▸ Enrolled.
enum AuthGate {
    /// Demo-only PIN. A production app would verify server-side.
    static let demoPIN = "1234"

    enum AuthError: LocalizedError {
        case unavailable(String)
        case wrongPIN

        var errorDescription: String? {
            switch self {
            case .unavailable(let reason):
                "Device authentication unavailable: \(reason). In Simulator: Features ▸ Face ID ▸ Enrolled."
            case .wrongPIN:
                "Incorrect PIN."
            }
        }
    }

    static func authenticate(reason: String) async throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw AuthError.unavailable(error?.localizedDescription ?? "unknown")
        }
        try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }

    static func verifyPIN(_ pin: String) throws {
        guard pin == demoPIN else { throw AuthError.wrongPIN }
    }
}
