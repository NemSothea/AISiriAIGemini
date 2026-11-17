package com.example.voicebank.voice

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.example.voicebank.BankAction
import com.example.voicebank.model.Tier
import com.example.voicebank.voiceBank

private val EXAMPLES = listOf(
    "Show my QR", "Exchange rate", "Find nearest ATM",
    "Check my balance", "Freeze my card", "Send 20 dollars to Dara",
)

/**
 * Mic dialog: listen → parse → open the matching screen (source "voice").
 * ON-DEVICE recognition only (API 31+); if unavailable we refuse rather than send audio to a server.
 * Tier 2–3 screens still require biometrics (+PIN) exactly as for touch.
 */
@Composable
fun VoiceDialog(onAction: (BankAction) -> Unit, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val app = context.voiceBank
    var transcript by remember { mutableStateOf("") }
    var listening by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var recognizer by remember { mutableStateOf<SpeechRecognizer?>(null) }

    fun handle(text: String) {
        if (text.isBlank()) return
        // Transcript text is never written to the audit log.
        val action = VoiceCommandParser.parse(text, app.bank.payees.map { it.name })
        if (action == null) {
            message = "Sorry, I didn't catch a banking command. Try one below."
            app.audit.record("voice", "unknown", Tier.PUBLIC, "not_understood")
        } else {
            onAction(action)
        }
    }

    fun start() {
        message = null
        transcript = ""
        val unavailable = onDeviceUnavailableReason(context)
        if (unavailable != null || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            message = unavailable
            return
        }
        val sr = recognizer ?: SpeechRecognizer.createOnDeviceSpeechRecognizer(context).also { recognizer = it }
        sr.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) { listening = true }
            override fun onPartialResults(partialResults: Bundle?) {
                partialResults.firstResult()?.let { transcript = it }
            }
            override fun onResults(results: Bundle?) {
                listening = false
                results.firstResult()?.let { transcript = it }
                handle(transcript)
            }
            override fun onError(error: Int) {
                listening = false
                message = if (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
                    "Didn't hear anything. Tap Start and try again."
                } else {
                    "Speech recognition error ($error)."
                }
            }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        sr.startListening(
            Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
                .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true),
        )
    }

    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) start() else message = "Microphone permission denied. Enable it in Settings."
    }

    LaunchedEffect(Unit) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            start()
        } else {
            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    DisposableEffect(Unit) {
        onDispose { recognizer?.destroy() }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Voice") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    when {
                        transcript.isNotEmpty() -> transcript
                        listening -> "Listening…"
                        else -> "Tap Start and speak"
                    },
                    style = MaterialTheme.typography.titleMedium,
                )
                message?.let { Text(it, color = Color(0xFFC62828)) }
                Text("Try saying", style = MaterialTheme.typography.labelSmall)
                EXAMPLES.forEach { Text("“$it”", style = MaterialTheme.typography.bodySmall) }
                Text("Speech is processed on this device only.", style = MaterialTheme.typography.labelSmall)
            }
        },
        confirmButton = {
            if (listening) {
                Button(onClick = { recognizer?.stopListening() }) { Text("Done") }
            } else {
                Button(onClick = { permissionLauncher.launch(Manifest.permission.RECORD_AUDIO) }) { Text("Start") }
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Close") } },
    )
}

private fun Bundle?.firstResult(): String? =
    this?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()

private fun onDeviceUnavailableReason(context: Context): String? = when {
    Build.VERSION.SDK_INT < Build.VERSION_CODES.S ->
        "Voice needs Android 12 or later for on-device speech recognition."
    !SpeechRecognizer.isOnDeviceRecognitionAvailable(context) ->
        "On-device speech recognition isn't available on this device, so voice is disabled."
    else -> null
}
