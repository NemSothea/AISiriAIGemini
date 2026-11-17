import Foundation

/// Rule-based parser for the in-app voice fallback (PLAN.md §5, Approach 3).
/// Same rules and order as Android's VoiceCommandParser — keep them in sync.
/// No LLM, no network: only maps a transcript to a BankAction. Auth still happens on the screen it opens.
enum VoiceCommandParser {
    static func parse(_ text: String, payeeNames: [String]) -> BankAction? {
        let t = " " + text.lowercased() + " "
        func has(_ words: String...) -> Bool { words.contains { t.contains($0) } }

        if has(" qr", "receive", "pay me") { return .showQR }
        if has("send", "transfer", " pay ") {
            let payee = payeeNames.first { t.contains(" \($0.lowercased()) ") }
            return .transfer(payee: payee, amount: firstAmount(in: t))
        }
        if has("freeze", "lock my card", "block my card") { return .freezeCard }
        if has("balance", "how much money") { return .balance }
        if has("exchange", " rate") { return .rates }
        if has("atm", "branch") { return .branches }
        return nil
    }

    private static func firstAmount(in text: String) -> Decimal? {
        guard let match = text.firstMatch(of: /(\d+(?:\.\d{1,2})?)/) else { return nil }
        return Decimal(string: String(match.1))
    }
}
