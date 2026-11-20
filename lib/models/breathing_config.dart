/// 呼吸阶段枚举
enum BreathingPhase {
  idle, // 空闲状态
  inhale, // 吸气
  hold, // 屏息
  exhale, // 呼气
}

/// 呼吸阶段的中文名称
extension BreathingPhaseExt on BreathingPhase {
  String get label {
    switch (this) {
      case BreathingPhase.idle:
        return '开始呼吸';
      case BreathingPhase.inhale:
        return '吸气中';
      case BreathingPhase.hold:
        return '屏息中';
      case BreathingPhase.exhale:
        return '呼气中';
    }
  }
}

/// 呼吸配置数据模型
class BreathingConfig {
  final int inhaleBeats; // 吸气拍数
  final int holdBeats; // 屏息拍数
  final int exhaleBeats; // 呼气拍数
  final double beatDuration; // 每拍秒数 (0.5 ~ 2.0)
  final int rounds; // 循环轮数
  final bool isInfinite; // 是否无限循环

  const BreathingConfig({
    this.inhaleBeats = 4,
    this.holdBeats = 7,
    this.exhaleBeats = 8,
    this.beatDuration = 1.5,
    this.rounds = 5,
    this.isInfinite = false,
  });

  /// 单轮总拍数
  int get totalBeatsPerRound => inhaleBeats + holdBeats + exhaleBeats;

  /// 单轮秒数
  double get secondsPerRound => totalBeatsPerRound * beatDuration;

  /// 总秒数（无限循环时返回 0）
  double get totalSeconds => isInfinite ? 0 : secondsPerRound * rounds;

  /// 格式化总用时
  String get formattedDuration {
    if (isInfinite) return '无限循环';
    final totalRounded = totalSeconds.round();
    final minutes = totalRounded ~/ 60;
    final seconds = totalRounded % 60;
    if (minutes > 0) {
      return '$minutes分$seconds秒（$totalRounded秒）';
    }
    return '$totalRounded秒';
  }

  /// 某阶段的实际秒数
  double phaseDuration(BreathingPhase phase) {
    switch (phase) {
      case BreathingPhase.inhale:
        return inhaleBeats * beatDuration;
      case BreathingPhase.hold:
        return holdBeats * beatDuration;
      case BreathingPhase.exhale:
        return exhaleBeats * beatDuration;
      case BreathingPhase.idle:
        return 0;
    }
  }

  BreathingConfig copyWith({
    int? inhaleBeats,
    int? holdBeats,
    int? exhaleBeats,
    double? beatDuration,
    int? rounds,
    bool? isInfinite,
  }) {
    return BreathingConfig(
      inhaleBeats: inhaleBeats ?? this.inhaleBeats,
      holdBeats: holdBeats ?? this.holdBeats,
      exhaleBeats: exhaleBeats ?? this.exhaleBeats,
      beatDuration: beatDuration ?? this.beatDuration,
      rounds: rounds ?? this.rounds,
      isInfinite: isInfinite ?? this.isInfinite,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BreathingConfig &&
        other.inhaleBeats == inhaleBeats &&
        other.holdBeats == holdBeats &&
        other.exhaleBeats == exhaleBeats &&
        other.beatDuration == beatDuration &&
        other.rounds == rounds &&
        other.isInfinite == isInfinite;
  }

  @override
  int get hashCode => Object.hash(
        inhaleBeats,
        holdBeats,
        exhaleBeats,
        beatDuration,
        rounds,
        isInfinite,
      );
}

/// 预设呼吸模式
class BreathingPreset {
  final String name;
  final String description;
  final BreathingConfig config;

  const BreathingPreset({
    required this.name,
    required this.description,
    required this.config,
  });

  /// 预设模式列表
  static const List<BreathingPreset> presets = [
    BreathingPreset(
      name: '4-7-8',
      description: '经典助眠',
      config: BreathingConfig(inhaleBeats: 4, holdBeats: 7, exhaleBeats: 8),
    ),
    BreathingPreset(
      name: '4-4-4',
      description: '平衡呼吸',
      config: BreathingConfig(inhaleBeats: 4, holdBeats: 4, exhaleBeats: 4),
    ),
    BreathingPreset(
      name: '5-2-5',
      description: '快速减压',
      config: BreathingConfig(inhaleBeats: 5, holdBeats: 2, exhaleBeats: 5),
    ),
  ];
}
