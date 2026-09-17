import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:day_schedule/models/course.dart';
import 'package:day_schedule/models/schedule.dart';
import 'package:day_schedule/services/course_service.dart';
import 'package:day_schedule/services/import_export_service.dart';
import 'package:day_schedule/widgets/import_export_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Schedule buildSchedule() => Schedule(
    id: 's-1',
    name: '2026春季学期',
    semesterStart: DateTime(2026, 2, 23),
    totalWeeks: 20,
    dailySections: 12,
    sectionDuration: 45,
    // 远程 Schedule 模型会把节次时间补全到 dailySections 个
    sectionStartTimes: List<String>.from(defaultSectionStartTimes),
  );

  List<Course> buildCourses() => [
    Course(
      id: 'c-1',
      name: '高等数学',
      teacher: '张老师',
      location: 'A-101',
      colorValue: 0xFF6C63FF,
      weeks: [1, 2, 3, 4, 5, 6],
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
    ),
    Course(
      id: 'c-2',
      name: '大学英语',
      teacher: '',
      location: '',
      colorValue: 0xFFFF6584,
      weeks: [1, 3, 5],
      dayOfWeek: 3,
      startSection: 3,
      endSection: 4,
    ),
  ];

  test('encode -> decode 往返数据一致', () {
    final code = ImportExportService.encode(buildSchedule(), buildCourses());

    expect(code.startsWith('OS1:'), isTrue);

    final data = ImportExportService.decode(code);
    expect(data.schedule.name, '2026春季学期');
    expect(data.schedule.totalWeeks, 20);
    expect(data.schedule.dailySections, 12);
    expect(data.schedule.sectionDuration, 45);
    expect(data.schedule.semesterStart, DateTime(2026, 2, 23));
    expect(data.schedule.sectionStartTimes, defaultSectionStartTimes);

    expect(data.courses.length, 2);
    final first = data.courses.first;
    expect(first.name, '高等数学');
    expect(first.teacher, '张老师');
    expect(first.location, 'A-101');
    expect(first.colorValue, 0xFF6C63FF);
    expect(first.weeks, [1, 2, 3, 4, 5, 6]);
    expect(first.dayOfWeek, 1);
    expect(first.startSection, 1);
    expect(first.endSection, 2);
    // 导入时应重新生成 id，避免跨设备冲突
    expect(first.id, isNot('c-1'));
    expect(data.schedule.id, isNot('s-1'));
  });

  test('空课表也能导出导入', () {
    final schedule = Schedule(id: 's-2', name: '空课表');
    final code = ImportExportService.encode(schedule, const []);
    final data = ImportExportService.decode(code);
    expect(data.courses, isEmpty);
    expect(data.schedule.name, '空课表');
  });

  test('校验码被破坏时抛出 FormatException', () {
    final code = ImportExportService.encode(buildSchedule(), buildCourses());
    // 改动最后一位校验字符
    final corrupted =
        code.substring(0, code.length - 1) + (code.endsWith('A') ? 'B' : 'A');
    expect(() => ImportExportService.decode(corrupted), throwsFormatException);
  });

  test('缺少前缀时抛出 FormatException', () {
    expect(
      () => ImportExportService.decode('hello world'),
      throwsFormatException,
    );
    expect(() => ImportExportService.decode(''), throwsFormatException);
  });

  test('粘贴时混入换行 / 空白也能解析', () {
    final code = ImportExportService.encode(buildSchedule(), buildCourses());
    final messy = '\n  ${code.substring(0, 20)}\n${code.substring(20)} \n';
    final data = ImportExportService.decode(messy);
    expect(data.courses.length, 2);
  });

  test('导入时拒绝超出课表周次范围的课程', () {
    final schedule = Schedule(
      id: 's-invalid-week',
      name: '一周课表',
      totalWeeks: 1,
    );
    final course = Course(
      id: 'c-invalid-week',
      name: '超范围课程',
      teacher: '',
      location: '',
      colorValue: courseColors[0],
      weeks: const [2],
      dayOfWeek: 1,
      startSection: 1,
      endSection: 1,
    );
    final code = ImportExportService.encode(schedule, [course]);

    expect(
      () => ImportExportService.decode(code),
      throwsA(isA<FormatException>()),
    );
  });

  test('导入时拒绝超出每天节数范围的课程', () {
    final schedule = Schedule(
      id: 's-invalid-section',
      name: '四节课表',
      dailySections: 4,
    );
    final course = Course(
      id: 'c-invalid-section',
      name: '超范围课程',
      teacher: '',
      location: '',
      colorValue: courseColors[0],
      weeks: const [1],
      dayOfWeek: 1,
      startSection: 5,
      endSection: 5,
    );
    final code = ImportExportService.encode(schedule, [course]);

    expect(
      () => ImportExportService.decode(code),
      throwsA(isA<FormatException>()),
    );
  });

  // ── 导入流程集成测试 ─────────────────────────────────────

  Future<void> openImportSheet(
    WidgetTester tester,
    CourseService service,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  isScrollControlled: true,
                  builder: (_) => ImportSheet(service: service),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> parseAndTapImport(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.text('解析口令'));
    await tester.pumpAndSettle();
    final importBtn = find.text('导入 2026春季学期');
    await tester.ensureVisible(importBtn);
    await tester.pumpAndSettle();
    await tester.tap(importBtn);
    await tester.pumpAndSettle();
  }

  testWidgets('导入：无同名课表时直接导入，名称不加后缀', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = CourseService();
    await service.ensureMigrated();
    final code = ImportExportService.encode(buildSchedule(), buildCourses());

    await openImportSheet(tester, service);
    await parseAndTapImport(tester, code);

    final schedules = await service.loadSchedules();
    final imported = schedules.where((s) => s.name == '2026春季学期');
    expect(imported.length, 1);
    final courses = await service.loadCoursesFor(imported.first.id);
    expect(courses.length, 2);
    expect(courses.first.name, '高等数学');
  });

  testWidgets('导入：同名课表时另存为新课表（名称带后缀）', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = CourseService();
    await service.ensureMigrated();
    await service.createSchedule('2026春季学期'); // 制造同名
    final code = ImportExportService.encode(buildSchedule(), buildCourses());

    await openImportSheet(tester, service);
    await parseAndTapImport(tester, code);

    expect(find.text('已存在同名课表'), findsOneWidget);
    await tester.tap(find.text('另存为新课表'));
    await tester.pumpAndSettle();

    final schedules = await service.loadSchedules();
    expect(schedules.where((s) => s.name == '2026春季学期 (导入)').length, 1);
  });

  testWidgets('导入：同名课表时选择覆盖保留原课表 id', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = CourseService();
    await service.ensureMigrated();
    final existing = await service.createSchedule('2026春季学期');
    await service.saveCoursesFor(existing.id, [
      Course(
        id: 'old-1',
        name: '旧课程',
        teacher: '',
        location: '',
        colorValue: 0xFF000000,
        weeks: const [1],
        dayOfWeek: 1,
        startSection: 1,
        endSection: 1,
      ),
    ]);
    final code = ImportExportService.encode(buildSchedule(), buildCourses());

    await openImportSheet(tester, service);
    await parseAndTapImport(tester, code);

    await tester.tap(find.text('覆盖'));
    await tester.pumpAndSettle();

    final schedules = await service.loadSchedules();
    final imported = schedules.firstWhere((s) => s.name == '2026春季学期');
    expect(imported.id, existing.id); // 保留原 id
    final courses = await service.loadCoursesFor(imported.id);
    expect(courses.length, 2); // 课程被替换为口令中的课程
    expect(courses.any((c) => c.name == '旧课程'), isFalse);
  });

  testWidgets('导入弹窗：键盘弹出时口令输入框不被遮挡', (WidgetTester tester) async {
    // 模拟输入法弹出（底部 300 逻辑像素；viewInsets 以物理像素为单位，
    // MediaQuery 会按 devicePixelRatio 换算成逻辑像素）
    tester.view.viewInsets = FakeViewPadding(
      bottom: 300 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final service = CourseService();
    await service.ensureMigrated();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                // 与 settings_screen 的 _openImport 一致：用 viewInsets 抬升面板
                onPressed: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  isScrollControlled: true,
                  constraints: const BoxConstraints(maxWidth: 640),
                  builder: (sheetContext) => Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                    ),
                    child: ImportSheet(service: service),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 聚焦口令输入框，触发自动滚动到可见区域
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(TextField));
    // 默认测试窗口 800x600，键盘 300 → 键盘上方可视区域为 0..300
    const visibleBottom = 600.0 - 300.0;
    expect(
      rect.top,
      greaterThanOrEqualTo(0),
      reason: '输入框顶部不应超出屏幕顶部，实际 top=${rect.top}',
    );
    expect(
      rect.bottom,
      lessThanOrEqualTo(visibleBottom + 1),
      reason: '输入框底部不应被键盘遮挡，实际 bottom=${rect.bottom}',
    );
  });
}
