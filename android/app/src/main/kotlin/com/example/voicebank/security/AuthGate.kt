package com.example.voicebank.security

import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Tier 2: biometric (device credential fallback). Tier 3: biometric + app PIN.
 * No bypass in any build — on an emulator enroll a fingerprint in Settings first.
 */
object AuthGate {
    /** Demo-only PIN. A production app would verify server-side. */
    private const val DEMO_PIN = "1234"
    private const val AUTHENTICATORS = BIOMETRIC_STRONG or DEVICE_CREDENTIAL

    class AuthException(message: String) : Exception(message)

    suspend fun authenticate(activity: FragmentActivity, title: String) {
        val status = BiometricManager.from(activity).canAuthenticate(AUTHENTICATORS)
        if (status != BiometricManager.BIOMETRIC_SUCCESS) {
            throw AuthException("Device authentication unavailable (code $status). Set a screen lock or enroll a fingerprint.")
        }
        suspendCancellableCoroutine { cont ->
            val prompt = BiometricPrompt(
                activity,
                ContextCompat.getMainExecutor(activity),
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                        if (cont.isActive) cont.resume(Unit)
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        if (cont.isActive) cont.resumeWithException(AuthException(errString.toString()))
                    }
                    // onAuthenticationFailed = single bad attempt; prompt stays open, so no-op.
                },
            )
            prompt.authenticate(
                BiometricPrompt.PromptInfo.Builder()
                    .setTitle(title)
                    .setAllowedAuthenticators(AUTHENTICATORS)
                    .build(),
            )
            cont.invokeOnCancellation { prompt.cancelAuthentication() }
        }
    }

    fun verifyPin(pin: String) {
        if (pin != DEMO_PIN) throw AuthException("Incorrect PIN.")
    }
}
