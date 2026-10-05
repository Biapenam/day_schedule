import 'package:flutter/material.dart';
import '../models/course.dart';
import '../models/schedule.dart';
import '../services/course_service.dart';
import '../screens/add_course_screen.dart';
import '../utils/app_colors.dart';
import 'app_components.dart';

class CourseDetailSheet extends StatefulWidget {
  final Course course;
  final VoidCallback onDeleted;
  final VoidCallback onEdited;
  final int totalWeeks;
  final List<String> sectionStartTimes;
  final int sectionDuration;

  const CourseDetailSheet({
    super.key,
    required this.course,
    required this.onDeleted,
    required this.onEdited,
    required this.totalWeeks,
    required this.sectionStartTimes,
    required this.sectionDuration,
  });

  @override
  State<CourseDetailSheet> createState() => _CourseDetailSheetState();
}

class _CourseDetailSheetState extends State<CourseDetailSheet> {
  final CourseService _service = CourseService();

  String _getStartTime(int section) =>
      Schedule.sectionStartTimeAt(widget.sectionStartTimes, section);

  String _getEndTime(int section) =>
      Schedule.calcEndTime(_getStartTime(section), widget.sectionDuration);

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final courseScheme = ColorScheme.fromSeed(
      seedColor: Color(course.colorValue),
      brightness: Theme.of(context).brightness,
    );
    final color = courseScheme.primary;
    final startTime = _getStartTime(course.startSection);
    final endTime = _getEndTime(course.endSection);
    final sections =
        '第 ${course.startSection} - ${course.endSection} 节（$startTime ~ $endTime）';
    final weeksText = _formatWeeks(course.weeks);

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SheetHeading(
                title: '课程详情',
                icon: Icons.menu_book_outlined,
              ),
            ),

            // 课程头部卡片
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: courseScheme.primaryContainer,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          style: TextStyle(
                            color: courseScheme.onPrimaryContainer,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (course.teacher.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                color: courseScheme.onPrimaryContainer,
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  course.teacher,
                                  style: TextStyle(
                                    color: courseScheme.onPrimaryContainer,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: courseScheme.onPrimaryContainer.withValues(
                        alpha: 0.08,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.book_rounded,
                      color: courseScheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            // 详情信息
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.access_time_rounded,
                    color: color,
                    label: '上课时间',
                    value: '${dayNames[course.dayOfWeek]}  $sections',
                  ),
                  const SizedBox(height: 12),
                  if (course.location.isNotEmpty) ...[
                    _InfoRow(
                      icon: Icons.location_on_rounded,
                      color: color,
                      label: '上课地点',
                      value: course.location,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _InfoRow(
                    icon: Icons.calendar_month_rounded,
                    color: color,
                    label: '上课周次',
                    value: weeksText,
                  ),
                ],
              ),
            ),

            // 操作按钮
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: '编辑',
                      icon: Icons.edit_rounded,
                      color: color,
                      onTap: () => _editCourse(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      label: '删除',
                      icon: Icons.delete_rounded,
                      color: context.colors.error,
                      onTap: () => _deleteCourse(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatWeeks(List<int> weeks) {
    if (weeks.isEmpty) return '无';
    weeks = List<int>.from(weeks)..sort();
    final result = <String>[];
    int start = weeks.first, prev = weeks.first;
    for (int i = 1; i < weeks.length; i++) {
      if (weeks[i] == prev + 1) {
        prev = weeks[i];
      } else {
        result.add(start == prev ? '第$start周' : '第$start-$prev周');
        start = weeks[i];
        prev = weeks[i];
      }
    }
    result.add(start == prev ? '第$start周' : '第$start-$prev周');
    return result.join('，');
  }

  void _deleteCourse(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('删除课程'),
        content: Text('确定要删除「${widget.course.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await _service.deleteCourse(widget.course.id);
      if (context.mounted) Navigator.pop(context);
      widget.onDeleted();
    }
  }

  void _editCourse(BuildContext context) async {
    Navigator.pop(context);
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, _) => AddCourseScreen(
          totalWeeks: widget.totalWeeks,
          editingCourse: widget.course,
        ),
        transitionsBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
      ),
    );
    if (result == true) widget.onEdited();
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(foregroundColor: color),
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}
