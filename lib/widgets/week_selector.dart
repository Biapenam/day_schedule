import 'package:flutter/material.dart';
import '../utils/app_modal_sheet.dart';
import '../utils/app_colors.dart';
import 'app_components.dart';

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
    padding: const EdgeInsets.symmetric(horizontal: 0),
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
          child: TextButton(
            onPressed: () => _showWeekPicker(context),
            style: TextButton.styleFrom(
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
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeading(title: '选择周次', icon: Icons.date_range_rounded),
          const SizedBox(height: 8),
          Text(
            '共 $totalWeeks 周 · 点击周次跳转',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 52,
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
                      ? context.colors.primary
                      : isCurrent
                      ? context.colors.primaryContainer
                      : context.colors.inputFill,
                  foregroundColor: isSelected
                      ? context.colors.onPrimary
                      : context.colors.textPrimary,
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
