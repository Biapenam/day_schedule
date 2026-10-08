import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:day_schedule/app.dart';
import 'package:day_schedule/models/course.dart';
import 'package:day_schedule/services/course_service.dart';
import 'package:day_schedule/screens/settings_screen.dart';
import 'package:day_schedule/widgets/schedule_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          (call) async => true,
        );
  });
  Future<void> seed({bool longCourse = false}) async {
    SharedPreferences.setMockInitialValues({});
    final service = CourseService();
    await service.ensureMigrated();
    await service.addCourse(
      Course(
        id: 'sample',
        name: longCourse ? '废弃物能源资源化技术' : '高等数学',
        teacher: '陈老师',
        location: longCourse ? '松江校区教学楼2101' : '教学楼 A201',
        colorValue: 0xFF356A51,
        weeks: [1],
        dayOfWeek: 7,
        startSection: 1,
        endSection: 2,
      ),
    );
  }

  void size(WidgetTester tester, Size value) {
    tester.view.physicalSize = value;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final width in [320.0, 390.0, 1024.0, 1280.0]) {
    testWidgets(
      'home seven-day layout preserves long course metadata at $width',
      (tester) async {
        size(tester, Size(width, width >= 1000 ? 768 : 844));
        await seed(longCourse: true);
        await tester.pumpWidget(const DayScheduleApp());
        await tester.pumpAndSettle();
        final grid = find.byType(ScheduleGrid);
        for (final text in ['废弃物能源资源化技术', '松江校区教学楼2101', '陈老师']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: grid, matching: find.text(text)),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: text);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('populated seven-day schedule and week navigation at $width', (
      tester,
    ) async {
      size(tester, Size(width, 844));
      await seed();
      await tester.pumpWidget(const DayScheduleApp());
      await tester.pumpAndSettle();
      expect(find.text('高等数学'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('下一周'));
      await tester.pumpAndSettle();
      expect(find.text('第 2 周'), findsOneWidget);
      expect(find.textContaining('(非本周)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'compact phone header keeps the timetable near the top at $width',
      (tester) async {
        size(tester, Size(width, 844));
        await seed();
        final service = CourseService();
        final now = DateTime.now();
        await service.saveSemesterStart(
          DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: now.weekday - 1)),
        );
        final schedule = await service.getActiveSchedule();
        await service.renameSchedule(schedule!.id, '2026秋季学期 · 计算机科学与技术');
        await tester.pumpWidget(const DayScheduleApp());
        await tester.pumpAndSettle();
        expect(find.text('DAY SCHEDULE'), findsNothing);
        expect(
          tester.getTopLeft(find.byType(ScheduleGrid)).dy,
          lessThanOrEqualTo(120),
        );
        await tester.tap(find.text('2026秋季学期 · 计算机科学与技术'));
        await tester.pumpAndSettle();
        expect(find.text('新建'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dimensions in [
    const Size(1280, 720),
    const Size(1280, 800),
    const Size(1024, 768),
    const Size(720, 1280),
    const Size(800, 1280),
    const Size(768, 1024),
  ]) {
    testWidgets(
      'populated Pad layout ${dimensions.width} x ${dimensions.height}',
      (tester) async {
        size(tester, dimensions);
        await seed();
        await tester.pumpWidget(const DayScheduleApp());
        await tester.pumpAndSettle();
        expect(find.text('DAY SCHEDULE'), findsOneWidget);
        expect(find.text('高等数学'), findsOneWidget);
        expect(
          find.byType(NavigationRail),
          dimensions.width >= 1000 ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.text('高等数学'));
        await tester.pumpAndSettle();
        expect(find.text('编辑'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('create a course from empty state then open details', (
    tester,
  ) async {
    size(tester, const Size(390, 844));
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DayScheduleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加第一门课程'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '交互设计');
    await tester.enterText(find.byType(TextFormField).at(1), '林老师');
    await tester.enterText(find.byType(TextFormField).at(2), '设计楼 203');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect((await CourseService().loadCourses()).single.name, '交互设计');
    await tester.tap(find.text('交互设计'));
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile navigation reaches settings and schedule manager', (
    tester,
  ) async {
    size(tester, const Size(390, 844));
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DayScheduleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('课表管理'));
    await tester.pumpAndSettle();
    expect(find.text('新建'), findsOneWidget);
    Navigator.of(tester.element(find.text('新建'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('导出课表'), findsOneWidget);
    expect(find.text('从口令导入'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
