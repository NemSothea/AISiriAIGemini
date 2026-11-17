package com.example.voicebank.voice

import com.example.voicebank.BankAction

/**
 * Rule-based parser for the in-app voice fallback (PLAN.md §5, Approach 3).
 * Same rules and order as iOS's VoiceCommandParser — keep them in sync.
 * No LLM, no network: only maps a transcript to a BankAction. Auth still happens on the screen it opens.
 */
object VoiceCommandParser {
    private val amountRegex = Regex("""(\d+(?:\.\d{1,2})?)""")

    fun parse(text: String, payeeNames: List<String>): BankAction? {
        val t = " ${text.lowercase()} "
        fun has(vararg words: String) = words.any { t.contains(it) }

        if (has(" qr", "receive", "pay me")) return BankAction.ShowQR
        if (has("send", "transfer", " pay ")) {
            val payee = payeeNames.firstOrNull { t.contains(" ${it.lowercase()} ") }
            val amount = amountRegex.find(t)?.groupValues?.get(1)?.toBigDecimalOrNull()
            return BankAction.Transfer(payee, amount)
        }
        if (has("freeze", "lock my card", "block my card")) return BankAction.FreezeCard
        if (has("balance", "how much money")) return BankAction.Balance
        if (has("exchange", " rate")) return BankAction.Rates
        if (has("atm", "branch")) return BankAction.Branches
        return null
    }
}
