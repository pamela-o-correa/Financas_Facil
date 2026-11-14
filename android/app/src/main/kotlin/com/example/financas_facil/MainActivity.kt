package com.example.financas_facil

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.net.toUri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "financas_facil/agenda")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(AgendaNotifications.enabled(this))
                    "permitir" -> requestNotifications(result)
                    "sincronizar" -> AgendaNotifications.runAsync {
                        try {
                            AgendaNotifications.synchronize(applicationContext)
                            runOnUiThread { result.success(null) }
                        } catch (error: Exception) {
                            runOnUiThread { result.error("agenda_sync", "Não foi possível agendar os lembretes.", null) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        AgendaNotifications.createChannel(this)
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            if (permissionResult != null) {
                result.error("permission_pending", "Há uma solicitação de permissão aberta.", null)
                return
            }
            permissionResult = result
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4101)
            return
        }
        if (!AgendaNotifications.enabled(this)) {
            val settings = if (Build.VERSION.SDK_INT >= 26) {
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    .putExtra(Settings.EXTRA_CHANNEL_ID, AgendaNotifications.CHANNEL)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    "package:$packageName".toUri())
            }
            startActivity(settings)
        }
        result.success(AgendaNotifications.enabled(this))
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4101) {
            permissionResult?.success(AgendaNotifications.enabled(this))
            permissionResult = null
            AgendaNotifications.refresh(applicationContext)
        }
    }

    override fun onResume() {
        super.onResume()
        AgendaNotifications.refresh(applicationContext)
    }

    override fun onDestroy() {
        permissionResult?.error("activity_closed", "A solicitação foi interrompida.", null)
        permissionResult = null
        super.onDestroy()
    }
}
