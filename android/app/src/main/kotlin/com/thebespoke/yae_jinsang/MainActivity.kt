package com.thebespoke.yae_jinsang

import android.app.role.RoleManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.telecom.TelecomManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.thebespoke.yae_jinsang/screening"
    private val REQUEST_ID = 1
    private var pendingPhone: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleRegisterIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleRegisterIntent(intent)
    }

    private fun handleRegisterIntent(intent: Intent) {
        val phone = intent.getStringExtra("register_phone")
        if (phone != null) {
            pendingPhone = phone
            // Flutter 준비됐으면 바로 전달
            methodChannel?.invokeMethod("onRegisterPhone", phone)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_ID) {
            // 스크리닝 역할 요청 결과 — Flutter에 상태 갱신 알림
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = getSystemService(RoleManager::class.java)
                val held = roleManager?.isRoleHeld(RoleManager.ROLE_CALL_SCREENING) ?: false
                methodChannel?.invokeMethod("onScreeningStateChanged", held)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingPhone" -> {
                    val phone = pendingPhone
                    pendingPhone = null
                    result.success(phone)
                }
                "requestScreeningRole" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val roleManager = getSystemService(RoleManager::class.java)
                        if (roleManager != null) {
                            val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
                            startActivityForResult(intent, REQUEST_ID)
                            result.success("requested")
                        } else {
                            result.success("no_role_manager")
                        }
                    } else {
                        result.error("UNSUPPORTED", "Android 10+ 필요", null)
                    }
                }
                "isScreeningEnabled" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val roleManager = getSystemService(RoleManager::class.java)
                        val heldByRole = roleManager?.isRoleHeld(RoleManager.ROLE_CALL_SCREENING) ?: false
                        
                        // 삼성 등 일부 기기에서 isRoleHeld가 false를 리턴하는 버그 대응
                        // CallScreeningService가 시스템에 등록되어 있는지 직접 확인
                        val serviceEnabled = try {
                            val pm = packageManager
                            val component = ComponentName(this, JinsangCallScreeningService::class.java)
                            val info = pm.getServiceInfo(component, 0)
                            info.permission == "android.permission.BIND_SCREENING_SERVICE"
                        } catch (e: Exception) {
                            false
                        }
                        
                        val held = heldByRole || serviceEnabled
                        android.util.Log.w("YaeJinsang", "isScreeningEnabled: role=$heldByRole, service=$serviceEnabled, final=$held")
                        result.success(held)
                    } else {
                        result.success(false)
                    }
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                        startActivity(intent)
                        result.success("requested")
                    } else {
                        result.success("already_granted")
                    }
                }
                "openAppSettings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    intent.data = android.net.Uri.parse("package:$packageName")
                    startActivity(intent)
                    result.success("opened")
                }
                "canDrawOverlays" -> {
                    result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
                    )
                }
                else -> result.notImplemented()
            }
        }
    }
}
