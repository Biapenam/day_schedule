// Separate, in-memory visual preview. The normal entry point stays empty.
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'models/course.dart';
import 'services/course_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The preview intentionally uses test storage so it never writes real data.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  await initializeDateFormatting('zh_CN', null);
  final service = CourseService();
  await service.ensureMigrated();
  final schedule = await service.getActiveSchedule();
  await service.renameSchedule(schedule!.id, '2026秋季学期');
  final now = DateTime.now();
  final monday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1 + 35));
  await service.saveSemesterStart(monday);
  final samples = [
    ('移动互联网开发技术', '陈老师', '教学楼 A201', 1, 1, 2, 0xFF356A51),
    ('大学英语', '林老师', '文科楼 302', 2, 3, 4, 0xFF77558C),
    ('Java EE开发技术与应用', '周老师', '设计楼 203', 3, 1, 3, 0xFF426B93),
    ('计算机基础', '李老师', '实验楼 406', 4, 3, 4, 0xFF886632),
    ('基于.Net的应用程序开发', '张老师', '创意工坊', 5, 1, 2, 0xFF9A5365),
    ('体育 · 羽毛球', '王老师', '体育馆', 1, 5, 6, 0xFF506A96),
    ('艺术与生活', '赵老师', '艺术楼 101', 3, 5, 6, 0xFF857239),
    ('自主学习', '', '图书馆', 7, 3, 4, 0xFF356A51),
  ];
  for (var i = 0; i < samples.length; i++) {
    final s = samples[i];
    await service.addCourse(
      Course(
        id: 'preview-$i',
        name: s.$1,
        teacher: s.$2,
        location: s.$3,
        dayOfWeek: s.$4,
        startSection: s.$5,
        endSection: s.$6,
        colorValue: s.$7,
        weeks: List.generate(20, (i) => i + 1),
      ),
    );
  }
  runApp(const DayScheduleApp());
}
