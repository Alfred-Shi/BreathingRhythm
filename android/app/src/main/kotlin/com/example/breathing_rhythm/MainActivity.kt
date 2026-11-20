package com.example.breathing_rhythm

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.example.breathing_rhythm/app"
    private var hasRequestedNotificationPermission = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    requestNotificationPermissionIfNeeded()
                    result.success(startBreathingService())
                }
                "stopForegroundService" -> {
                    stopBreathingService()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /** 启动前台服务，失败时返回 false（不影响呼吸流程本身） */
    private fun startBreathingService(): Boolean {
        return try {
            BreathingForegroundService.shouldRun = true
            val intent = Intent(this, BreathingForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            true
        } catch (e: Exception) {
            BreathingForegroundService.shouldRun = false
            false
        }
    }

    /** 停止前台服务：若服务尚未完成启动则仅标记停止，由服务在 startForeground 后自行退出 */
    private fun stopBreathingService() {
        BreathingForegroundService.shouldRun = false
        if (BreathingForegroundService.isRunning) {
            stopService(Intent(this, BreathingForegroundService::class.java))
        }
    }

    /** Android 13+ 仅首次提示通知权限；未授权不影响服务运行 */
    private fun requestNotificationPermissionIfNeeded() {
        if (hasRequestedNotificationPermission) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            hasRequestedNotificationPermission = true
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
        }
    }
}
