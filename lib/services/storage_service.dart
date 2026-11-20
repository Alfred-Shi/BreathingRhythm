import 'package:shared_preferences/shared_preferences.dart';
import '../models/breathing_config.dart';

/// 本地存储服务，保存/读取用户呼吸配置
class StorageService {
  static const _keyInhale = 'inhale_beats';
  static const _keyHold = 'hold_beats';
  static const _keyExhale = 'exhale_beats';
  static const _keyBeatDuration = 'beat_duration';
  static const _keyRounds = 'rounds';
  static const _keyInfinite = 'is_infinite';

  /// 保存配置
  static Future<void> saveConfig(BreathingConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyInhale, config.inhaleBeats);
    await prefs.setInt(_keyHold, config.holdBeats);
    await prefs.setInt(_keyExhale, config.exhaleBeats);
    await prefs.setDouble(_keyBeatDuration, config.beatDuration);
    await prefs.setInt(_keyRounds, config.rounds);
    await prefs.setBool(_keyInfinite, config.isInfinite);
  }

  /// 读取配置，不存在则返回默认值
  static Future<BreathingConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return BreathingConfig(
      inhaleBeats: prefs.getInt(_keyInhale) ?? 4,
      holdBeats: prefs.getInt(_keyHold) ?? 7,
      exhaleBeats: prefs.getInt(_keyExhale) ?? 8,
      beatDuration: (prefs.getDouble(_keyBeatDuration) ?? 1.5).clamp(0.5, 2.0),
      rounds: prefs.getInt(_keyRounds) ?? 5,
      isInfinite: prefs.getBool(_keyInfinite) ?? false,
    );
  }
}
