import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/course.dart';
import '../models/schedule.dart';
import '../services/course_service.dart';
import '../screens/add_course_screen.dart';
import '../utils/app_colors.dart';

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
    final color = Color(course.colorValue);
    final startTime = _getStartTime(course.startSection);
    final endTime = _getEndTime(course.endSection);
    final sections =
        '第 ${course.startSection} - ${course.endSection} 节（$startTime ~ $endTime）';
    final weeksText = _formatWeeks(course.weeks);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 课程头部卡片
          Container(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.85), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (course.teacher.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_rounded,
                              color: Colors.white70,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              course.teacher,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
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
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.book_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ).animate().scale(
            begin: const Offset(0.9, 0.9),
            duration: 350.ms,
            curve: Curves.easeOutBack,
          ),

          // 详情信息
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child:
                Column(
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
                    )
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 350.ms)
                    .slideY(begin: 0.15),
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
                    color: AppColors.secondary,
                    onTap: () => _deleteCourse(context),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 250.ms, duration: 350.ms),
          ),
        ],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除课程'),
        content: Text('确定要删除「${widget.course.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
        transitionDuration: 400.ms,
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
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFAAAAAA),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
