import 'package:flutter/material.dart';
import '../models/course.dart';
import '../models/schedule.dart';
import '../utils/app_colors.dart';

class DayOverview extends StatelessWidget {
  final List<Course> courses;
  final List<String> sectionStartTimes;
  final VoidCallback onAddCourse;
  final ValueChanged<Course> onCourseTap;

  const DayOverview({
    super.key,
    required this.courses,
    required this.sectionStartTimes,
    required this.onAddCourse,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.wb_sunny_outlined,
                    color: AppColors.onPrimaryContainer,
                  ),
                  Spacer(),
                  Text(
                    'TODAY',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                '今日 ${today.length} 门课程',
                style: const TextStyle(
                  fontSize: 26,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '本周 ${courses.length} 门课程 · $sections 节',
                style: const TextStyle(color: AppColors.onPrimaryContainer),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text('今日安排', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              '${today.length} 门课',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (today.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.coffee_outlined, color: AppColors.primary),
                SizedBox(height: 12),
                Text('今天没有课程'),
                SizedBox(height: 6),
                Text(
                  '本周课程见左侧课表。',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ...today.map(
          (course) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                onTap: () => onCourseTap(course),
                leading: Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(course.colorValue),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                title: Text(
                  course.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${Schedule.sectionStartTimeAt(sectionStartTimes, course.startSection)}${course.location.isEmpty ? '' : ' · ${course.location}'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onAddCourse,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('安排一门新课程'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
