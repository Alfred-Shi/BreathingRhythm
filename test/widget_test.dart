import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:breathing_rhythm/controllers/breathing_controller.dart';
import 'package:breathing_rhythm/main.dart';
import 'package:breathing_rhythm/models/breathing_config.dart';
import 'package:breathing_rhythm/pages/home_page.dart';
import 'package:breathing_rhythm/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(
      const MethodChannel('com.example.breathing_rhythm/app'),
      (call) async => true,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (call) async {
        if (call.method == 'init') return null;
        if (call.method.startsWith('dispose')) return {};
        return {};
      },
    );
  });

  group('BreathingRhythmApp', () {
    testWidgets('显示标题', (WidgetTester tester) async {
      await tester.pumpWidget(const BreathingRhythmApp());
      expect(find.text('节律呼吸'), findsOneWidget);
    });

    testWidgets('显示设置卡片', (WidgetTester tester) async {
      await tester.pumpWidget(const BreathingRhythmApp());
      expect(find.text('呼吸节奏设置'), findsOneWidget);
    });

    testWidgets('显示预设模式', (WidgetTester tester) async {
      await tester.pumpWidget(const BreathingRhythmApp());
      expect(find.text('4-7-8'), findsOneWidget);
      expect(find.text('4-4-4'), findsOneWidget);
      expect(find.text('5-2-5'), findsOneWidget);
    });

    testWidgets('深色模式渲染', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const HomePage(),
        ),
      );
      expect(find.text('节律呼吸'), findsOneWidget);
    });
  });

  group('BreathingConfig', () {
    test('== 相等性', () {
      const a = BreathingConfig(inhaleBeats: 4, holdBeats: 7, exhaleBeats: 8);
      const b = BreathingConfig(inhaleBeats: 4, holdBeats: 7, exhaleBeats: 8);
      const c = BreathingConfig(inhaleBeats: 4, holdBeats: 4, exhaleBeats: 4);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode 一致', () {
      const a = BreathingConfig(inhaleBeats: 4, holdBeats: 7, exhaleBeats: 8);
      const b = BreathingConfig(inhaleBeats: 4, holdBeats: 7, exhaleBeats: 8);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith 正确', () {
      const original = BreathingConfig(
        inhaleBeats: 4,
        holdBeats: 7,
        exhaleBeats: 8,
        beatDuration: 1.5,
        rounds: 5,
        isInfinite: false,
      );
      final modified = original.copyWith(inhaleBeats: 6, beatDuration: 2.0);
      expect(modified.inhaleBeats, 6);
      expect(modified.beatDuration, 2.0);
      expect(modified.holdBeats, 7);
      expect(modified.exhaleBeats, 8);
    });

    test('phaseDuration 计算', () {
      const config = BreathingConfig(
        inhaleBeats: 4,
        holdBeats: 7,
        exhaleBeats: 8,
        beatDuration: 1.5,
      );
      expect(config.phaseDuration(BreathingPhase.inhale), 6.0);
      expect(config.phaseDuration(BreathingPhase.hold), 10.5);
      expect(config.phaseDuration(BreathingPhase.exhale), 12.0);
      expect(config.phaseDuration(BreathingPhase.idle), 0.0);
    });

    test('holdBeats 为 0 时 phaseDuration 为 0', () {
      const config = BreathingConfig(
        inhaleBeats: 4,
        holdBeats: 0,
        exhaleBeats: 4,
        beatDuration: 1.5,
      );
      expect(config.phaseDuration(BreathingPhase.hold), 0.0);
      expect(config.totalBeatsPerRound, 8);
    });

    test('formattedDuration 不出现分60秒进位错误', () {
      const config = BreathingConfig(
        inhaleBeats: 10,
        holdBeats: 3,
        exhaleBeats: 10,
        beatDuration: 1.3,
        rounds: 4,
      );
      // 23 * 1.3 * 4 = 119.6 秒，应进位为 2分0秒（120秒）
      expect(config.formattedDuration, '2分0秒（120秒）');
    });
  });

  group('BreathingController', () {
    test('开始、停止及销毁阶段不抛出异常且不触发残留回调', () {
      final ctrl = BreathingController();
      var endCallCount = 0;
      ctrl.onSessionEnd = (_) => endCallCount++;

      ctrl.start();
      expect(ctrl.isRunning, isTrue);
      expect(ctrl.phase, BreathingPhase.inhale);
      expect(ctrl.currentBeatNumber, 1);

      ctrl.stop();
      expect(ctrl.isRunning, isFalse);
      expect(ctrl.phase, BreathingPhase.idle);
      expect(endCallCount, 1);

      // 运行中直接 dispose 不应再触发 onSessionEnd 或 notifyListeners 异常
      ctrl.start();
      ctrl.dispose();
      expect(endCallCount, 1);
    });
  });

  group('BreathingPreset', () {
    test('预设数量', () {
      expect(BreathingPreset.presets.length, 3);
    });

    test('预设名称', () {
      final names = BreathingPreset.presets.map((p) => p.name).toList();
      expect(names, containsAll(['4-7-8', '4-4-4', '5-2-5']));
    });
  });

  group('AppTheme', () {
    test('双主题存在', () {
      expect(AppTheme.lightTheme, isA<ThemeData>());
      expect(AppTheme.darkTheme, isA<ThemeData>());
    });

    test('预缓存颜色', () {
      expect(AppTheme.primaryAlpha06, isA<Color>());
      expect(AppTheme.primaryAlpha50, isA<Color>());
    });

    test('明暗背景不同', () {
      expect(
        AppTheme.lightTheme.scaffoldBackgroundColor,
        isNot(equals(AppTheme.darkTheme.scaffoldBackgroundColor)),
      );
    });
  });
}
