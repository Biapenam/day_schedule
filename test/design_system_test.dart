import 'package:day_schedule/app.dart';
import 'package:day_schedule/screens/add_course_screen.dart';
import 'package:day_schedule/screens/settings_screen.dart';
import 'package:day_schedule/widgets/week_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('zh_CN');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          (_) async => true,
        );
  });

  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget screen, Brightness brightness, {double scale = 1}) =>
      MaterialApp(
        theme: buildScheduleTheme(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      );

  for (final brightness in Brightness.values) {
    test('readable semantic color pairs in ${brightness.name}', () {
      final colors = buildScheduleTheme(brightness: brightness).colorScheme;
      double contrast(Color a, Color b) {
        final values = [a.computeLuminance(), b.computeLuminance()]..sort();
        return (values.last + .05) / (values.first + .05);
      }

      for (final pair in [
        (colors.onSurface, colors.surface),
        (colors.onSurfaceVariant, colors.surfaceContainerLowest),
        (colors.onPrimary, colors.primary),
        (colors.onPrimaryContainer, colors.primaryContainer),
        (colors.error, colors.surface),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
    });

    testWidgets('narrow editor supports large text in ${brightness.name}', (
      tester,
    ) async {
      viewport(tester, const Size(320, 740));
      await tester.pumpWidget(
        app(const AddCourseScreen(totalWeeks: 30), brightness, scale: 1.3),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -550));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, '双周'));
      await tester.pumpAndSettle();
      expect(find.text('已选 15 / 30 周'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings save stays reachable in ${brightness.name}', (
      tester,
    ) async {
      viewport(tester, const Size(320, 740));
      await tester.pumpWidget(
        app(const SettingsScreen(), brightness, scale: 1.3),
      );
      await tester.pumpAndSettle();
      expect(find.text('保存设置').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(find.text('保存设置').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '30-week picker scrolls in short landscape ${brightness.name}',
      (tester) async {
        viewport(tester, const Size(640, 360));
        int? selected;
        await tester.pumpWidget(
          app(
            Scaffold(
              body: WeekSelector(
                currentWeek: 1,
                selectedWeek: 1,
                totalWeeks: 30,
                onWeekChanged: (value) => selected = value,
              ),
            ),
            brightness,
          ),
        );
        await tester.tap(find.text('第 1 周'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('30'));
        await tester.pumpAndSettle();
        expect(selected, 30);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('app follows system dark appearance', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const DayScheduleApp());
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
  });
}
