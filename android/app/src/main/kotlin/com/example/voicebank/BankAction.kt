package com.example.voicebank

import android.net.Uri
import com.example.voicebank.model.Tier
import java.math.BigDecimal

/** Canonical actions shared by touch, deep links and AppFunctions — PLAN.md §4. Same names as iOS. */
sealed class BankAction(val name: String, val tier: Tier) {
    data object ShowQR : BankAction("showQR", Tier.PUBLIC)
    data object Rates : BankAction("getRates", Tier.PUBLIC)
    data object Branches : BankAction("findBranch", Tier.PUBLIC)
    data object Balance : BankAction("checkBalance", Tier.AUTH_VIEW)
    data object FreezeCard : BankAction("freezeCard", Tier.AUTH_VIEW)
    data class Transfer(val payee: String? = null, val amount: BigDecimal? = null) :
        BankAction("prepareTransfer", Tier.AUTH_CONFIRM)

    fun toUri(): Uri = when (this) {
        ShowQR -> Uri.parse("voicebank://qr")
        Rates -> Uri.parse("voicebank://rates")
        Branches -> Uri.parse("voicebank://branches")
        Balance -> Uri.parse("voicebank://balance")
        FreezeCard -> Uri.parse("voicebank://freeze")
        is Transfer -> Uri.Builder().scheme("voicebank").authority("transfer").apply {
            payee?.let { appendQueryParameter("payee", it) }
            amount?.let { appendQueryParameter("amount", it.toPlainString()) }
        }.build()
    }

    companion object {
        /** voicebank://qr | rates | branches | balance | freeze | transfer?payee=Dara&amount=20 */
        fun fromUri(uri: Uri): BankAction? {
            if (uri.scheme != "voicebank") return null
            return when (uri.host) {
                "qr" -> ShowQR
                "rates" -> Rates
                "branches" -> Branches
                "balance" -> Balance
                "freeze" -> FreezeCard
                "transfer" -> Transfer(
                    payee = uri.getQueryParameter("payee"),
                    amount = uri.getQueryParameter("amount")?.toBigDecimalOrNull(),
                )
                else -> null
            }
        }
    }
}
