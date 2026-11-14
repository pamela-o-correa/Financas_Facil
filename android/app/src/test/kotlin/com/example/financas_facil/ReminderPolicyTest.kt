package com.example.financas_facil

import org.junit.Assert.*
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class ReminderPolicyTest {
    private fun reminder(id: Long, time: Long) = ReminderPolicy.Reminder("1", id, "Titulo", "Texto", time)

    @Test fun includesDueWindowAndChoosesNext() {
        val items = listOf(reminder(1, 90), reminder(2, 100), reminder(3, 110), reminder(4, 120))
        val plan = ReminderPolicy.plan(items, emptySet(), 100, 90, true)
        assertEquals(listOf(items[0], items[1]), plan.due)
        assertEquals(110L, plan.next)
    }
    @Test fun deliveredRemindersAreNotRepeated() {
        val item = reminder(1, 100)
        val plan = ReminderPolicy.plan(listOf(item), setOf(item.fingerprint, "agenda:1:2:80"), 100, 90, true)
        assertTrue(plan.due.isEmpty())
        assertNull(plan.next)
        assertEquals(setOf("agenda:1:2:80"), plan.obsolete)
    }
    @Test fun permissionDeniedDoesNotDeliverOrSchedule() {
        val plan = ReminderPolicy.plan(listOf(reminder(1, 100), reminder(2, 120)), emptySet(), 100, 90, false)
        assertTrue(plan.due.isEmpty())
        assertNull(plan.next)
    }
    @Test fun rescheduleAfterBootDoesNotReplayPastReminders() {
        val plan = ReminderPolicy.plan(listOf(reminder(1, 90), reminder(2, 120)), emptySet(), 100, null, true)
        assertTrue(plan.due.isEmpty())
        assertEquals(120L, plan.next)
    }
    @Test fun profileAndTimeChangesHaveDistinctFingerprints() {
        val one = reminder(1, 100)
        assertNotEquals(one.fingerprint, one.copy(profile = "2").fingerprint)
        assertNotEquals(one.fingerprint, one.copy(time = 101).fingerprint)
    }
    @Test fun incompleteReadCannotProduceCancellationPlan() {
        var scheduled = false
        try {
            val items = ReminderPolicy.readComplete(listOf("ok", "locked")) {
                if (it == "locked") error("Falha de leitura")
                listOf(reminder(1, 100))
            }
            ReminderPolicy.plan(items, emptySet(), 100, 90, true)
            scheduled = true
            fail("Uma leitura parcial nao pode ser tratada como sucesso")
        } catch (_: IllegalStateException) {
            assertFalse(scheduled)
        }
    }
    @Test fun leapDayAndPreviousDayRespectLocalTime() {
        val previous = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("America/Cuiaba"))
            val value = ReminderPolicy.reminderTime("2024-03-01", 1, 9, 30)
            val calendar = Calendar.getInstance().apply { timeInMillis = value }
            assertEquals(29, calendar.get(Calendar.DAY_OF_MONTH))
            assertEquals(Calendar.FEBRUARY, calendar.get(Calendar.MONTH))
            assertEquals(9, calendar.get(Calendar.HOUR_OF_DAY))
            assertEquals(30, calendar.get(Calendar.MINUTE))
        } finally { TimeZone.setDefault(previous) }
    }
    @Test fun rejectsInvalidDatesAndHours() {
        for (date in listOf("2026-02-31", "2026-13-01", "2026-2-01", "invalid")) {
            try { ReminderPolicy.reminderTime(date, 0, 9, 0); fail(date) }
            catch (_: IllegalArgumentException) {} catch (_: java.text.ParseException) {}
        }
        for (hour in listOf(-1, 24)) {
            try { ReminderPolicy.reminderTime("2026-11-14", 0, hour, 0); fail("Hora invalida") }
            catch (_: IllegalArgumentException) {}
        }
    }
}
