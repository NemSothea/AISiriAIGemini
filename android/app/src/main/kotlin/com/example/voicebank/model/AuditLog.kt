package com.example.voicebank.model

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.util.UUID

data class AuditEvent(
    val id: String = UUID.randomUUID().toString(),
    val timestamp: Instant,
    val source: String, // touch | deeplink | agent | app
    val action: String,
    val tier: Tier,
    val result: String,
)

/**
 * Records every action and its outcome (PLAN.md §6.5). Persisted to app-private storage.
 * Never store balances or full account numbers here.
 */
class AuditLog(context: Context) {
    private val file = File(context.filesDir, "audit_log.json")
    private val _events = MutableStateFlow(load())
    val events: StateFlow<List<AuditEvent>> = _events.asStateFlow()

    @Synchronized
    fun record(source: String, action: String, tier: Tier, result: String) {
        _events.value = listOf(AuditEvent(timestamp = Instant.now(), source = source, action = action,
            tier = tier, result = result)) + _events.value
        save()
    }

    @Synchronized
    fun clear() {
        _events.value = emptyList()
        save()
    }

    private fun load(): List<AuditEvent> = runCatching {
        val array = JSONArray(file.readText())
        (0 until array.length()).map { i ->
            val o = array.getJSONObject(i)
            AuditEvent(o.getString("id"), Instant.parse(o.getString("timestamp")), o.getString("source"),
                o.getString("action"), Tier.valueOf(o.getString("tier")), o.getString("result"))
        }
    }.getOrDefault(emptyList())

    private fun save() {
        val array = JSONArray()
        _events.value.forEach {
            array.put(JSONObject().apply {
                put("id", it.id); put("timestamp", it.timestamp.toString()); put("source", it.source)
                put("action", it.action); put("tier", it.tier.name); put("result", it.result)
            })
        }
        file.writeText(array.toString())
    }
}
