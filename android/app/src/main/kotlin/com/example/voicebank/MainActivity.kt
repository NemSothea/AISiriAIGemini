package com.example.voicebank

import android.content.Intent
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.mutableStateOf
import androidx.fragment.app.FragmentActivity
import com.example.voicebank.ui.VoiceBankRoot

/** FragmentActivity (not ComponentActivity) because BiometricPrompt requires it. */
class MainActivity : FragmentActivity() {

    companion object {
        /** Set only on explicit intents built by our AppFunctions service. */
        const val EXTRA_SOURCE = "com.example.voicebank.SOURCE"
    }

    private val route = mutableStateOf<BankAction?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        handle(intent)
        setContent {
            VoiceBankRoot(
                route = route.value,
                onNavigate = { action -> open(action, "touch") },
                onVoice = { action -> open(action, "voice") },
                onBack = { route.value = null },
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent?) {
        val uri = intent?.data ?: return
        val source = intent.getStringExtra(EXTRA_SOURCE) ?: "deeplink"
        val action = BankAction.fromUri(uri)
        if (action == null) {
            voiceBank.audit.record(source, "unknown", com.example.voicebank.model.Tier.PUBLIC, "rejected")
            return
        }
        open(action, source)
    }

    private fun open(action: BankAction, source: String) {
        voiceBank.audit.record(source, action.name, action.tier, "opened")
        route.value = action
    }
}
