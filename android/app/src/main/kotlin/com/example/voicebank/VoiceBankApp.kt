package com.example.voicebank

import android.app.Application
import android.content.Context
import com.example.voicebank.model.AuditLog
import com.example.voicebank.model.BankRepository

/** Holds the single action layer shared by UI, deep links and AppFunctions. */
class VoiceBankApp : Application() {
    lateinit var bank: BankRepository
        private set
    lateinit var audit: AuditLog
        private set

    override fun onCreate() {
        super.onCreate()
        bank = BankRepository(this)
        audit = AuditLog(this)
    }
}

val Context.voiceBank: VoiceBankApp get() = applicationContext as VoiceBankApp
