import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:day_schedule/app.dart';
import 'package:day_schedule/models/course.dart';
import 'package:day_schedule/screens/add_course_screen.dart';
import 'package:day_schedule/services/course_service.dart';
import 'package:day_schedule/widgets/adaptive_orientation.dart';
import 'package:day_schedule/widgets/schedule_grid.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final orientationRequests = <List<String>>[];
  setUp(() {
    orientationRequests.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientationRequests.add(List<String>.from(call.arguments as List));
        }
        return null;
      },
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (call) async => true,
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      null,
    );
  });

  void display(WidgetTester tester, Size logicalSize, {Size? windowSize}) {
    tester.view.devicePixelRatio = 2;
    tester.view.display.size = logicalSize * 2;
    tester.view.physicalSize = (windowSize ?? logicalSize) * 2;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.reset();
      tester.view.display.reset();
    });
  }

  Future<void> mountPolicy(WidgetTester tester) =>
      tester.pumpWidget(const AdaptiveOrientation(child: SizedBox.shrink()));

  for (final phoneSize in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('phone display stays portrait at $phoneSize', (tester) async {
      display(tester, phoneSize);
      await mountPolicy(tester);
      await tester.pump();
      expect(orientationRequests, [
        ['DeviceOrientation.portraitUp'],
      ]);
      expect(tester.takeException(), isNull);
    });
  }

  for (final tabletSize in [const Size(600, 960), const Size(960, 600)]) {
    testWidgets('600dp tablet follows system rotation at $tabletSize', (
      tester,
    ) async {
      display(tester, tabletSize);
      await mountPolicy(tester);
      await tester.pump();
      expect(orientationRequests, [<String>[]]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('letterboxed tablet uses the complete display', (tester) async {
    display(tester, const Size(1280, 800), windowSize: const Size(390, 800));
    await mountPolicy(tester);
    await tester.pump();
    expect(orientationRequests, [<String>[]]);
  });

  testWidgets(
    'startup metrics arrive after the first frame without a portrait lock',
    (tester) async {
      display(tester, Size.zero, windowSize: Size.zero);
      await mountPolicy(tester);
      await tester.pump();
      expect(orientationRequests, isEmpty);
      tester.view.display.size = const Size(1600, 2560);
      tester.view.physicalSize = const Size(1600, 2560);
      await tester.pump();
      expect(orientationRequests, [<String>[]]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('display changes release a previous phone orientation lock', (
    tester,
  ) async {
    display(tester, const Size(390, 844));
    await mountPolicy(tester);
    await tester.pump();
    tester.view.display.size = const Size(2560, 1600);
    tester.view.physicalSize = const Size(780, 1600);
    await tester.pump();
    expect(orientationRequests, [
      ['DeviceOrientation.portraitUp'],
      <String>[],
    ]);
    // Resizing a tablet window must not reintroduce a phone orientation lock.
    tester.view.physicalSize = const Size(720, 1280);
    await tester.pump();
    expect(orientationRequests.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed policy does not react to later screen changes', (
    tester,
  ) async {
    display(tester, const Size(390, 844));
    await mountPolicy(tester);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    orientationRequests.clear();
    tester.view.display.size = const Size(2560, 1600);
    await tester.pump();
    expect(orientationRequests, isEmpty);
  });

  testWidgets(
    'Windows does not receive Android orientation requests',
    (tester) async {
      display(tester, const Size(390, 844));
      await mountPolicy(tester);
      await tester.pump();
      expect(orientationRequests, isEmpty);
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );

  for (final portrait in [
    const Size(800, 1280),
    const Size(768, 1024),
    const Size(600, 960),
  ]) {
    testWidgets('tablet homepage rotates and retains courses at $portrait', (
      tester,
    ) async {
      display(tester, portrait);
      SharedPreferences.setMockInitialValues({});
      final service = CourseService();
      await service.ensureMigrated();
      final now = DateTime.now();
      await service.saveSemesterStart(
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1)),
      );
      await service.addCourse(
        Course(
          id: 'rotation-course',
          name: '七天课表课程',
          teacher: '梁老师',
          location: '教学楼2101',
          dayOfWeek: 7,
          startSection: 1,
          endSection: 2,
          weeks: [1],
          colorValue: 0xFF356A51,
        ),
      );
      await tester.pumpWidget(
        const AdaptiveOrientation(child: DayScheduleApp()),
      );
      await tester.pumpAndSettle();
      Finder gridCourse(String name) => find.descendant(
        of: find.byType(ScheduleGrid),
        matching: find.text(name),
      );
      expect(gridCourse('七天课表课程'), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      await tester.tap(find.byTooltip('下一周'));
      await tester.pumpAndSettle();
      expect(find.text('第 2 周'), findsOneWidget);
      final landscape = Size(portrait.height, portrait.width);
      tester.view.display.size = landscape * 2;
      tester.view.physicalSize = landscape * 2;
      await tester.pumpAndSettle();
      expect(
        MediaQuery.of(tester.element(find.byType(ScheduleGrid))).orientation,
        Orientation.landscape,
      );
      expect(
        find.byType(NavigationRail),
        landscape.width >= 1000 ? findsOneWidget : findsNothing,
      );
      expect(gridCourse('七天课表课程 (非本周)'), findsOneWidget);
      expect(find.text('第 2 周'), findsOneWidget);
      expect(find.text('留一点时间，给自己'), findsNothing);
      expect(orientationRequests, [<String>[]]);
      expect(tester.takeException(), isNull);
      tester.view.display.size = portrait * 2;
      tester.view.physicalSize = portrait * 2;
      await tester.pumpAndSettle();
      expect(
        MediaQuery.of(tester.element(find.byType(ScheduleGrid))).orientation,
        Orientation.portrait,
      );
      expect(find.byType(NavigationRail), findsNothing);
      expect(gridCourse('七天课表课程 (非本周)'), findsOneWidget);
      expect(find.text('第 2 周'), findsOneWidget);
      expect((await service.loadCourses()).single.id, 'rotation-course');
      expect(orientationRequests, [<String>[]]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tablet rotation preserves an unsaved course and saves it', (
    tester,
  ) async {
    display(tester, const Size(800, 1280));
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AdaptiveOrientation(child: DayScheduleApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加第一门课程'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '横竖屏编辑验证');
    await tester.enterText(find.byType(TextFormField).at(1), '林老师');
    await tester.enterText(find.byType(TextFormField).at(2), '教学楼2101');
    for (final size in [const Size(1280, 800), const Size(800, 1280)]) {
      tester.view.display.size = size * 2;
      tester.view.physicalSize = size * 2;
      await tester.pumpAndSettle();
      expect(find.byType(AddCourseScreen), findsOneWidget);
      expect(find.text('横竖屏编辑验证'), findsOneWidget);
      expect(find.text('林老师'), findsOneWidget);
      expect(find.text('教学楼2101'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final saved = (await CourseService().loadCourses()).single;
    expect(saved.name, '横竖屏编辑验证');
    expect(saved.teacher, '林老师');
    expect(saved.location, '教学楼2101');
    expect(orientationRequests, [<String>[]]);
    expect(tester.takeException(), isNull);
  });
}
