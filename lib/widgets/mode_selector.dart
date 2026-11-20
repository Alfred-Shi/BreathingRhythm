import 'package:flutter/material.dart';
import '../models/breathing_config.dart';
import '../theme/app_theme.dart';

/// 快捷模式横向选择组件
class ModeSelector extends StatelessWidget {
  final int selectedIndex; // -1 表示自定义模式
  final bool enabled; // 是否启用选择
  final ValueChanged<int> onSelected;

  const ModeSelector({
    super.key,
    required this.selectedIndex,
    this.enabled = true,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final presets = BreathingPreset.presets;
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: presets.length + 1, // +1 自定义模式
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index < presets.length) {
            return _buildPresetChip(
              context: context,
              name: presets[index].name,
              description: presets[index].description,
              isSelected: selectedIndex == index,
              onTap: enabled ? () => onSelected(index) : null,
            );
          }
          // 自定义模式
          return _buildPresetChip(
            context: context,
            name: '自定义',
            description: '自由设置',
            isSelected: selectedIndex == -1,
            onTap: enabled ? () => onSelected(-1) : null,
          );
        },
      ),
    );
  }

  Widget _buildPresetChip({
    required BuildContext context,
    required String name,
    required String description,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.45,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : context.appCardBackground,
          borderRadius: BorderRadius.circular(30), // 胶囊形状
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : context.appDivider,
            width: 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.primaryAlpha25, blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : context.appTextPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.whiteAlpha80
                    : context.appTextSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
