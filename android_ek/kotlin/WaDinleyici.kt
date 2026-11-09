package com.kones.on_muhasebe

import android.app.Notification
import android.app.Person
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/**
 * WhatsApp bildirimlerini dinler. Sadece kullanıcının seçtiği sohbetlerden gelen mesajları
 * telefonda saklar; uygulama açıldığında Dart tarafı bunları alıp veritabanına yazar.
 * Uygulama kapalıyken de çalışır (Android bildirim erişimi izni gerekir).
 */
class WaDinleyici : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            if (sbn.packageName != "com.whatsapp" && sbn.packageName != "com.whatsapp.w4b") return
            val ex = sbn.notification.extras ?: return
            val baslik = (ex.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
                ?: ex.getCharSequence(Notification.EXTRA_TITLE))?.toString() ?: return
            // "Grup (3 mesaj)" gibi ekleri temizle
            val sohbet = baslik.replace(Regex("\\s*\\(\\d+[^)]*\\)\\s*$"), "").trim()
            if (sohbet.isEmpty() || sohbet == "WhatsApp") return
            gorulenEkle(this, sohbet)
            if (!takip(this).contains(sohbet)) return

            val mesajlar = ex.getParcelableArray(Notification.EXTRA_MESSAGES)
            if (mesajlar != null && mesajlar.isNotEmpty()) {
                for (p in mesajlar) {
                    val b = p as? Bundle ?: continue
                    val metin = b.getCharSequence("text")?.toString() ?: continue
                    var kisi = b.getCharSequence("sender")?.toString()
                    if (kisi == null && Build.VERSION.SDK_INT >= 28) {
                        @Suppress("DEPRECATION")
                        val pr: Person? = if (Build.VERSION.SDK_INT >= 33) b.getParcelable("sender_person", Person::class.java)
                        else b.getParcelable<Person>("sender_person")
                        kisi = pr?.name?.toString()
                    }
                    kaydet(this, sohbet, kisi ?: sohbet, metin, b.getLong("time", sbn.postTime))
                }
            } else {
                val metin = (ex.getCharSequence(Notification.EXTRA_BIG_TEXT)
                    ?: ex.getCharSequence(Notification.EXTRA_TEXT))?.toString() ?: return
                kaydet(this, sohbet, ex.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: sohbet, metin, sbn.postTime)
            }
        } catch (e: Exception) {
        }
    }

    companion object {
        private const val AYAR = "wa_ayar"
        private const val AZAMI = 3000
        private val kilit = Any()

        private fun sp(c: Context) = c.getSharedPreferences(AYAR, Context.MODE_PRIVATE)

        fun takip(c: Context): Set<String> = sp(c).getStringSet("takip", emptySet()) ?: emptySet()

        fun takipYaz(c: Context, l: Set<String>) {
            sp(c).edit().putStringSet("takip", HashSet(l)).apply()
        }

        fun gorulenler(c: Context): List<String> {
            val a = JSONArray(sp(c).getString("gorulen", "[]"))
            return (0 until a.length()).map { a.getString(it) }
        }

        private fun gorulenEkle(c: Context, s: String) {
          synchronized(kilit) {
            val l = gorulenler(c).toMutableList()
            if (l.firstOrNull() == s) return
            l.remove(s)
            l.add(0, s)
            sp(c).edit().putString("gorulen", JSONArray(l.take(100)).toString()).apply()
          }
        }

        private fun kaydet(c: Context, sohbet: String, kisi: String, metin: String, zaman: Long) {
          synchronized(kilit) {
            val a = JSONArray(sp(c).getString("mesajlar", "[]"))
            val anahtar = "$sohbet|$kisi|$zaman|${metin.take(200)}"
            for (i in 0 until a.length()) if (a.getJSONObject(i).optString("anahtar") == anahtar) return
            a.put(JSONObject().put("anahtar", anahtar).put("sohbet", sohbet).put("kisi", kisi).put("metin", metin).put("zaman", zaman))
            val son = if (a.length() > AZAMI) JSONArray((a.length() - AZAMI until a.length()).map { a.getJSONObject(it) }) else a
            sp(c).edit().putString("mesajlar", son.toString()).apply()
          }
        }

        /** Saklanan mesajları döner ve temizler. */
        fun mesajlariAl(c: Context): List<Map<String, Any>> = synchronized(kilit) {
            val a = JSONArray(sp(c).getString("mesajlar", "[]"))
            val l = (0 until a.length()).map {
                val o = a.getJSONObject(it)
                mapOf<String, Any>(
                    "anahtar" to o.getString("anahtar"), "sohbet" to o.getString("sohbet"),
                    "kisi" to o.getString("kisi"), "metin" to o.getString("metin"), "zaman" to o.getLong("zaman"),
                )
            }
            sp(c).edit().putString("mesajlar", "[]").apply()
            l
        }
    }
}
