import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:day_schedule/app.dart';
import 'package:day_schedule/models/course.dart';
import 'package:day_schedule/screens/add_course_screen.dart';
import 'package:day_schedule/screens/settings_screen.dart';
import 'package:day_schedule/widgets/schedule_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the schedule home screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DayScheduleApp());
    await tester.pumpAndSettle();

    expect(find.text('我的课表'), findsOneWidget);
    expect(find.text('第 1 周'), findsOneWidget);
  });

  // 覆盖常见平板比例的横屏与竖屏，验证无 RenderFlex / bottom overflow
  const tabletSizes = <String, Size>{
    '16:9 landscape': Size(1280, 720),
    '16:10 landscape': Size(1280, 800),
    '4:3 landscape': Size(1024, 768),
    '16:9 portrait': Size(720, 1280),
    '16:10 portrait': Size(800, 1280),
    '4:3 portrait': Size(768, 1024),
  };

  for (final entry in tabletSizes.entries) {
    testWidgets('home tablet ${entry.key} renders without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const DayScheduleApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('add course tablet two-column renders without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: AddCourseScreen(totalWeeks: 20)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 平板双栏布局应同时出现两栏的标题
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('上课时间'), findsOneWidget);
    expect(find.text('上课周次'), findsOneWidget);
    expect(find.text('课程颜色'), findsOneWidget);
  });

  testWidgets('settings tablet renders without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('ScheduleGrid renders non-current-week courses on empty slots', (
    WidgetTester tester,
  ) async {
    final c1 = Course(
      id: 'c1',
      name: '离散数学',
      teacher: '李老师',
      location: '301',
      colorValue: 0xFF6C63FF,
      weeks: const [2, 3],
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
    );
    final c2 = Course(
      id: 'c2',
      name: '大学物理',
      teacher: '王老师',
      location: '402',
      colorValue: 0xFFFF6584,
      weeks: const [1],
      dayOfWeek: 1,
      startSection: 3,
      endSection: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleGrid(
            courses: [c2],
            allCourses: [c1, c2],
            showNonCurrentWeekCourses: true,
            isCurrentWeek: true,
            onCourseDeleted: () {},
            onCourseEdited: () {},
            totalWeeks: 16,
            weekNumber: 1,
            currentWeek: 1,
            sectionStartTimes: const ['08:00', '08:55', '10:00', '10:55'],
            sectionDuration: 45,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('大学物理'), findsOneWidget);
    expect(find.textContaining('(非本周)'), findsOneWidget);
    expect(find.text('[第2-3周]'), findsOneWidget);
  });

  testWidgets('ScheduleGrid ignores courses without weeks', (
    WidgetTester tester,
  ) async {
    final courseWithoutWeeks = Course(
      id: 'empty-weeks',
      name: '无周次课程',
      teacher: '',
      location: '',
      colorValue: 0xFF6C63FF,
      weeks: const [],
      dayOfWeek: 6,
      startSection: 1,
      endSection: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleGrid(
            courses: const [],
            allCourses: [courseWithoutWeeks],
            showNonCurrentWeekCourses: true,
            isCurrentWeek: true,
            onCourseDeleted: () {},
            onCourseEdited: () {},
            totalWeeks: 16,
            weekNumber: 1,
            currentWeek: 1,
            sectionStartTimes: const ['08:00'],
            sectionDuration: 45,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('无周次课程'), findsNothing);
    expect(find.text('周六'), findsNothing);
  });
}
