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
      final todayWeekday = now.weekday; // 1=周一

      // 计算当前周，并判断是否在学期范围内
      int currentWeek = 1;
      bool inSemester = true;
      if (semesterStart != null) {
        final raw = _courseService.currentWeek(semesterStart);
        currentWeek = raw;
        inSemester = raw >= 1 && raw <= totalWeeks;
      }

      // 学期未开始或已结束时不显示课程（空列表）
      List<Course> todayCourses;
      if (inSemester) {
        todayCourses = courses
            .where(
              (c) =>
                  c.dayOfWeek == todayWeekday && c.weeks.contains(currentWeek),
            )
            .toList();
        todayCourses.sort((a, b) => a.startSection.compareTo(b.startSection));
      } else {
        todayCourses = <Course>[];
      }

      // 构建 JSON
      final courseList = todayCourses.map((c) {
        final startTime = Schedule.sectionStartTimeAt(
          startTimes,
          c.startSection,
        );
        final lastSectionStart = Schedule.sectionStartTimeAt(
          startTimes,
          c.endSection,
        );
        final endTime = Schedule.calcEndTime(lastSectionStart, duration);
        return {
          'name': c.name,
          'time': '$startTime-$endTime',
          'location': c.location,
        };
      }).toList();

      // 写入数据（home_widget Android 端对应 HomeWidgetPreferences）
      await HomeWidget.saveWidgetData<String>(
        'today_courses',
        jsonEncode(courseList),
      );

      // 通知 Android 刷新桌面组件
      await HomeWidget.updateWidget(androidName: _widgetName);
    } catch (e) {
      // Widget 更新失败不应影响主应用，但记录日志便于排查
      debugPrint('updateWidget failed: $e');
    }
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
