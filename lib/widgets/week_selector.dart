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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // 上一周
          _ArrowButton(
            icon: Icons.chevron_left_rounded,
            onTap: selectedWeek > 1
                ? () => onWeekChanged(selectedWeek - 1)
                : null,
          ),
          // 周次显示
          Expanded(
            child: GestureDetector(
              onTap: () => _showWeekPicker(context),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 当前周指示
                    if (selectedWeek == currentWeek)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '本周',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Text(
                      '第 $selectedWeek 周',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ $totalWeeks',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: Color(0xFFAAAAAA),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 下一周
          _ArrowButton(
            icon: Icons.chevron_right_rounded,
            onTap: selectedWeek < totalWeeks
                ? () => onWeekChanged(selectedWeek + 1)
                : null,
          ),
        ],
      ),
    );
  }

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

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ArrowButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: onTap != null
              ? Colors.white
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          color: onTap != null ? AppColors.primary : const Color(0xFFCCCCDD),
          size: 22,
        ),
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
              childAspectRatio: 1.6,
            ),
            itemCount: totalWeeks,
            itemBuilder: (_, i) {
              final week = i + 1;
              final isSelected = week == selectedWeek;
              final isCurrent = week == currentWeek;
              return GestureDetector(
                onTap: () => onSelected(week),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : isCurrent
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : const Color(0xFFF5F5FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '$week',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : isCurrent
                            ? AppColors.primary
                            : AppColors.textBody,
                      ),
                    ),
                  ),
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
