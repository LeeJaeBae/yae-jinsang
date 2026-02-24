package com.thebespoke.yae_jinsang

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

class JinsangCallScreeningService : CallScreeningService() {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val supabaseUrl = "https://jwxwjgcbarbfigucarod.supabase.co"
    private val supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp3eHdqZ2NiYXJiZmlndWNhcm9kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjUyNTgsImV4cCI6MjA4NzQ0MTI1OH0.YtAbcj3j2AMTgV_iwi9ZgII8x0py0JTShsh0qX-FBGs"

    override fun onScreenCall(callDetails: Call.Details) {
        val number = callDetails.handle?.schemeSpecificPart ?: ""
        val hash = hashPhoneNumber(number)

        Log.d("YaeJinsang", "수신 전화 - hash: $hash")

        // 서버 조회
        scope.launch {
            try {
                val result = lookupJinsang(hash)
                if (result.isNotEmpty()) {
                    Log.d("YaeJinsang", "⚠️ 진상 감지: $result")
                    showWarningOverlay(number, result, isJinsang = true)
                    showNotification(number, result)
                } else {
                    Log.d("YaeJinsang", "✅ 미등록 번호")
                    showWarningOverlay(number, emptyList(), isJinsang = false)
                }
            } catch (e: Exception) {
                Log.e("YaeJinsang", "조회 실패: ${e.message}")
            }
        }

        // 전화는 항상 통과 (차단하지 않음, 경고만)
        val response = CallResponse.Builder()
            .setDisallowCall(false)
            .setRejectCall(false)
            .setSilenceCall(false)
            .setSkipCallLog(false)
            .setSkipNotification(false)
            .build()

        respondToCall(callDetails, response)
    }

    private fun hashPhoneNumber(number: String): String {
        val normalized = number.replace(Regex("[^0-9]"), "")
        val digest = MessageDigest.getInstance("SHA-256")
        val hashBytes = digest.digest(normalized.toByteArray())
        return hashBytes.joinToString("") { "%02x".format(it) }
    }

    private fun lookupJinsang(hash: String): List<Pair<String, Int>> {
        val url = URL("$supabaseUrl/rest/v1/rpc/lookup_jinsang")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("apikey", supabaseKey)
        conn.setRequestProperty("Content-Type", "application/json")
        conn.doOutput = true

        val body = """{"p_hash": "$hash"}"""
        conn.outputStream.write(body.toByteArray())

        val response = conn.inputStream.bufferedReader().readText()
        conn.disconnect()

        val results = mutableListOf<Pair<String, Int>>()
        try {
            val arr = JSONArray(response)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                results.add(Pair(obj.getString("tag"), obj.getInt("count")))
            }
        } catch (e: Exception) {
            Log.e("YaeJinsang", "JSON 파싱 실패: ${e.message}")
        }
        return results
    }

    private fun openAppWithNumber(number: String) {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("register_phone", number)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e("YaeJinsang", "앱 실행 실패: ${e.message}")
        }
    }

    private fun showWarningOverlay(number: String, tags: List<Pair<String, Int>>, isJinsang: Boolean = true) {
        if (!Settings.canDrawOverlays(this)) {
            Log.w("YaeJinsang", "오버레이 권한 없음")
            return
        }

        val handler = Handler(Looper.getMainLooper())
        handler.post {
            val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED,
                PixelFormat.TRANSLUCENT
            )
            params.gravity = Gravity.TOP

            val layout = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(48, 80, 48, 48)
                setBackgroundColor(if (isJinsang) 0xEE1A1A1A.toInt() else 0xDD1A1A1A.toInt())
            }

            // 번호 (마스킹)
            val masked = if (number.length > 4) {
                "${"*".repeat(number.length - 4)}${number.takeLast(4)}"
            } else number

            if (isJinsang) {
                // === 진상 감지 모드 ===
                val titleView = TextView(this).apply {
                    text = "🚨 얘진상 경고"
                    textSize = 24f
                    setTextColor(0xFFFF3B30.toInt())
                    gravity = Gravity.CENTER
                    setPadding(0, 0, 0, 16)
                }
                layout.addView(titleView)

                val numberView = TextView(this).apply {
                    text = masked
                    textSize = 18f
                    setTextColor(0xFFFFFFFF.toInt())
                    gravity = Gravity.CENTER
                    setPadding(0, 0, 0, 24)
                }
                layout.addView(numberView)

                val totalCount = tags.sumOf { it.second }
                val tagSummary = tags.joinToString(", ") { "${it.first} ${it.second}건" }

                val infoView = TextView(this).apply {
                    text = "⚠️ ${totalCount}개 업소에서 주의 등록\n$tagSummary"
                    textSize = 16f
                    setTextColor(0xFFFF6B6B.toInt())
                    gravity = Gravity.CENTER
                    setPadding(0, 0, 0, 16)
                    lineHeight = 56
                }
                layout.addView(infoView)

                val hintView = TextView(this).apply {
                    text = "응대에 주의하세요"
                    textSize = 14f
                    setTextColor(0x99FFFFFF.toInt())
                    gravity = Gravity.CENTER
                    setPadding(0, 0, 0, 24)
                }
                layout.addView(hintView)
            } else {
                // === 미등록 번호 모드 ===
                val titleView = TextView(this).apply {
                    text = "📞 수신 전화"
                    textSize = 18f
                    setTextColor(0xFFFFFFFF.toInt())
                    gravity = Gravity.CENTER
                    setPadding(0, 0, 0, 8)
                }
                layout.addView(titleView)

                val numberView = TextView(this).apply {
                    text = masked
                    textSize = 16f
                    setTextColor(0xAAFFFFFF.toInt())
                    gravity = Gravity.CENTER
                    setPadding(0, 0, 0, 16)
                }
                layout.addView(numberView)

                val safeView = TextView(this).apply {
                    text = "✅ 등록된 진상 정보 없음"
                    textSize = 14f
                    setTextColor(0xFF34C759.toInt())
                    gravity = Gravity.CENTER
                    setPadding(0, 0, 0, 16)
                }
                layout.addView(safeView)
            }

            // === 등록 버튼 (공통) ===
            val btnLayout = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
            }

            val registerBtn = TextView(this).apply {
                text = if (isJinsang) "✏️ 태그 추가" else "🚨 진상 등록"
                textSize = 15f
                setTextColor(0xFFFFFFFF.toInt())
                gravity = Gravity.CENTER
                setPadding(48, 24, 48, 24)
                setBackgroundColor(0xFFFF3B30.toInt())
                setOnClickListener {
                    openAppWithNumber(number)
                    try { windowManager.removeView(layout) } catch (_: Exception) {}
                }
            }
            btnLayout.addView(registerBtn)

            val dismissBtn = TextView(this).apply {
                text = "닫기"
                textSize = 14f
                setTextColor(0x99FFFFFF.toInt())
                gravity = Gravity.CENTER
                setPadding(36, 24, 36, 24)
                setOnClickListener {
                    try { windowManager.removeView(layout) } catch (_: Exception) {}
                }
            }
            btnLayout.addView(dismissBtn)

            layout.addView(btnLayout)

            windowManager.addView(layout, params)

            // 자동 제거: 진상이면 15초, 미등록이면 8초
            val dismissDelay = if (isJinsang) 15000L else 8000L
            handler.postDelayed({
                try {
                    windowManager.removeView(layout)
                } catch (e: Exception) {
                    Log.e("YaeJinsang", "오버레이 제거 실패: ${e.message}")
                }
            }, dismissDelay)
        }
    }

    private fun showNotification(number: String, tags: List<Pair<String, Int>>) {
        val channelId = "jinsang_warning"
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "진상 경고",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "진상 손님 수신 전화 경고"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val totalCount = tags.sumOf { it.second }
        val tagSummary = tags.joinToString(", ") { "${it.first} ${it.second}건" }
        val masked = if (number.length > 4) {
            "${"*".repeat(number.length - 4)}${number.takeLast(4)}"
        } else number

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("🚨 진상 감지 — $masked")
            .setContentText("${totalCount}개 업소 주의: $tagSummary")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .build()

        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }
}
