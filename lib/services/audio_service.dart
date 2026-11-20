import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/breathing_config.dart';

/// 呼吸音频播放服务
///
/// 架构：背景音层 + 提示音层，完全独立互不干扰
///
/// 背景音层：
///   opening_music → 播放一次 → 自动切换到 ambient_sound 无限循环
///
/// 提示音层：
///   inhale / hold / exhale 提示语音，与背景音叠加播放
class AudioService {
  AudioService();

  // ========== 背景音播放器（关闭单实例焦点拦截，由 AudioSession 统一管理） ==========
  late final AudioPlayer _openingPlayer =
      AudioPlayer(handleInterruptions: false);
  late final AudioPlayer _ambientPlayer =
      AudioPlayer(handleInterruptions: false);

  // ========== 提示音播放器 ==========
  late final Map<BreathingPhase, AudioPlayer> _cuePlayers = {
    BreathingPhase.inhale: AudioPlayer(handleInterruptions: false),
    BreathingPhase.hold: AudioPlayer(handleInterruptions: false),
    BreathingPhase.exhale: AudioPlayer(handleInterruptions: false),
  };

  // 独立的淡入淡出定时器
  final Map<AudioPlayer, Timer> _fadeTimers = {};

  // opening_music 位置、状态与外部打断监听
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _openingStateSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;

  // 音频开关
  bool enabled = true;

  // 是否已初始化 / 正在初始化的 Future / 是否已销毁
  bool _initialized = false;
  Future<bool>? _initFuture;
  bool _disposed = false;

  // 会话是否活跃（从点击开始到点击停止）
  bool _sessionActive = false;

  // 避免环境音重复启动
  bool _ambientStarted = false;

  // 是否为会话首次吸气
  bool _isFirstInhale = true;

  // 是否被外部音频中断暂停
  bool _pausedByInterruption = false;

  // 会话唯一代号，用于防止异步等待跨会话产生残留播放或串音
  int _sessionId = 0;

  // 最近一次请求播放的提示音阶段，用于丢弃延迟后已过期的提示音
  BreathingPhase _latestCuePhase = BreathingPhase.idle;

  // 淡入淡出参数
  static const int _fadeSteps = 20;
  static const int _fadeDurationMs = 1000;
  static const int _fadeStepMs = _fadeDurationMs ~/ _fadeSteps;

  // 自然结束时的淡出参数（1.5 秒）
  static const int _fadeOutSteps = 15;
  static const int _fadeOutStepMs = 100;

  // 背景音音量
  static const double _bgVolume = 0.7;

  /// 判断指定会话是否仍然有效（未被停止、未被新会话取代且未销毁）
  bool _isCurrent(int sessionId) =>
      !_disposed && _sessionActive && _sessionId == sessionId;

  /// 初始化：配置音频会话并预加载音频资源，成功返回 true
  Future<bool> init() {
    if (_disposed) return Future.value(false);
    if (_initialized) return Future.value(true);
    return _initFuture ??= _performInit();
  }

  Future<bool> _performInit() async {
    try {
      // 配置应用级音频会话，保证与后台保活和外部音频打断行为一致
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );
      _listenInterruptions(session);

      // 预加载背景音
      await _openingPlayer.setAsset('assets/audio/opening_music.wav');
      await _ambientPlayer.setAsset('assets/audio/ambient_sound.wav');
      await _ambientPlayer.setLoopMode(LoopMode.one);

      // 预加载提示音
      await _cuePlayers[BreathingPhase.inhale]!
          .setAsset('assets/audio/inhale.wav');
      await _cuePlayers[BreathingPhase.hold]!
          .setAsset('assets/audio/hold.wav');
      await _cuePlayers[BreathingPhase.exhale]!
          .setAsset('assets/audio/exhale.wav');

      if (_disposed) return false;
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('AudioService init failed: $e');
      _initFuture = null;
      return false;
    }
  }

  /// 监听来电、闹钟等外部音频打断事件
  void _listenInterruptions(AudioSession session) {
    _interruptionSub?.cancel();
    _interruptionSub = session.interruptionEventStream.listen((event) {
      if (_disposed || !_sessionActive) return;
      if (event.begin) {
        _pausedByInterruption = true;
        _pauseBackgroundForInterruption();
      } else {
        if (_pausedByInterruption &&
            (event.type == AudioInterruptionType.pause ||
                event.type == AudioInterruptionType.unknown)) {
          _pausedByInterruption = false;
          _resumeBackgroundAfterInterruption();
        } else {
          _pausedByInterruption = false;
        }
      }
    });
  }

  void _pauseBackgroundForInterruption() {
    if (_openingPlayer.playing) {
      _openingPlayer.pause().catchError((Object e) {
        debugPrint('AudioService interruption pause opening failed: $e');
      });
    }
    if (_ambientPlayer.playing) {
      _ambientPlayer.pause().catchError((Object e) {
        debugPrint('AudioService interruption pause ambient failed: $e');
      });
    }
  }

  void _resumeBackgroundAfterInterruption() {
    if (!_sessionActive || _disposed) return;
    if (_ambientStarted) {
      unawaited(
        _ambientPlayer.play().catchError((Object e) {
          debugPrint('AudioService resume ambient failed: $e');
        }),
      );
    } else if (_openingPlayer.processingState != ProcessingState.completed) {
      unawaited(
        _openingPlayer.play().catchError((Object e) {
          debugPrint('AudioService resume opening failed: $e');
        }),
      );
    }
  }

  /// 开始会话：播放 opening_music，并在结束前 1 秒无缝切换到 ambient_sound 循环
  Future<void> startSession() async {
    if (!enabled || _disposed) return;

    final sessionId = ++_sessionId;
    _sessionActive = true;
    _ambientStarted = false;
    _isFirstInhale = true;
    _pausedByInterruption = false;
    _latestCuePhase = BreathingPhase.idle;

    if (!_initialized) {
      final success = await init();
      if (!success || !_isCurrent(sessionId)) return;
    }

    // 停止所有可能残留的播放
    await _stopAllImmediate();
    if (!_isCurrent(sessionId)) return;

    // 播放 opening_music
    try {
      await _openingPlayer.seek(Duration.zero);
      if (!_isCurrent(sessionId)) return;
      await _openingPlayer.setVolume(_bgVolume);
      if (!_isCurrent(sessionId)) return;

      unawaited(
        _openingPlayer.play().catchError((Object e) {
          debugPrint('AudioService opening play failed: $e');
        }),
      );

      // 监听播放进度与完成态（完成态用于后台节流时的兜底切换）
      _cancelOpeningListeners();
      _positionSub = _openingPlayer.positionStream.listen((position) {
        final duration = _openingPlayer.duration;
        if (duration != null &&
            (duration - position).inMilliseconds <= 1000 &&
            _isCurrent(sessionId) &&
            !_ambientStarted) {
          _triggerAmbientLoop(sessionId);
        }
      });
      _openingStateSub = _openingPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed &&
            _isCurrent(sessionId) &&
            !_ambientStarted) {
          _triggerAmbientLoop(sessionId);
        }
      });
    } catch (_) {
      // 如果 opening_music 播放失败，直接启动 ambient
      _triggerAmbientLoop(sessionId);
    }
  }

  void _triggerAmbientLoop(int sessionId) {
    if (_ambientStarted || !_isCurrent(sessionId)) return;
    _ambientStarted = true;
    _startAmbientLoop(sessionId);
  }

  void _cancelOpeningListeners() {
    _positionSub?.cancel();
    _positionSub = null;
    _openingStateSub?.cancel();
    _openingStateSub = null;
  }

  /// 启动 ambient_sound 循环播放
  Future<void> _startAmbientLoop(int sessionId) async {
    if (!_isCurrent(sessionId)) return;

    try {
      _cancelOpeningListeners();

      await _ambientPlayer.seek(Duration.zero);
      if (!_isCurrent(sessionId)) return;
      await _ambientPlayer.setVolume(0);
      if (!_isCurrent(sessionId)) return;

      unawaited(
        _ambientPlayer.play().catchError((Object e) {
          debugPrint('AudioService ambient play failed: $e');
        }),
      );
      _fadeIn(_ambientPlayer, targetVolume: _bgVolume);
    } catch (e) {
      debugPrint('AudioService ambient loop failed: $e');
    }
  }

  /// 播放指定阶段的提示语音（与背景音叠加，不中断背景音）
  Future<void> playCue(BreathingPhase phase) async {
    if (!enabled || _disposed || !_sessionActive) return;
    if (phase == BreathingPhase.idle) return;

    final sessionId = _sessionId;
    _latestCuePhase = phase;

    // 若会话刚启动且音频仍在初始化，等待初始化完成避免首拍丢失
    if (!_initialized) {
      final success = await init();
      if (!success || !_isCurrent(sessionId) || _latestCuePhase != phase) {
        return;
      }
    }

    if (phase == BreathingPhase.inhale && _isFirstInhale) {
      _isFirstInhale = false;
      // 延迟约 1 秒，等待 opening_music 播放一会再出人声，自然融合
      await Future.delayed(const Duration(seconds: 1));
      // 会话已结束/重启，或期间已进入下一阶段（本提示音已过期）则丢弃
      if (!_isCurrent(sessionId) || _latestCuePhase != phase) return;
    }

    final player = _cuePlayers[phase];
    if (player == null) return;

    try {
      // 使用 pause 而非 stop，避免释放解码资源导致下次播放延迟
      for (final p in _cuePlayers.values) {
        if (p.playing) await p.pause();
      }
      if (!_isCurrent(sessionId) || _latestCuePhase != phase) return;
      await player.seek(Duration.zero);
      if (!_isCurrent(sessionId) || _latestCuePhase != phase) return;

      unawaited(
        player.play().catchError((Object e) {
          debugPrint('AudioService play cue $phase error: $e');
        }),
      );
    } catch (e) {
      debugPrint('AudioService play cue $phase failed: $e');
    }
  }

  /// 停止会话：fadeOut 为 true 时背景音淡出后再停止（用于自然结束），否则立即停止
  Future<void> stopSession({bool fadeOut = false}) async {
    final sessionId = ++_sessionId;
    _sessionActive = false;
    _pausedByInterruption = false;
    _cancelOpeningListeners();

    if (fadeOut && _initialized && !_disposed) {
      await _fadeOutAndStop(sessionId);
    } else {
      await _stopAllImmediate();
    }
  }

  /// 背景音淡出后停止；淡出期间若开始了新会话或被强制停止，则放弃本次淡出
  Future<void> _fadeOutAndStop(int sessionId) async {
    for (final timer in _fadeTimers.values) {
      timer.cancel();
    }
    _fadeTimers.clear();

    final players = [_openingPlayer, _ambientPlayer];
    final startVolumes = [for (final p in players) p.volume];

    for (var i = 1; i <= _fadeOutSteps; i++) {
      await Future.delayed(const Duration(milliseconds: _fadeOutStepMs));
      if (_disposed || _sessionId != sessionId) return;
      final ratio = 1 - i / _fadeOutSteps;
      for (var j = 0; j < players.length; j++) {
        if (players[j].playing) {
          players[j].setVolume(startVolumes[j] * ratio).ignore();
        }
      }
    }
    if (_disposed || _sessionId != sessionId) return;
    await _stopAllImmediate();
  }

  /// 立即停止所有播放（无淡出）
  Future<void> _stopAllImmediate() async {
    _cancelOpeningListeners();

    for (var timer in _fadeTimers.values) {
      timer.cancel();
    }
    _fadeTimers.clear();

    final players = [_openingPlayer, _ambientPlayer, ..._cuePlayers.values];
    try {
      // 同时下发暂停指令，避免逐个等待产生间隙
      await Future.wait([
        for (final p in players)
          if (p.playing) p.pause(),
      ]);
    } catch (e) {
      debugPrint('AudioService stop failed: $e');
    }
  }

  /// 声音平滑淡入
  void _fadeIn(AudioPlayer player, {required double targetVolume}) {
    _fadeTimers[player]?.cancel();
    double vol = 0;
    final step = targetVolume / _fadeSteps;
    int count = 0;

    _fadeTimers[player] = Timer.periodic(
      const Duration(milliseconds: _fadeStepMs),
      (timer) {
        if (_disposed || !_sessionActive) {
          timer.cancel();
          _fadeTimers.remove(player);
          return;
        }
        count++;
        vol += step;
        if (count >= _fadeSteps) {
          player.setVolume(targetVolume).ignore();
          timer.cancel();
          _fadeTimers.remove(player);
        } else {
          player.setVolume(vol.clamp(0.0, targetVolume)).ignore();
        }
      },
    );
  }

  /// 销毁并释放资源
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _interruptionSub?.cancel();
    _interruptionSub = null;
    await stopSession();
    await _openingPlayer.dispose();
    await _ambientPlayer.dispose();
    for (var p in _cuePlayers.values) {
      await p.dispose();
    }
  }
}
