package com.kones.on_muhasebe

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kones/wa").setMethodCallHandler { call, result ->
            when (call.method) {
                "izinVarMi" -> result.success(izinVar())
                "izinAc" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
                "takipOku" -> result.success(WaDinleyici.takip(this).toList())
                "takipAyarla" -> {
                    val l = call.argument<List<String>>("liste") ?: emptyList()
                    WaDinleyici.takipYaz(this, l.toSet())
                    result.success(null)
                }
                "gorulenler" -> result.success(WaDinleyici.gorulenler(this))
                "mesajlar" -> result.success(WaDinleyici.mesajlariAl(this))
                else -> result.notImplemented()
            }
        }
    }

    private fun izinVar(): Boolean {
        val s = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        val bu = ComponentName(this, WaDinleyici::class.java).flattenToString()
        return s.split(":").any { it == bu }
    }
}
