import 'package:flutter/material.dart';
import '../controllers/breathing_controller.dart';
import '../models/breathing_config.dart';
import '../theme/app_theme.dart';

class BreathingCircle extends StatefulWidget {
  final BreathingController controller;
  final VoidCallback onTap;

  const BreathingCircle({
    super.key,
    required this.controller,
    required this.onTap,
  });

  @override
  State<BreathingCircle> createState() => _BreathingCircleState();
}

class _BreathingCircleState extends State<BreathingCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final CurvedAnimation _curvedAnim;
  late final Animation<double> _scaleAnimation;

  static const double _minScale = 0.65;
  static const double _maxScale = 1.3;

  BreathingPhase _lastPhase = BreathingPhase.idle;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
      value: 0.0,
      // 呼吸动画是核心功能，不受系统“减少动画/关闭动画”设置压缩时长
      animationBehavior: AnimationBehavior.preserve,
    );
    _curvedAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    // 单一连续缩放映射：0.0 对应 0.65（最小尺寸），1.0 对应 1.30（最大尺寸）
    _scaleAnimation = Tween<double>(
      begin: _minScale,
      end: _maxScale,
    ).animate(_curvedAnim);

    _lastPhase = widget.controller.phase;
    widget.controller.addListener(_onBreathingStateChanged);
  }

  void _onBreathingStateChanged() {
    final ctrl = widget.controller;
    final newPhase = ctrl.phase;

    if (newPhase != _lastPhase) {
      _lastPhase = newPhase;
      _handlePhaseTransition(newPhase, ctrl);
    }
  }

  @override
  void didUpdateWidget(covariant BreathingCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onBreathingStateChanged);
      widget.controller.addListener(_onBreathingStateChanged);
      final newPhase = widget.controller.phase;
      if (newPhase != _lastPhase) {
        _lastPhase = newPhase;
        _handlePhaseTransition(newPhase, widget.controller);
      }
    }
  }

  void _handlePhaseTransition(BreathingPhase phase, BreathingController ctrl) {
    final durationMs =
        (ctrl.currentPhaseDuration * 1000).round().clamp(100, 60000);

    switch (phase) {
      case BreathingPhase.inhale:
        // 吸气：严格从基准最小尺寸（0.0）起步，在吸气时长内缓缓变大至最大尺寸（1.0）
        _animController.duration = Duration(milliseconds: durationMs);
        _animController.forward(from: 0.0);
        break;

      case BreathingPhase.hold:
        // 屏息：立即保持不动，锁定在最大尺寸（1.0）
        _animController.stop();
        _animController.value = 1.0;
        break;

      case BreathingPhase.exhale:
        // 呼气：严格从最大尺寸（1.0）起步，在呼气时长内缓缓收缩至最小尺寸（0.0）
        _animController.duration = Duration(milliseconds: durationMs);
        _animController.reverseDuration = Duration(milliseconds: durationMs);
        _animController.reverse(from: 1.0);
        break;

      case BreathingPhase.idle:
        // 停止/空闲：停止当前动画；若未归位则平滑回缩回到基准初始大小
        _animController.stop();
        if (_animController.value > 0.0) {
          _animController.animateBack(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _animController.value = 0.0;
        }
        break;
    }
  }

  String _formatElapsed(double seconds) {
    final total = seconds.floor();
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onBreathingStateChanged);
    _curvedAnim.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseSize = MediaQuery.of(context).size.width * 0.55;
    final isDark = context.isDark;
    final beatColor = isDark
        ? AppTheme.primaryLight.withValues(alpha: 0.85)
        : AppTheme.primaryAlpha70;
    final metaColor = isDark
        ? AppTheme.primaryLight.withValues(alpha: 0.65)
        : AppTheme.primaryAlpha50;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: baseSize * 1.4,
        height: baseSize * 1.4,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // 动画圆环层：静态缓存圆环绘制层，通过 GPU 变换缩放避免每帧重复计算模糊与对象分配
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                );
              },
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size(baseSize, baseSize),
                  painter: const _CirclePainter(),
                ),
              ),
            ),
            // 文字信息层：仅在阶段、拍号、轮次或整秒变化时重建
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final ctrl = widget.controller;
                final isRunning = ctrl.isRunning;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ctrl.phase.label,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.primary,
                        fontSize: isRunning ? 18 : 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                    if (isRunning) ...[
                      const SizedBox(height: 8),
                      Text(
                        ctrl.currentBeatNumber == 1
                            ? (ctrl.phase == BreathingPhase.inhale
                                ? '吸'
                                : ctrl.phase == BreathingPhase.hold
                                    ? '停'
                                    : '呼')
                            : '${ctrl.currentBeatNumber}',
                        style: TextStyle(
                          color: beatColor,
                          fontSize: 36,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ctrl.config.isInfinite
                            ? '第${ctrl.currentRound}轮'
                            : '${ctrl.currentRound}/${ctrl.config.rounds}',
                        style: TextStyle(
                          color: metaColor,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatElapsed(ctrl.totalElapsedSeconds),
                        style: TextStyle(
                          color: metaColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  const _CirclePainter();

  static final Paint _outerGlowPaint = Paint()
    ..color = AppTheme.primary.withValues(alpha: 0.15)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);

  static final Paint _innerGlowPaint = Paint()
    ..color = AppTheme.primaryLight.withValues(alpha: 0.10)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.primaryAlpha25,
          AppTheme.primaryAlpha10,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // 外层大阴影
    canvas.drawCircle(center, radius + 15, _outerGlowPaint);

    // 内层小阴影
    canvas.drawCircle(center, radius - 5, _innerGlowPaint);

    // 绘制主圆
    canvas.drawCircle(center, radius, fillPaint);
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) => false;
}
