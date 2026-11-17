package com.example.voicebank.model

import java.math.BigDecimal
import java.time.Instant
import java.util.UUID

// Domain model — PLAN.md §4. Same shape as iOS. Demo data only.

data class Account(
    val id: String,
    val name: String,
    val maskedNumber: String,
    val currency: String,
    val balance: BigDecimal,
)

data class Payee(
    val id: String,
    val name: String,
    val bank: String,
    val maskedAccount: String,
)

data class ExchangeRate(
    val pair: String,
    val buy: BigDecimal,
    val sell: BigDecimal,
    val asOf: Instant,
)

data class Branch(
    val id: String,
    val name: String,
    val type: String, // "atm" | "branch"
    val address: String,
    val lat: Double,
    val lng: Double,
)

data class Card(
    val id: String,
    val name: String,
    val maskedNumber: String,
    val frozen: Boolean,
)

data class Transaction(
    val id: String,
    val date: Instant,
    val detail: String,
    val amount: BigDecimal,
    val currency: String,
)

/** Voice-prepared transfer. Saved payees only, capped, short-lived, single use. */
data class TransferDraft(
    val id: String = UUID.randomUUID().toString(),
    val payee: Payee,
    val amount: BigDecimal,
    val currency: String = "USD",
    val expiresAt: Instant,
) {
    val isExpired: Boolean get() = !Instant.now().isBefore(expiresAt)
}

/** Security tier — PLAN.md §1. */
enum class Tier(val label: String) {
    PUBLIC("Public"),
    AUTH_VIEW("Biometric"),
    AUTH_CONFIRM("Biometric + PIN"),
}
