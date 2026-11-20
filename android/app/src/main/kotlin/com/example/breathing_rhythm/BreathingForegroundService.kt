package com.example.breathing_rhythm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * 呼吸引导前台服务
 *
 * 呼吸会话期间常驻通知并持有 CPU 唤醒锁，保证切换后台、息屏后
 * Dart 定时器与音频播放不被系统挂起或回收。
 */
class BreathingForegroundService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // 若在服务启动完成前就已收到停止指令，先完成 startForeground 契约再立即自停，避免系统异常
        if (!shouldRun) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
            return START_NOT_STICKY
        }

        isRunning = true
        acquireWakeLock()
        // 被系统杀死后不自动重启（重启后 Dart 侧已无会话，会留下空转通知）
        return START_NOT_STICKY
    }

    /** 用户从最近任务划掉应用时，立即结束服务与通知 */
    override fun onTaskRemoved(rootIntent: Intent?) {
        shouldRun = false
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        isRunning = false
        releaseWakeLock()
        super.onDestroy()
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
        val lock = wakeLock ?: powerManager
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "breathing_rhythm:session")
            .apply { setReferenceCounted(false) }
        wakeLock = lock
        // 设置超时兜底，避免异常情况下长期耗电
        lock.acquire(WAKE_LOCK_TIMEOUT_MS)
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "呼吸引导",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "呼吸引导进行中的后台提示"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder
            .setSmallIcon(R.drawable.ic_stat_breathing)
            .setContentTitle("节律呼吸")
            .setContentText("呼吸引导进行中，点击返回应用")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
        if (pendingIntent != null) {
            builder.setContentIntent(pendingIntent)
        }
        return builder.build()
    }

    companion object {
        private const val CHANNEL_ID = "breathing_session"
        private const val NOTIFICATION_ID = 1001
        // 唤醒锁最长持有 8 小时
        private const val WAKE_LOCK_TIMEOUT_MS = 8 * 60 * 60 * 1000L

        @Volatile
        var shouldRun: Boolean = false

        @Volatile
        var isRunning: Boolean = false
    }
}
