import 'package:flutter_test/flutter_test.dart';
import 'package:day_schedule/models/course.dart';

void main() {
  Course buildCourse({
    String id = 'c-1',
    String name = '高等数学',
    int dayOfWeek = 1,
    List<int> weeks = const [1, 2, 3],
    int startSection = 1,
    int endSection = 2,
  }) {
    return Course(
      id: id,
      name: name,
      teacher: '张老师',
      location: 'A-101',
      colorValue: 0xFF6C63FF,
      weeks: weeks,
      dayOfWeek: dayOfWeek,
      startSection: startSection,
      endSection: endSection,
    );
  }

  group('normalizeWeeks', () {
    test('去重并排序', () {
      expect(Course.normalizeWeeks([3, 1, 3, 2]), [1, 2, 3]);
    });

    test('过滤非正数', () {
      expect(Course.normalizeWeeks([0, -1, 5]), [5]);
    });
  });

  group('构造参数 clamp', () {
    test('星期越界收拢到 1-7', () {
      expect(buildCourse(dayOfWeek: 0).dayOfWeek, 1);
      expect(buildCourse(dayOfWeek: 9).dayOfWeek, 7);
    });

    test('节次越界收拢到 1-maxSection', () {
      expect(buildCourse(startSection: 0, endSection: 0).startSection, 1);
      expect(
        buildCourse(startSection: 99, endSection: 99).endSection,
        Course.maxSection,
      );
    });

    test('endSection 小于 startSection 时跟随 startSection', () {
      final c = buildCourse(startSection: 5, endSection: 2);
      expect(c.endSection, 5);
    });
  });

  group('overlaps 冲突检测', () {
    test('同一天、周次有交集、节次重叠 → 冲突', () {
      final a = buildCourse(
        weeks: const [1, 3],
        startSection: 1,
        endSection: 3,
      );
      final b = buildCourse(
        weeks: const [2, 3],
        startSection: 3,
        endSection: 4,
      );
      expect(Course.overlaps(a, b), isTrue);
    });

    test('不同天 → 不冲突', () {
      final a = buildCourse(dayOfWeek: 1);
      final b = buildCourse(dayOfWeek: 2);
      expect(Course.overlaps(a, b), isFalse);
    });

    test('周次无交集 → 不冲突', () {
      final a = buildCourse(weeks: const [1, 2]);
      final b = buildCourse(weeks: const [3, 4]);
      expect(Course.overlaps(a, b), isFalse);
    });

    test('节次紧邻不重叠（1-2 与 3-4）→ 不冲突', () {
      final a = buildCourse(startSection: 1, endSection: 2);
      final b = buildCourse(startSection: 3, endSection: 4);
      expect(Course.overlaps(a, b), isFalse);
    });

    test('节次边界相触（1-3 与 3-4）→ 冲突', () {
      final a = buildCourse(startSection: 1, endSection: 3);
      final b = buildCourse(startSection: 3, endSection: 4);
      expect(Course.overlaps(a, b), isTrue);
    });
  });

  group('JSON 序列化与容错', () {
    test('toJson -> fromJson 往返一致', () {
      final c = buildCourse();
      final restored = Course.fromJson(c.toJson());
      expect(restored.id, c.id);
      expect(restored.name, c.name);
      expect(restored.teacher, c.teacher);
      expect(restored.location, c.location);
      expect(restored.colorValue, c.colorValue);
      expect(restored.weeks, c.weeks);
      expect(restored.dayOfWeek, c.dayOfWeek);
      expect(restored.startSection, c.startSection);
      expect(restored.endSection, c.endSection);
    });

    test('字符串数字也能读取', () {
      final json = {
        'id': 'c-1',
        'name': '高等数学',
        'teacher': '',
        'location': '',
        'colorValue': '4293191935',
        'weeks': ['1', '2'],
        'dayOfWeek': '3',
        'startSection': '2',
        'endSection': '4',
      };
      final c = Course.fromJson(json);
      expect(c.dayOfWeek, 3);
      expect(c.startSection, 2);
      expect(c.endSection, 4);
      expect(c.weeks, [1, 2]);
    });

    test('缺失字段回退默认值', () {
      final c = Course.fromJson(const {'id': 'x', 'name': 'y'});
      expect(c.weeks, isEmpty);
      expect(c.dayOfWeek, 1);
      expect(c.startSection, 1);
      expect(c.endSection, 1);
      expect(c.colorValue, courseColors[0]);
    });

    test('无效 weeks 值被过滤', () {
      final json = {
        'id': 'x',
        'name': 'y',
        'weeks': [1, -3, 'abc', 2],
      };
      final c = Course.fromJson(json);
      expect(c.weeks, [1, 2]);
    });
  });

  group('formatWeeksSummary 周次简短格式化', () {
    test('连续周次合并为区间', () {
      expect(Course.formatWeeksSummary([1, 2, 3, 4, 5]), '第1-5周');
    });

    test('多段连续区间以逗号分隔', () {
      expect(Course.formatWeeksSummary([1, 2, 3, 7, 8]), '第1-3,7-8周');
    });

    test('单周与断续周次', () {
      expect(Course.formatWeeksSummary([3]), '第3周');
      expect(Course.formatWeeksSummary([2, 4, 6]), '第2,4,6周');
    });

    test('空列表返回空字符串', () {
      expect(Course.formatWeeksSummary([]), '');
    });
  });
}
