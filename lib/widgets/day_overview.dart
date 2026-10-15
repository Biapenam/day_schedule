import 'package:flutter/material.dart';
import '../models/course.dart';
import '../models/schedule.dart';
import '../utils/app_colors.dart';
import 'app_components.dart';

class DayOverview extends StatelessWidget {
  final List<Course> courses;
  final List<String> sectionStartTimes;
  final ValueChanged<Course> onCourseTap;
  const DayOverview({
    super.key,
    required this.courses,
    required this.sectionStartTimes,
    required this.onCourseTap,
  });

  @override
  Widget build(BuildContext context) {
    final today =
        courses.where((c) => c.dayOfWeek == DateTime.now().weekday).toList()
          ..sort((a, b) => a.startSection.compareTo(b.startSection));
    final sections = courses.fold<int>(
      0,
      (sum, c) => sum + c.endSection - c.startSection + 1,
    );
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.colors.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: context.colors.onPrimaryContainer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.today_outlined,
                      size: 20,
                      color: context.colors.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '今天',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${today.length}',
                  style: text.displayLarge?.copyWith(
                    fontSize: 52,
                    color: context.colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('门课程'),
                const SizedBox(height: 24),
                Divider(
                  color: context.colors.onPrimaryContainer.withValues(
                    alpha: 0.15,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(value: '${courses.length}', label: '本周课程'),
                    ),
                    Expanded(
                      child: _Metric(value: '$sections', label: '本周节次'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        AppSectionCard(
          title: '今日安排',
          subtitle: today.isEmpty ? null : '按上课时间排序',
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            children: [
              if (today.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.coffee_outlined,
                        color: context.colors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text('今天没有课程', style: text.bodyMedium)),
                    ],
                  ),
                ),
              ...today.map((course) {
                final scheme = ColorScheme.fromSeed(
                  seedColor: Color(course.colorValue),
                  brightness: Theme.of(context).brightness,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: context.colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onCourseTap(course),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 3,
                              height: 46,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Schedule.sectionStartTimeAt(
                                      sectionStartTimes,
                                      course.startSection,
                                    ),
                                    style: text.labelMedium?.copyWith(
                                      color: scheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    course.name,
                                    style: text.titleSmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (course.location.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      course.location,
                                      style: text.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: context.colors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
