import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../models/course.dart';
import '../models/schedule.dart';
import '../services/course_service.dart';

class WidgetService {
  // 必须和 AndroidManifest 中 receiver 的包名一致
  static const _widgetName = 'ScheduleWidgetProvider';
  static const _platform = MethodChannel('day_schedule/widget');

  final CourseService _courseService = CourseService();

  /// 初始化：设置 App Group ID（Android 上等同于包名）
  static Future<void> init() async {
    // Android 不需要 AppGroupId，仅 iOS 需要；这里保留调用以兼容
    await HomeWidget.setAppGroupId('com.biapenam.day_schedule');
  }

  /// 推送今日课程数据到桌面小组件
  Future<void> updateWidget() async {
    try {
      await _courseService.ensureMigrated();
      final schedule = await _courseService.getActiveSchedule();
      final courses = await _courseService.loadCourses();
      final semesterStart = schedule?.semesterStart;
      final totalWeeks = schedule?.totalWeeks ?? 20;
      final startTimes =
          schedule?.sectionStartTimes ?? defaultSectionStartTimes;
      final duration = schedule?.sectionDuration ?? 45;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // 预计算整个学期（未设置学期时预计算未来 14 天），让 Android 原生
      // 小组件在跨日广播时可以读取下一天，而不是继续显示昨天的缓存。
      final rangeStart = semesterStart == null
          ? today
          : DateTime(
              semesterStart.year,
              semesterStart.month,
              semesterStart.day,
            );
      final daysToGenerate = semesterStart == null ? 14 : totalWeeks * 7;
      final coursesByDate = <String, List<Map<String, String>>>{};

      List<Map<String, String>> buildCourseList(DateTime date) {
        final week = semesterStart == null
            ? 1
            : _courseService.currentWeek(semesterStart, now: date);
        final inSemester =
            semesterStart == null || (week >= 1 && week <= totalWeeks);
        if (!inSemester) return <Map<String, String>>[];

        final dayCourses =
            courses
                .where(
                  (c) => c.dayOfWeek == date.weekday && c.weeks.contains(week),
                )
                .toList()
              ..sort((a, b) => a.startSection.compareTo(b.startSection));
        return dayCourses
            .map((course) => _courseToWidgetMap(course, startTimes, duration))
            .toList();
      }

      for (var offset = 0; offset < daysToGenerate; offset++) {
        final date = rangeStart.add(Duration(days: offset));
        coursesByDate[_dateKey(date)] = buildCourseList(date);
      }

      final courseList =
          coursesByDate[_dateKey(today)] ?? buildCourseList(today);

      // 写入按日期索引的完整缓存。保留 today_courses 兼容旧版本小组件。
      await HomeWidget.saveWidgetData<String>(
        'widget_courses_by_date',
        jsonEncode(coursesByDate),
      );
      await HomeWidget.saveWidgetData<String>(
        'today_courses',
        jsonEncode(courseList),
      );
      await HomeWidget.saveWidgetData<String>(
        'today_courses_date',
        _dateKey(today),
      );

      // 通知 Android 刷新桌面组件
      await HomeWidget.updateWidget(androidName: _widgetName);
    } catch (e) {
      // Widget 更新失败不应影响主应用，但记录日志便于排查
      debugPrint('updateWidget failed: $e');
    }
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static Map<String, String> _courseToWidgetMap(
    Course course,
    List<String> startTimes,
    int duration,
  ) {
    final startTime = Schedule.sectionStartTimeAt(
      startTimes,
      course.startSection,
    );
    final lastSectionStart = Schedule.sectionStartTimeAt(
      startTimes,
      course.endSection,
    );
    final endTime = Schedule.calcEndTime(lastSectionStart, duration);
    return {
      'name': course.name,
      'time': '$startTime-$endTime',
      'location': course.location,
    };
  }

  Future<String> requestPinWidget() async {
    try {
      await updateWidget();
      return await _platform.invokeMethod<String>('requestPinWidget') ??
          'unknown';
    } on PlatformException catch (e) {
      return e.code;
    }
  }
}
