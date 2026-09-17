import 'package:flutter_test/flutter_test.dart';
import 'package:day_schedule/models/schedule.dart';

void main() {
  Schedule buildSchedule({
    String id = 's-1',
    String name = '2026春季学期',
    DateTime? semesterStart,
    int totalWeeks = 20,
    int dailySections = 12,
    int sectionDuration = 45,
    List<String>? sectionStartTimes,
  }) {
    return Schedule(
      id: id,
      name: name,
      semesterStart: semesterStart,
      totalWeeks: totalWeeks,
      dailySections: dailySections,
      sectionStartTimes: sectionStartTimes,
      sectionDuration: sectionDuration,
    );
  }

  group('构造参数 clamp 边界', () {
    test('totalWeeks 限制在 1-30', () {
      expect(buildSchedule(totalWeeks: 0).totalWeeks, Schedule.minTotalWeeks);
      expect(buildSchedule(totalWeeks: 99).totalWeeks, Schedule.maxTotalWeeks);
    });

    test('dailySections 限制在 4-16', () {
      expect(
        buildSchedule(dailySections: 2).dailySections,
        Schedule.minDailySections,
      );
      expect(
        buildSchedule(dailySections: 30).dailySections,
        Schedule.maxDailySections,
      );
    });

    test('sectionDuration 限制在 20-120', () {
      expect(
        buildSchedule(sectionDuration: 10).sectionDuration,
        Schedule.minSectionDuration,
      );
      expect(
        buildSchedule(sectionDuration: 300).sectionDuration,
        Schedule.maxSectionDuration,
      );
    });
  });

  group('normalizeSectionStartTimes', () {
    test('缺失的节次时间用默认值补全到 dailySections 个', () {
      final s = buildSchedule(
        dailySections: 10,
        sectionStartTimes: const ['08:00', '08:55'],
      );
      expect(s.sectionStartTimes.length, 10);
      expect(s.sectionStartTimes.sublist(0, 2), ['08:00', '08:55']);
      expect(s.sectionStartTimes[2], defaultSectionStartTimes[2]);
    });

    test('非法时间回退默认值', () {
      final s = buildSchedule(
        sectionStartTimes: const ['25:99', '08:55', 'abc'],
      );
      expect(s.sectionStartTimes[0], defaultSectionStartTimes[0]);
      expect(s.sectionStartTimes[1], '08:55');
      expect(s.sectionStartTimes[2], defaultSectionStartTimes[2]);
    });

    test('空列表时全部用默认值', () {
      final s = buildSchedule(sectionStartTimes: const []);
      expect(s.sectionStartTimes, defaultSectionStartTimes);
    });
  });

  group('JSON 序列化与容错', () {
    test('toJson -> fromJson 往返一致', () {
      final s = buildSchedule(semesterStart: DateTime(2026, 2, 23));
      final restored = Schedule.fromJson(s.toJson());
      expect(restored.id, s.id);
      expect(restored.name, s.name);
      expect(restored.semesterStart, s.semesterStart);
      expect(restored.totalWeeks, s.totalWeeks);
      expect(restored.dailySections, s.dailySections);
      expect(restored.sectionStartTimes, s.sectionStartTimes);
      expect(restored.sectionDuration, s.sectionDuration);
    });

    test('缺失字段回退默认值', () {
      final s = Schedule.fromJson(const {'id': 'x'});
      expect(s.name, '未命名课表');
      expect(s.totalWeeks, 20);
      expect(s.dailySections, 12);
      expect(s.sectionDuration, 45);
    });

    test('semesterStart 非法字符串时回退 null', () {
      final s = Schedule.fromJson(const {
        'id': 'x',
        'semesterStart': 'not-a-date',
      });
      expect(s.semesterStart, isNull);
    });

    test('copyWith clearSemesterStart 可清空学期开始日期', () {
      final s = buildSchedule(semesterStart: DateTime(2026, 2, 23));
      final cleared = s.copyWith(clearSemesterStart: true);
      expect(cleared.semesterStart, isNull);
    });
  });
}
