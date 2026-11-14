package com.example.financas_facil

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/** Regras puras: nenhuma leitura de banco, permissao ou modificacao de alarme. */
internal object ReminderPolicy {
    data class Reminder(val profile: String, val id: Long, val title: String, val text: String, val time: Long) {
        val tag get() = "agenda:$profile:$id"
        val fingerprint get() = "$tag:$time"
    }
    data class Plan(val due: List<Reminder>, val next: Long?, val obsolete: Set<String>)

    fun plan(reminders: List<Reminder>, delivered: Set<String>, now: Long, dueFrom: Long?, permitted: Boolean): Plan {
        val active = reminders.map { it.fingerprint }.toSet()
        val due = if (permitted && dueFrom != null) reminders.filter {
            it.time in dueFrom..now && it.fingerprint !in delivered
        } else emptyList()
        val next = if (permitted) reminders.filter {
            it.time > now && it.fingerprint !in delivered
        }.minOfOrNull { it.time } else null
        return Plan(due, next, delivered - active)
    }

    /** Uma falha impede o uso de uma lista parcial para cancelar alarmes. */
    fun <T> readComplete(sources: List<T>, read: (T) -> List<Reminder>): List<Reminder> = sources.flatMap(read)

    fun reminderTime(date: String, daysBefore: Int, hour: Int, minute: Int): Long {
        require(daysBefore >= 0 && hour in 0..23 && minute in 0..59)
        val parser = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { isLenient = false }
        require(Regex("\\d{4}-\\d{2}-\\d{2}").matches(date))
        val calendar = Calendar.getInstance().apply {
            time = requireNotNull(parser.parse(date))
            add(Calendar.DAY_OF_MONTH, -daysBefore)
            set(Calendar.HOUR_OF_DAY, hour); set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        return calendar.timeInMillis
    }
}
