import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/breathing_config.dart';
import '../theme/app_theme.dart';

/// 自定义呼吸节奏设置卡片
class RhythmSettingsCard extends StatelessWidget {
  final BreathingConfig config;
  final bool enabled; // 运行中禁用编辑
  final ValueChanged<BreathingConfig> onChanged;

  const RhythmSettingsCard({
    super.key,
    required this.config,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: context.appCardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              '呼吸节奏设置',
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // 吸气拍数
            _buildSliderRow(
              context: context,
              label: '吸气',
              value: config.inhaleBeats.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              unit: '拍',
              onChanged: enabled
                  ? (v) => onChanged(config.copyWith(inhaleBeats: v.round()))
                  : null,
            ),

            // 屏息拍数
            _buildSliderRow(
              context: context,
              label: '屏息',
              value: config.holdBeats.toDouble(),
              min: 0,
              max: 12,
              divisions: 12,
              unit: '拍',
              onChanged: enabled
                  ? (v) => onChanged(config.copyWith(holdBeats: v.round()))
                  : null,
            ),

            // 呼气拍数
            _buildSliderRow(
              context: context,
              label: '呼气',
              value: config.exhaleBeats.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              unit: '拍',
              onChanged: enabled
                  ? (v) => onChanged(config.copyWith(exhaleBeats: v.round()))
                  : null,
            ),

            Divider(color: context.appDivider, height: 24),

            // 每拍时长
            _buildSliderRow(
              context: context,
              label: '每拍时长',
              subLabel: '${config.secondsPerRound.toStringAsFixed(1)}秒',
              value: config.beatDuration.clamp(0.5, 2.0),
              min: 0.5,
              max: 2.0,
              divisions: 15,
              unit: '秒',
              displayValue: config.beatDuration.clamp(0.5, 2.0).toStringAsFixed(1),
              onChanged: enabled
                  ? (v) =>
                        onChanged(
                          config.copyWith(
                            beatDuration: (v * 10).round() / 10.0,
                          ),
                        ) // 保留一位小数
                  : null,
            ),

            Divider(color: context.appDivider, height: 24),

            // 无限循环开关
            Row(
              children: [
                Expanded(
                  child: Text(
                    '无限循环',
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Switch(
                  value: config.isInfinite,
                  onChanged: enabled
                      ? (v) => onChanged(config.copyWith(isInfinite: v))
                      : null,
                ),
              ],
            ),

            // 循环轮数（非无限时显示）
            if (!config.isInfinite)
              _buildSliderRow(
                context: context,
                label: '循环轮数',
                value: config.rounds.toDouble().clamp(
                      1.0,
                      math.max(100.0, config.rounds.toDouble()),
                    ),
                min: 1,
                max: math.max(100.0, config.rounds.toDouble()),
                divisions: math.max(99, config.rounds - 1),
                unit: '轮',
                displayValue: '${config.rounds}',
                onValueTap: enabled
                    ? () => _showRoundsInputDialog(context)
                    : null,
                onChanged: enabled
                    ? (v) => onChanged(config.copyWith(rounds: v.round()))
                    : null,
              ),

            Divider(color: context.appDivider, height: 24),

            // 预计总用时
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: AppTheme.primaryAlpha60,
                ),
                const SizedBox(width: 8),
                Text(
                  '预计总用时：',
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  config.formattedDuration,
                  style: TextStyle(
                    color: context.appPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出手动输入循环轮数对话框
  Future<void> _showRoundsInputDialog(BuildContext context) async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _RoundsInputDialog(initialRounds: config.rounds),
    );

    if (result != null && result > 0) {
      onChanged(config.copyWith(rounds: result));
    }
  }

  Widget _buildSliderRow({
    required BuildContext context,
    required String label,
    String? subLabel,
    required double value,
    required double min,
    required double max,
    required String unit,
    required int divisions,
    String? displayValue,
    VoidCallback? onValueTap,
    ValueChanged<double>? onChanged,
  }) {
    final display = displayValue ?? value.round().toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 75,
                child: Text(
                  label,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
              if (onValueTap != null)
                InkWell(
                  onTap: onChanged != null ? onValueTap : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? AppTheme.darkPrimarySurface
                          : AppTheme.primaryAlpha08,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.primaryAlpha25,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          display,
                          style: TextStyle(
                            color: context.appPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          unit,
                          style: TextStyle(
                            color: context.appPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.edit_outlined,
                          size: 11,
                          color: AppTheme.primaryAlpha60,
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  width: 45,
                  child: Text(
                    '$display$unit',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: context.appPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (subLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: AppTheme.primaryAlpha60,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '每轮用时：',
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subLabel,
                    style: TextStyle(
                      color: context.appPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 轮数输入弹窗（独立管理 TextEditingController 生命周期，防止泄漏）
class _RoundsInputDialog extends StatefulWidget {
  final int initialRounds;

  const _RoundsInputDialog({required this.initialRounds});

  @override
  State<_RoundsInputDialog> createState() => _RoundsInputDialogState();
}

class _RoundsInputDialogState extends State<_RoundsInputDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: '${widget.initialRounds}');
    _textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _textController.text.length,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) {
      Navigator.of(context).pop(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      backgroundColor: context.appCardBackground,
      title: Text(
        '设置循环轮数',
        style: TextStyle(
          color: context.appTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: TextField(
        controller: _textController,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: InputDecoration(
          hintText: '请输入轮数 (1~999)',
          suffixText: '轮',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            borderSide: BorderSide(color: context.appDivider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
          ),
        ),
        onSubmitted: _submit,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '取消',
            style: TextStyle(color: context.appTextSecondary),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
          ),
          onPressed: () => _submit(_textController.text),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
