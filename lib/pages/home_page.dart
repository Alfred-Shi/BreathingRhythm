import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/breathing_controller.dart';
import '../models/breathing_config.dart';
import '../services/audio_service.dart';
import '../services/background_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/breathing_circle.dart';
import '../widgets/mode_selector.dart';
import '../widgets/rhythm_settings_card.dart';

/// 首页
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late BreathingController _controller;
  final AudioService _audioService = AudioService();
  int _selectedModeIndex = 0;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = BreathingController();
    _controller.onSessionStart = () {
      _audioService.startSession();
      // 启动后台保活，保证切后台/息屏后继续运行
      BackgroundService.start();
    };
    _controller.onSessionEnd = (completed) async {
      // 自然结束时背景音淡出，手动停止则立即静音
      await _audioService.stopSession(fadeOut: completed);
      // 淡出期间若已开始新会话，则不能关闭新会话的后台保活
      if (!_controller.isRunning) {
        BackgroundService.stop();
      }
    };
    _controller.onCuePlay = (phase) => _audioService.playCue(phase);
    _initAudio();
    _loadConfig();
  }

  Future<void> _initAudio() async {
    final success = await _audioService.init();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('音频资源加载失败'),
          action: SnackBarAction(
            label: '重试',
            onPressed: _initAudio,
          ),
        ),
      );
    }
  }

  Future<void> _loadConfig() async {
    try {
      final config = await StorageService.loadConfig();
      // 页面已销毁或用户已开始呼吸时，不再覆盖配置
      if (!mounted || _controller.isRunning) return;
      _controller.updateConfig(config);
      setState(() {
        _selectedModeIndex = _findMatchingPreset(config);
      });
    } catch (e) {
      debugPrint('读取配置失败: $e');
    }
  }

  int _findMatchingPreset(BreathingConfig config) {
    final presets = BreathingPreset.presets;
    for (int i = 0; i < presets.length; i++) {
      final p = presets[i].config;
      if (p.inhaleBeats == config.inhaleBeats &&
          p.holdBeats == config.holdBeats &&
          p.exhaleBeats == config.exhaleBeats &&
          p.beatDuration == config.beatDuration) {
        return i;
      }
    }
    return -1;
  }

  void _onModeSelected(int index) {
    if (_controller.isRunning) return;

    setState(() {
      _selectedModeIndex = index;
      if (index >= 0 && index < BreathingPreset.presets.length) {
        final preset = BreathingPreset.presets[index].config;
        _controller.updateConfig(
          _controller.config.copyWith(
            inhaleBeats: preset.inhaleBeats,
            holdBeats: preset.holdBeats,
            exhaleBeats: preset.exhaleBeats,
            beatDuration: preset.beatDuration,
          ),
        );
      }
    });
    _saveConfig();
  }

  void _onConfigChanged(BreathingConfig newConfig) {
    setState(() {
      _controller.updateConfig(newConfig);
      _selectedModeIndex = _findMatchingPreset(newConfig);
    });
    _saveConfig();
  }

  void _saveConfig() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        await StorageService.saveConfig(_controller.config);
      } catch (e) {
        debugPrint('保存配置失败: $e');
      }
    });
  }

  void _toggleBreathing() {
    HapticFeedback.mediumImpact();
    if (_controller.isRunning) {
      _controller.stop();
    } else {
      _controller.start();
    }
  }

  @override
  void dispose() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
      StorageService.saveConfig(_controller.config).catchError((Object e) {
        debugPrint('保存配置失败: $e');
      });
    }
    // 先摘除回调，避免销毁阶段触发 setState；音频与后台保活在下方统一释放
    _controller.onSessionStart = null;
    _controller.onSessionEnd = null;
    _controller.onCuePlay = null;
    _controller.dispose();
    BackgroundService.stop();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      BreathingCircle(
                        controller: _controller,
                        onTap: _toggleBreathing,
                      ),
                      const SizedBox(height: 12),
                      ListenableBuilder(
                        listenable: _controller,
                        builder: (context, _) {
                          if (_controller.isRunning) {
                            return Text(
                              '点击圆球停止',
                              style: TextStyle(
                                color: context.appTextSecondary.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 13,
                              ),
                            );
                          }
                          return Text(
                            '点击圆球开始呼吸',
                            style: TextStyle(
                              color: context.appTextSecondary.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 13,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      ListenableBuilder(
                        listenable: _controller,
                        builder: (context, _) {
                          final enabled = !_controller.isRunning;
                          return Column(
                            children: [
                              ModeSelector(
                                selectedIndex: _selectedModeIndex,
                                enabled: enabled,
                                onSelected: _onModeSelected,
                              ),
                              const SizedBox(height: 20),
                              RhythmSettingsCard(
                                config: _controller.config,
                                enabled: enabled,
                                onChanged: _onConfigChanged,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(
        '节律呼吸',
        style: TextStyle(
          color: context.appTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
