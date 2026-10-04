import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:day_schedule/app.dart';
import 'package:day_schedule/models/course.dart';
import 'package:day_schedule/widgets/schedule_grid.dart';

void main() {
  Future<void> showCourse(
    WidgetTester tester, {
    required String name,
    int sections = 4,
    double scale = 1,
    bool otherWeek = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final course = Course(
      id: 'long-name',
      name: name,
      teacher: '任课教师',
      location: '教学楼 A201',
      colorValue: 0xFF356A51,
      weeks: [otherWeek ? 2 : 1],
      dayOfWeek: 7,
      startSection: 1,
      endSection: sections,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildScheduleTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: ScheduleGrid(
              courses: otherWeek ? [] : [course],
              allCourses: [course],
              isCurrentWeek: true,
              onCourseDeleted: () {},
              onCourseEdited: () {},
              totalWeeks: 20,
              weekNumber: 1,
              currentWeek: 1,
              sectionStartTimes: const ['08:00', '08:55', '09:50', '10:45'],
              sectionDuration: 45,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 1.3]) {
    testWidgets('long course title uses free card space at text scale $scale', (
      tester,
    ) async {
      const name = '移动互联网应用程序开发技术与实践';
      await showCourse(tester, name: name, scale: scale);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('non-current-week long title and week information both fit', (
    tester,
  ) async {
    const name = '基于.Net的应用程序开发技术';
    await showCourse(tester, name: name, otherWeek: true);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('$name (非本周)'),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(find.text('[第2周]'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short card prioritizes course title over location and teacher', (
    tester,
  ) async {
    const name = '程序设计实践';
    await showCourse(tester, name: name, sections: 1);
    expect(
      tester.renderObject<RenderParagraph>(find.text(name)).didExceedMaxLines,
      isFalse,
    );
    expect(find.text('教学楼 A201'), findsNothing);
    expect(find.text('任课教师'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('oversized title truncates only when card height is exhausted', (
    tester,
  ) async {
    const name = '这是一个远远超出单节课卡片可用高度的课程名称';
    await showCourse(tester, name: name, sections: 1);
    expect(
      tester.renderObject<RenderParagraph>(find.text(name)).didExceedMaxLines,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
