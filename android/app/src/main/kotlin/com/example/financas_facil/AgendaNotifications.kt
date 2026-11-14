package com.example.financas_facil

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import androidx.core.net.toUri
import android.os.Build
import android.util.Log
import com.example.financas_facil.ReminderPolicy.Reminder
import java.util.concurrent.Executors

/** O banco financeiro é somente lido; o agendamento não cria movimentações. */
object AgendaNotifications {
    const val CHANNEL = "compromissos_financeiros"
    const val ACTION = "com.example.financas_facil.AGENDA_REMINDER"
    private const val PREFS = "agenda_notifications"
    private const val NEXT = "next_alarm"
    private val executor = Executors.newSingleThreadExecutor()

    fun runAsync(block: () -> Unit) { executor.execute(block) }
    fun refresh(context: Context) = runAsync {
        try { synchronize(context) }
        catch (error: Exception) { Log.e("Agenda", "Falha ao sincronizar lembretes", error) }
    }

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(CHANNEL, "Compromissos financeiros", NotificationManager.IMPORTANCE_DEFAULT)
            channel.description = "Lembretes de contas a pagar e valores a receber"
            channel.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    fun enabled(context: Context): Boolean {
        createChannel(context)
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!manager.areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(CHANNEL).importance != NotificationManager.IMPORTANCE_NONE
    }

    private fun alarmIntent(context: Context, time: Long = 0): PendingIntent = PendingIntent.getBroadcast(
        context, 4102, Intent(context, AgendaReminderReceiver::class.java).setAction(ACTION).putExtra(NEXT, time),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    /** Um único alarme para o próximo horário evita limites de alarmes por fabricante. */
    fun synchronize(context: Context, dueFrom: Long? = null, recoverDue: Boolean = true) {
        createChannel(context)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val reminders = readReminders(context)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        val scheduled = prefs.getLong(NEXT, 0)
        val due = dueFrom ?: scheduled.takeIf { recoverDue && it > 0 && it <= now }
        val delivered = prefs.getStringSet("delivered", emptySet())!!.toMutableSet()
        val plan = ReminderPolicy.plan(reminders, delivered, now, due, enabled(context))
        for (old in plan.obsolete) {
            manager.cancel(old.substringBeforeLast(':'), 0)
            delivered.remove(old)
        }
        for (item in plan.due) {
            show(context, item)
            delivered.add(item.fingerprint)
        }
        val next = plan.next
        // Persistência antes de confirmar o canal ao Flutter; falhas são exibidas na agenda.
        if (!prefs.edit().putStringSet("delivered", delivered).putLong(NEXT, next ?: 0).commit()) {
            throw IllegalStateException("Não foi possível salvar o agendamento")
        }
        alarm.cancel(alarmIntent(context))
        if (next != null) {
            // Alarmes inexatos não exigem acesso especial. O Android pode atrasar a entrega em economia de bateria.
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, alarmIntent(context, next))
        }
    }

    fun receive(context: Context, intent: Intent) {
        val expected = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(NEXT, 0)
        if (intent.action == ACTION) {
            val due = intent.getLongExtra(NEXT, 0)
            if (due == 0L || due != expected) return
            synchronize(context, due)
        } else {
            // Após reiniciar ou mudar relógio/fuso, reagenda o futuro, sem repetir avisos passados.
            synchronize(context, recoverDue = false)
        }
    }

    @Suppress("DEPRECATION") // Compatibilidade com Android 7, sem NotificationChannel.
    private fun show(context: Context, reminder: Reminder) {
        val tap = PendingIntent.getActivity(context, reminder.tag.hashCode(),
            Intent(context, MainActivity::class.java)
                .setData("financas-facil://lembrete/${reminder.profile}/${reminder.id}".toUri())
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        val notification = builder.setSmallIcon(R.drawable.ic_notification_agenda)
            .setContentTitle(reminder.title).setContentText(reminder.text)
            .setStyle(Notification.BigTextStyle().bigText(reminder.text))
            .setCategory(Notification.CATEGORY_REMINDER).setVisibility(Notification.VISIBILITY_PRIVATE)
            .setOnlyAlertOnce(true).setAutoCancel(true).setContentIntent(tap).build()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(reminder.tag, 0, notification)
    }

    private fun readReminders(context: Context): List<Reminder> {
        val directory = requireNotNull(context.getDatabasePath("financas_facil.db").parentFile)
        if (!directory.exists()) return emptyList()
        val files = directory.listFiles()?.filter {
            it.name == "financas_facil.db" || Regex("financas_perfil_\\d+\\.db").matches(it.name)
        } ?: throw IllegalStateException("Nao foi possivel listar os bancos de lembretes")
        val names = mutableMapOf("1" to "Pessoal")
        val profiles = context.getDatabasePath("financas_perfis.db")
        if (profiles.exists()) {
            try {
                SQLiteDatabase.openDatabase(profiles.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                    db.rawQuery("SELECT id, nome FROM perfis", null).use { cursor ->
                        while (cursor.moveToNext()) names[cursor.getLong(0).toString()] = cursor.getString(1)
                    }
                }
            } catch (error: Exception) {
                Log.w("Agenda", "Nomes de perfis indisponiveis; usando identificadores", error)
            }
        }
        return ReminderPolicy.readComplete(files) { file ->
            val result = mutableListOf<Reminder>()
            val profile = if (file.name == "financas_facil.db") "1" else file.name.removePrefix("financas_perfil_").removeSuffix(".db")
            try {
                SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                    val exists = db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='agenda'", null).use { it.moveToFirst() }
                    if (!exists) return@use
                    db.rawQuery("SELECT id, titulo, tipo, data, lembrete, hora, minuto FROM agenda WHERE status='pendente' AND lembrete IS NOT NULL", null).use { cursor ->
                        while (cursor.moveToNext()) {
                            try {
                                val date = cursor.getString(3)
                                val time = ReminderPolicy.reminderTime(date, cursor.getInt(4), cursor.getInt(5), cursor.getInt(6))
                                val formatted = date.split('-').reversed().joinToString("/")
                                result.add(Reminder(profile, cursor.getLong(0),
                                    "${if (cursor.getString(2) == "receita") "A receber" else "A pagar"} • ${names[profile] ?: "Perfil $profile"}",
                                    "${cursor.getString(1)} • vence em $formatted", time))
                            } catch (error: Exception) {
                                Log.w("Agenda", "Lembrete invalido ignorado", error)
                            }
                        }
                    }
                }
            } catch (error: Exception) {
                // Nao retornar lista parcial: synchronize preserva alarmes e preferencias.
                throw IllegalStateException("Nao foi possivel ler os lembretes", error)
            }
            result
        }
    }

    fun retry(context: Context) {
        val expected = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(NEXT, 0)
        if (expected <= 0 || !enabled(context)) return
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // Preserva o horario original no Intent para recuperar vencidos sem duplicar.
        alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis() + 5 * 60_000, alarmIntent(context, expected))
    }
}

class AgendaReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            AgendaNotifications.ACTION, Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED, Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> Unit
            else -> return
        }
        val pending = goAsync()
        AgendaNotifications.runAsync {
            try { AgendaNotifications.receive(context.applicationContext, intent) }
            catch (error: Exception) {
                Log.e("Agenda", "Falha ao processar lembrete", error)
                try { AgendaNotifications.retry(context.applicationContext) }
                catch (retryError: Exception) { Log.e("Agenda", "Falha ao reagendar tentativa", retryError) }
            }
            finally { pending.finish() }
        }
    }
}
