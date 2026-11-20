import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/breathing_config.dart';

/// 呼吸核心逻辑控制器
///
/// 管理呼吸循环的状态机：idle → inhale → hold → exhale → inhale → ...
/// 使用 Timer.periodic 驱动倒计时，内部统一使用整数毫秒计算以消除浮点误差。
class BreathingController extends ChangeNotifier {
  BreathingConfig _config;
  BreathingPhase _phase = BreathingPhase.idle;
  Timer? _timer;

  // 当前阶段在总时间轴上的起点（毫秒）。阶段边界按理论时间推进，避免定时器延迟累积漂移
  int _phaseStartMs = 0;
  // 本轮总已耗时计时器
  final Stopwatch _totalStopwatch = Stopwatch();
  // 当前轮次（从1开始）
  int _currentRound = 1;
  // 是否正在运行
  bool _isRunning = false;
  // 当前拍号（1开始），用于检测拍变化
  int _currentBeatNumber = 0;
  // 上次通知的整秒数，避免秒数与拍号均未变化时无效重建 UI
  int _lastNotifiedSecond = 0;

  /// 会话开始回调（用于启动背景音）
  VoidCallback? onSessionStart;

  /// 会话结束回调（用于停止音频）：completed 为 true 表示全部轮数自然结束
  void Function(bool completed)? onSessionEnd;

  /// 提示音播放回调（阶段切换时触发）
  void Function(BreathingPhase phase)? onCuePlay;

  BreathingController() : _config = const BreathingConfig();

  // ========== Getters ==========

  BreathingConfig get config => _config;
  BreathingPhase get phase => _phase;
  bool get isRunning => _isRunning;
  int get currentRound => _currentRound;
  int get currentBeatNumber => _currentBeatNumber;
  double get totalElapsedSeconds => _totalStopwatch.elapsedMilliseconds / 1000.0;

  int get _beatDurationMs => (_config.beatDuration * 1000).round();
  int get _totalElapsedMs => _totalStopwatch.elapsedMilliseconds;
  int get _elapsedMs => _totalElapsedMs - _phaseStartMs;
  int get _currentPhaseDurationMs => currentPhaseBeats * _beatDurationMs;

  /// 当前阶段的总时长（秒）
  double get currentPhaseDuration => _config.phaseDuration(_phase);

  /// 当前阶段的总拍数
  int get currentPhaseBeats {
    switch (_phase) {
      case BreathingPhase.inhale:
        return _config.inhaleBeats;
      case BreathingPhase.hold:
        return _config.holdBeats;
      case BreathingPhase.exhale:
        return _config.exhaleBeats;
      case BreathingPhase.idle:
        return 0;
    }
  }

  // ========== 配置管理 ==========

  /// 更新呼吸配置（运行中不允许修改）
  void updateConfig(BreathingConfig newConfig) {
    if (_isRunning) return;
    _config = newConfig;
    notifyListeners();
  }

  // ========== 呼吸控制 ==========

  /// 开始呼吸
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _currentRound = 1;
    _phaseStartMs = 0;
    _lastNotifiedSecond = 0;
    _totalStopwatch.reset();
    _totalStopwatch.start();
    // 触发会话开始回调（启动背景音）
    onSessionStart?.call();
    _startPhase(BreathingPhase.inhale);
  }

  /// 停止呼吸，立即重置所有状态（completed 为 true 表示自然结束）
  void stop({bool completed = false}) {
    final wasRunning = _isRunning;
    _resetInternal();

    // 如果之前在运行，触发结束回调
    if (wasRunning) {
      onSessionEnd?.call(completed);
    }

    notifyListeners();
  }

  /// 清理内部状态与定时器（不触发通知与外部回调）
  void _resetInternal() {
    _cancelTimer();
    _isRunning = false;
    _phase = BreathingPhase.idle;
    _phaseStartMs = 0;
    _totalStopwatch.stop();
    _totalStopwatch.reset();
    _currentRound = 1;
    _currentBeatNumber = 0;
    _lastNotifiedSecond = 0;
  }

  /// 开始指定阶段
  void _startPhase(BreathingPhase newPhase) {
    _cancelTimer();
    _phase = newPhase;
    final beatMs = _beatDurationMs;
    final elapsed = _elapsedMs.clamp(0, _currentPhaseDurationMs);
    _currentBeatNumber = beatMs > 0
        ? (elapsed ~/ beatMs + 1).clamp(1, currentPhaseBeats)
        : 1;
    _lastNotifiedSecond = _totalElapsedMs ~/ 1000;

    // 触发提示音回调
    onCuePlay?.call(_phase);
    notifyListeners();

    // 每100ms检查一次阶段切换、拍号与整秒更新
    const tick = Duration(milliseconds: 100);
    _timer = Timer.periodic(tick, (_) {
      if (_elapsedMs >= _currentPhaseDurationMs) {
        _advanceToNextPhase();
      } else {
        final currentSecond = _totalElapsedMs ~/ 1000;
        final newBeat = beatMs > 0 ? (_elapsedMs ~/ beatMs) + 1 : 1;
        var shouldNotify = false;
        if (newBeat != _currentBeatNumber && newBeat <= currentPhaseBeats) {
          _currentBeatNumber = newBeat;
          shouldNotify = true;
        }
        if (currentSecond != _lastNotifiedSecond) {
          _lastNotifiedSecond = currentSecond;
          shouldNotify = true;
        }
        if (shouldNotify) {
          notifyListeners();
        }
      }
    });
  }

  /// 进入下一阶段，支持系统挂起恢复后按实际流逝时间对齐阶段与轮次
  void _advanceToNextPhase() {
    final roundDurationMs = _config.totalBeatsPerRound * _beatDurationMs;

    while (_isRunning && _elapsedMs >= _currentPhaseDurationMs) {
      _phaseStartMs += _currentPhaseDurationMs;

      switch (_phase) {
        case BreathingPhase.inhale:
          _phase = _config.holdBeats <= 0
              ? BreathingPhase.exhale
              : BreathingPhase.hold;
          break;
        case BreathingPhase.hold:
          _phase = BreathingPhase.exhale;
          break;
        case BreathingPhase.exhale:
          if (!_config.isInfinite && _currentRound >= _config.rounds) {
            stop(completed: true);
            return;
          }
          _currentRound++;
          _phase = BreathingPhase.inhale;

          // 若跨越了整轮以上时间，使用整除直接跳过，保证轮次、阶段与总耗时一致
          if (roundDurationMs > 0 && _elapsedMs >= roundDurationMs) {
            final skippedRounds = _elapsedMs ~/ roundDurationMs;
            if (!_config.isInfinite &&
                _currentRound + skippedRounds > _config.rounds) {
              stop(completed: true);
              return;
            }
            _currentRound += skippedRounds;
            _phaseStartMs += skippedRounds * roundDurationMs;
          }
          break;
        case BreathingPhase.idle:
          return;
      }
    }

    if (_isRunning) {
      _startPhase(_phase);
    }
  }

  /// 取消定时器
  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    // 销毁阶段静默释放，避免向尚未销毁的子组件广播状态变更
    _resetInternal();
    super.dispose();
  }
}
