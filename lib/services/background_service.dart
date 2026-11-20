import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 后台保活服务
///
/// Android：呼吸会话期间启动前台服务 + 唤醒锁，保证切后台、息屏后继续运行。
/// 其他平台（iOS 依靠 audio 后台模式）调用无平台实现时静默忽略。
class BackgroundService {
  BackgroundService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.breathing_rhythm/app');

  /// 启动后台保活
  static Future<void> start() async {
    try {
      await _channel.invokeMethod<bool>('startForegroundService');
    } catch (e) {
      debugPrint('启动后台保活失败: $e');
    }
  }

  /// 停止后台保活
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<bool>('stopForegroundService');
    } catch (e) {
      debugPrint('停止后台保活失败: $e');
    }
  }
}
