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

        scope.launch {
            try {
                val subscriptionValid = checkSubscription()
                if (!subscriptionValid) {
                    Log.d("YaeJinsang", "⚠️ 구독 만료 — 연장 안내")
                    showSubscriptionExpiredOverlay()
                    return@launch
                }

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

        respondToCall(callDetails, CallResponse.Builder()
            .setDisallowCall(false).setRejectCall(false)
            .setSilenceCall(false).setSkipCallLog(false)
            .setSkipNotification(false).build())
    }

    // ── 유틸 ──

    private fun hashPhoneNumber(number: String): String {
        val normalized = number.replace(Regex("[^0-9]"), "")
        val digest = MessageDigest.getInstance("SHA-256")
        return digest.digest(normalized.toByteArray()).joinToString("") { "%02x".format(it) }
    }

    private fun getShopId(): String? {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getString("flutter.supabase_user_id", null)
    }

    // ── 구독 체크 ──

    private fun checkSubscription(): Boolean {
        try {
            val shopId = getShopId() ?: run {
                Log.w("YaeJinsang", "shop ID 없음 — 구독 체크 스킵")
                return true
            }
            val url = URL("$supabaseUrl/rest/v1/shops?id=eq.$shopId&select=subscription_until,is_active")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.setRequestProperty("apikey", supabaseKey)
            conn.setRequestProperty("Accept", "application/json")
            conn.connectTimeout = 5000
            conn.readTimeout = 5000
            val response = conn.inputStream.bufferedReader().readText()
            conn.disconnect()

            val arr = JSONArray(response)
            if (arr.length() == 0) return true
            val shop = arr.getJSONObject(0)
            val isActive = shop.optBoolean("is_active", false)
            val until = shop.optString("subscription_until", "")
            if (!isActive || until.isEmpty()) return false

            val sdf = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US)
            sdf.timeZone = java.util.TimeZone.getTimeZone("UTC")
            val expiry = sdf.parse(until.take(19)) ?: return false
            return expiry.after(java.util.Date())
        } catch (e: Exception) {
            Log.e("YaeJinsang", "구독 체크 실패: ${e.message}")
            return true // 실패 시 서비스 중단 방지
        }
    }

    // ── 진상 조회 ──

    data class JinsangResult(val tag: String, val count: Int, val region: String?, val category: String?, val shopName: String?)

    private fun lookupJinsang(hash: String): List<JinsangResult> {
        val url = URL("$supabaseUrl/rest/v1/rpc/lookup_jinsang")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("apikey", supabaseKey)
        conn.setRequestProperty("Content-Type", "application/json")
        conn.doOutput = true
        conn.outputStream.write("""{"p_hash": "$hash"}""".toByteArray())
        val response = conn.inputStream.bufferedReader().readText()
        conn.disconnect()

        val results = mutableListOf<JinsangResult>()
        try {
            val arr = JSONArray(response)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                results.add(JinsangResult(
                    tag = obj.getString("tag"),
                    count = obj.getInt("count"),
                    region = obj.optString("region", null),
                    category = obj.optString("category", null),
                    shopName = if (obj.isNull("shop_name")) null else obj.optString("shop_name", null)
                ))
            }
        } catch (e: Exception) { Log.e("YaeJinsang", "JSON 파싱 실패: ${e.message}") }
        return results
    }

    private fun openAppWithNumber(number: String) {
        try {
            startActivity(Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("register_phone", number)
            })
        } catch (e: Exception) { Log.e("YaeJinsang", "앱 실행 실패: ${e.message}") }
    }

    // ── 오버레이 공통 파라미터 ──

    private fun createOverlayParams(): WindowManager.LayoutParams {
        val screenWidth = resources.displayMetrics.widthPixels
        val params = WindowManager.LayoutParams(
            (screenWidth * 0.88).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.CENTER
        return params
    }

    private fun createCardBackground(strokeColor: Long, strokeWidth: Int = 3): android.graphics.drawable.GradientDrawable {
        return android.graphics.drawable.GradientDrawable().apply {
            cornerRadius = 40f
            setColor(0xF01A1A1A.toInt())
            setStroke(strokeWidth, strokeColor.toInt())
        }
    }

    // ── 구독 만료 오버레이 ──

    private fun showSubscriptionExpiredOverlay() {
        if (!Settings.canDrawOverlays(this)) return
        val handler = Handler(Looper.getMainLooper())
        handler.post {
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager

            val layout = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(56, 56, 56, 48)
                background = createCardBackground(0xFFFF9500, 4)
                elevation = 24f
            }

            layout.addView(TextView(this).apply {
                text = "⏰ 구독이 만료되었어요"
                textSize = 20f; setTextColor(0xFFFF9500.toInt()); gravity = Gravity.CENTER
                setPadding(0, 0, 0, 16)
            })
            layout.addView(TextView(this).apply {
                text = "전화 보호 기능을 계속 사용하려면\n구독을 연장해주세요"
                textSize = 15f; setTextColor(0xCCFFFFFF.toInt()); gravity = Gravity.CENTER
                lineHeight = 52; setPadding(0, 0, 0, 24)
            })

            val btnRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER }
            btnRow.addView(TextView(this).apply {
                text = "앱 열기"; textSize = 15f; setTextColor(0xFFFFFFFF.toInt()); gravity = Gravity.CENTER
                setPadding(56, 28, 56, 28)
                background = android.graphics.drawable.GradientDrawable().apply { cornerRadius = 24f; setColor(0xFFFF9500.toInt()) }
                setOnClickListener {
                    try { startActivity(Intent(this@JinsangCallScreeningService, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }) } catch (_: Exception) {}
                    try { wm.removeView(layout) } catch (_: Exception) {}
                }
            })
            btnRow.addView(TextView(this).apply {
                text = "닫기"; textSize = 14f; setTextColor(0xAAFFFFFF.toInt()); gravity = Gravity.CENTER
                setPadding(40, 28, 40, 28)
                background = android.graphics.drawable.GradientDrawable().apply { cornerRadius = 24f; setColor(0xFF333333.toInt()) }
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { marginStart = 20 }
                setOnClickListener { try { wm.removeView(layout) } catch (_: Exception) {} }
            })
            layout.addView(btnRow)

            wm.addView(layout, createOverlayParams())
            handler.postDelayed({ try { wm.removeView(layout) } catch (_: Exception) {} }, 10000)
        }
    }

    // ── 진상/안전 오버레이 ──

    private fun showWarningOverlay(number: String, tags: List<JinsangResult>, isJinsang: Boolean) {
        if (!Settings.canDrawOverlays(this)) { Log.w("YaeJinsang", "오버레이 권한 없음"); return }

        val handler = Handler(Looper.getMainLooper())
        handler.post {
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val masked = if (number.length > 4) "${"*".repeat(number.length - 4)}${number.takeLast(4)}" else number

            val bgColor = if (isJinsang) 0xFFFF3B30.toLong() else 0xFF34C759.toLong()
            val layout = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(56, 56, 56, 48)
                background = createCardBackground(bgColor, if (isJinsang) 4 else 3)
                elevation = 24f
            }

            if (isJinsang) {
                layout.addView(TextView(this).apply {
                    text = "🚨 얘진상 경고"; textSize = 24f; setTextColor(0xFFFF3B30.toInt())
                    gravity = Gravity.CENTER; setPadding(0, 0, 0, 16)
                })
                layout.addView(TextView(this).apply {
                    text = masked; textSize = 18f; setTextColor(0xFFFFFFFF.toInt())
                    gravity = Gravity.CENTER; setPadding(0, 0, 0, 24)
                })

                val totalCount = tags.sumOf { it.count }
                val tagSummary = tags.joinToString(", ") { "${it.tag} ${it.count}건" }
                layout.addView(TextView(this).apply {
                    text = "⚠️ ${totalCount}개 업소에서 주의 등록\n$tagSummary"
                    textSize = 16f; setTextColor(0xFFFF6B6B.toInt()); gravity = Gravity.CENTER
                    lineHeight = 56; setPadding(0, 0, 0, 16)
                })

                val shopNames = tags.mapNotNull { it.shopName }.distinct()
                if (shopNames.isNotEmpty()) {
                    layout.addView(TextView(this).apply {
                        text = "🏪 ${shopNames.joinToString(", ")}"; textSize = 14f
                        setTextColor(0xFFFFAA00.toInt()); gravity = Gravity.CENTER; setPadding(0, 0, 0, 8)
                    })
                }

                val locationInfo = tags.filter { it.region != null && it.region != "미설정" }
                    .map { "${it.region} · ${it.category ?: "기타"}" }.distinct()
                if (locationInfo.isNotEmpty()) {
                    layout.addView(TextView(this).apply {
                        text = "📍 ${locationInfo.joinToString(", ")}"; textSize = 13f
                        setTextColor(0xAAFFFFFF.toInt()); gravity = Gravity.CENTER; setPadding(0, 0, 0, 16)
                    })
                }

                layout.addView(TextView(this).apply {
                    text = "응대에 주의하세요"; textSize = 14f; setTextColor(0x99FFFFFF.toInt())
                    gravity = Gravity.CENTER; setPadding(0, 0, 0, 24)
                })
            } else {
                layout.addView(TextView(this).apply {
                    text = "📞 수신 전화"; textSize = 18f; setTextColor(0xFFFFFFFF.toInt())
                    gravity = Gravity.CENTER; setPadding(0, 0, 0, 8)
                })
                layout.addView(TextView(this).apply {
                    text = masked; textSize = 16f; setTextColor(0xAAFFFFFF.toInt())
                    gravity = Gravity.CENTER; setPadding(0, 0, 0, 16)
                })
                layout.addView(TextView(this).apply {
                    text = "✅ 등록된 진상 정보 없음"; textSize = 14f; setTextColor(0xFF34C759.toInt())
                    gravity = Gravity.CENTER; setPadding(0, 0, 0, 16)
                })
            }

            // 버튼
            val btnRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER }
            btnRow.addView(TextView(this).apply {
                text = if (isJinsang) "✏️ 태그 추가" else "🚨 진상 등록"
                textSize = 15f; setTextColor(0xFFFFFFFF.toInt()); gravity = Gravity.CENTER
                setPadding(56, 28, 56, 28)
                background = android.graphics.drawable.GradientDrawable().apply { cornerRadius = 24f; setColor(0xFFFF3B30.toInt()) }
                setOnClickListener { openAppWithNumber(number); try { wm.removeView(layout) } catch (_: Exception) {} }
            })
            btnRow.addView(TextView(this).apply {
                text = "닫기"; textSize = 14f; setTextColor(0xAAFFFFFF.toInt()); gravity = Gravity.CENTER
                setPadding(40, 28, 40, 28)
                background = android.graphics.drawable.GradientDrawable().apply { cornerRadius = 24f; setColor(0xFF333333.toInt()) }
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { marginStart = 20 }
                setOnClickListener { try { wm.removeView(layout) } catch (_: Exception) {} }
            })
            layout.addView(btnRow)

            wm.addView(layout, createOverlayParams())
            val delay = if (isJinsang) 15000L else 8000L
            handler.postDelayed({ try { wm.removeView(layout) } catch (e: Exception) { Log.e("YaeJinsang", "오버레이 제거 실패: ${e.message}") } }, delay)
        }
    }

    // ── 알림 ──

    private fun showNotification(number: String, tags: List<JinsangResult>) {
        val channelId = "jinsang_warning"
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(NotificationChannel(channelId, "진상 경고", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "진상 손님 수신 전화 경고"; enableVibration(true); vibrationPattern = longArrayOf(0, 500, 200, 500)
            })
        }

        val totalCount = tags.sumOf { it.count }
        val tagSummary = tags.joinToString(", ") { "${it.tag} ${it.count}건" }
        val locationInfo = tags.filter { it.region != null && it.region != "미설정" }
            .map { "${it.region}·${it.category ?: "기타"}" }.distinct().joinToString(", ")
        val masked = if (number.length > 4) "${"*".repeat(number.length - 4)}${number.takeLast(4)}" else number
        val contentText = if (locationInfo.isNotEmpty()) "${totalCount}개 업소 주의: $tagSummary ($locationInfo)" else "${totalCount}개 업소 주의: $tagSummary"

        nm.notify(System.currentTimeMillis().toInt(), NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("🚨 진상 감지 — $masked")
            .setContentText(contentText)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .build())
    }
}
