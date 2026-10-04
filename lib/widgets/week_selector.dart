import 'package:flutter/material.dart';
import '../utils/app_modal_sheet.dart';
import '../utils/app_colors.dart';

class WeekSelector extends StatelessWidget {
  final int currentWeek;
  final int selectedWeek;
  final int totalWeeks;
  final ValueChanged<int> onWeekChanged;

  const WeekSelector({
    super.key,
    required this.currentWeek,
    required this.selectedWeek,
    required this.totalWeeks,
    required this.onWeekChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        IconButton.filledTonal(
          tooltip: '上一周',
          onPressed: selectedWeek > 1
              ? () => onWeekChanged(selectedWeek - 1)
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.tonal(
            onPressed: () => _showWeekPicker(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surfaceContainer,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '第 $selectedWeek 周',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '/ $totalWeeks',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more_rounded, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: '下一周',
          onPressed: selectedWeek < totalWeeks
              ? () => onWeekChanged(selectedWeek + 1)
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        if (currentWeek > 0 && currentWeek != selectedWeek) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: '回到本周',
            onPressed: () => onWeekChanged(currentWeek),
            icon: const Icon(Icons.today_rounded),
          ),
        ],
      ],
    ),
  );

  void _showWeekPicker(BuildContext context) {
    showAppModalSheet(
      context,
      builder: (_) => _WeekPickerSheet(
        selectedWeek: selectedWeek,
        currentWeek: currentWeek,
        totalWeeks: totalWeeks,
        onSelected: (w) {
          Navigator.pop(context);
          onWeekChanged(w);
        },
      ),
    );
  }
}

class _WeekPickerSheet extends StatelessWidget {
  final int selectedWeek;
  final int currentWeek;
  final int totalWeeks;
  final ValueChanged<int> onSelected;

  const _WeekPickerSheet({
    required this.selectedWeek,
    required this.currentWeek,
    required this.totalWeeks,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '选择周次',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.15,
            ),
            itemCount: totalWeeks,
            itemBuilder: (_, i) {
              final week = i + 1;
              final isSelected = week == selectedWeek;
              final isCurrent = week == currentWeek;
              return FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                  backgroundColor: isSelected
                      ? AppColors.primary
                      : isCurrent
                      ? AppColors.primaryContainer
                      : AppColors.inputFill,
                  foregroundColor: isSelected
                      ? Colors.white
                      : AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isSelected ? 24 : 12),
                  ),
                ),
                onPressed: () => onSelected(week),
                child: Text(
                  '$week',
                  semanticsLabel: '第 $week 周${isCurrent ? '，本周' : ''}',
                ),
              );
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
