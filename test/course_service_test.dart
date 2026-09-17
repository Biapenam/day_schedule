import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:day_schedule/models/course.dart';
import 'package:day_schedule/models/schedule.dart';
import 'package:day_schedule/services/course_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<CourseService> createService() async {
    SharedPreferences.setMockInitialValues({});
    final service = CourseService();
    await service.ensureMigrated();
    return service;
  }

  group('课程 CRUD', () {
    test('添加 / 读取 / 更新 / 删除 往返', () async {
      final service = await createService();

      await service.addCourse(buildCourse());
      var courses = await service.loadCourses();
      expect(courses.length, 1);
      expect(courses.first.name, '高等数学');

      await service.updateCourse(buildCourse(name: '线性代数'));
      courses = await service.loadCourses();
      expect(courses.first.name, '线性代数');

      await service.deleteCourse('c-1');
      courses = await service.loadCourses();
      expect(courses, isEmpty);
    });

    test('saveCoursesFor 写入指定课表，与激活课表隔离', () async {
      final service = await createService();
      final s1 = await service.createSchedule('课表A');
      final s2 = await service.createSchedule('课表B');

      await service.saveCoursesFor(s1.id, [buildCourse()]);
      await service.saveCoursesFor(s2.id, [buildCourse(id: 'c-2', name: '英语')]);

      expect((await service.loadCoursesFor(s1.id)).length, 1);
      expect((await service.loadCoursesFor(s2.id)).first.name, '英语');
    });

    test('主课程数据损坏时从最近一次备份恢复', () async {
      final service = await createService();
      final scheduleId = await service.getActiveScheduleId();
      expect(scheduleId, isNotNull);

      await service.saveCoursesFor(scheduleId!, [buildCourse()]);
      await service.saveCoursesFor(scheduleId, [
        buildCourse(),
        buildCourse(id: 'c-2', name: '英语'),
      ]);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('courses_$scheduleId', '{{{ invalid');

      final recovered = await service.loadCoursesFor(scheduleId);
      expect(recovered.map((course) => course.id), ['c-1']);
      expect(prefs.getString('courses_$scheduleId'), isNot('{{{ invalid'));
    });
  });

  group('多课表管理', () {
    test('创建课表（空名回退默认名）', () async {
      final service = await createService();
      final s = await service.createSchedule('   ');
      expect(s.name, '新课表');
      final schedules = await service.loadSchedules();
      expect(schedules.length, 2); // 迁移产生的默认课表 + 新建
    });

    test('重命名课表', () async {
      final service = await createService();
      final s = await service.createSchedule('旧名字');
      await service.renameSchedule(s.id, '新名字');
      final schedules = await service.loadSchedules();
      expect(schedules.firstWhere((x) => x.id == s.id).name, '新名字');
    });

    test('删除课表：至少保留一个', () async {
      final service = await createService();
      final schedules = await service.loadSchedules();
      expect(schedules.length, 1);
      await service.deleteSchedule(schedules.first.id);
      expect((await service.loadSchedules()).length, 1);
    });

    test('删除当前激活课表后自动切换到剩余课表', () async {
      final service = await createService();
      final s1 = await service.createSchedule('课表A');
      final s2 = await service.createSchedule('课表B');
      await service.setActiveSchedule(s2.id);

      await service.deleteSchedule(s2.id);

      final active = await service.getActiveSchedule();
      expect(active!.id, isNot(s2.id));
      // 回退到剩余课表的第一个（迁移产生的默认课表）
      final remaining = await service.loadSchedules();
      expect(active.id, remaining.first.id);
      expect(remaining.any((s) => s.id == s1.id), isTrue);
    });

    test('active id 失效时回退到第一个课表', () async {
      final service = await createService();
      await service.createSchedule('课表A');
      await service.setActiveSchedule('不存在的id');
      final active = await service.getActiveSchedule();
      final schedules = await service.loadSchedules();
      expect(active!.id, schedules.first.id);
    });

    test('active id 失效时课程读取也回退到第一个课表', () async {
      final service = await createService();
      final schedules = await service.loadSchedules();
      await service.saveCoursesFor(schedules.first.id, [buildCourse()]);
      await service.setActiveSchedule('不存在的id');

      final courses = await service.loadCourses();
      expect(courses.map((course) => course.id), ['c-1']);
      expect(await service.getActiveScheduleId(), schedules.first.id);
    });

    test('主课表数据损坏时从最近一次备份恢复', () async {
      final service = await createService();
      await service.createSchedule('课表A');
      await service.createSchedule('课表B');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('schedules', '{{{ invalid');

      final recovered = await service.loadSchedules();
      expect(recovered.length, 2);
      expect(recovered.map((schedule) => schedule.name), ['我的课表', '课表A']);
      expect(prefs.getString('schedules'), isNot('{{{ invalid'));
    });
  });

  group('旧数据迁移', () {
    test('旧全局 key 迁移到多课表结构并清理旧 key', () async {
      SharedPreferences.setMockInitialValues({
        'courses': jsonEncode([
          buildCourse().toJson(),
          buildCourse(id: 'c-2', name: '英语').toJson(),
        ]),
        'semester_start': '2026-02-23T00:00:00.000',
        'total_weeks': 18,
        'daily_sections': 10,
        'section_times': jsonEncode(['08:00', '08:55']),
        'section_duration': 40,
      });
      final service = CourseService();
      await service.ensureMigrated();

      final schedules = await service.loadSchedules();
      expect(schedules.length, 1);
      final s = schedules.first;
      expect(s.name, '我的课表');
      expect(s.semesterStart, DateTime(2026, 2, 23));
      expect(s.totalWeeks, 18);
      expect(s.dailySections, 10);
      expect(s.sectionDuration, 40);
      expect(s.sectionStartTimes.sublist(0, 2), ['08:00', '08:55']);

      final activeId = await service.getActiveScheduleId();
      expect(activeId, s.id);

      final courses = await service.loadCoursesFor(s.id);
      expect(courses.length, 2);

      // 旧 key 已清理
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('courses'), isNull);
      expect(prefs.getString('semester_start'), isNull);
      expect(prefs.getString('total_weeks'), isNull);
    });

    test('损坏的旧课程 JSON 不阻断迁移', () async {
      SharedPreferences.setMockInitialValues({
        'courses': '{{{ 不是 JSON',
        'semester_start': '2026-02-23',
      });
      final service = CourseService();
      await service.ensureMigrated();
      final schedules = await service.loadSchedules();
      expect(schedules.length, 1);
      expect((await service.loadCoursesFor(schedules.first.id)), isEmpty);
    });

    test('空 id / 空名的课程在迁移时被过滤', () async {
      SharedPreferences.setMockInitialValues({
        'courses': jsonEncode([
          {'id': '', 'name': '无id'},
          {'id': 'c-1', 'name': ''},
          buildCourse().toJson(),
        ]),
      });
      final service = CourseService();
      await service.ensureMigrated();
      final schedules = await service.loadSchedules();
      final courses = await service.loadCoursesFor(schedules.first.id);
      expect(courses.length, 1);
      expect(courses.first.name, '高等数学');
    });
  });

  group('工具方法', () {
    test('calcEndTime 常规计算', () {
      expect(Schedule.calcEndTime('08:00', 45), '08:45');
      expect(Schedule.calcEndTime('10:55', 45), '11:40');
      expect(Schedule.calcEndTime('13:30', 45), '14:15');
    });

    test('calcEndTime 跨天 clamp 到 23:59，不产生非法时间', () {
      expect(Schedule.calcEndTime('23:30', 120), '23:59');
      expect(Schedule.calcEndTime('22:00', 120), '23:59');
    });

    test('currentWeek：进行中 / 未开始 / 已结束', () {
      final service = CourseService();
      final semesterStart = DateTime(2026, 2, 23);
      // 学期开始于 7 天前 → 第 2 周
      expect(
        service.currentWeek(
          semesterStart,
          now: semesterStart.add(const Duration(days: 7)),
        ),
        2,
      );
      // 学期开始于今天 → 第 1 周
      expect(service.currentWeek(semesterStart, now: semesterStart), 1);
      // 学期 7 天后才开始 → 负数（未开始）
      expect(
        service.currentWeek(
          semesterStart,
          now: semesterStart.subtract(const Duration(days: 1)),
        ),
        lessThan(1),
      );
      // 学期 100 天前开始 → 第 15 周（100 ~/ 7 + 1）
      expect(
        service.currentWeek(
          semesterStart,
          now: semesterStart.add(const Duration(days: 100)),
        ),
        15,
      );
    });

    test('loadShowNonCurrentWeekCourses 默认为 true，保存后可正确读取', () async {
      final service = await createService();
      expect(await service.loadShowNonCurrentWeekCourses(), isTrue);

      await service.saveShowNonCurrentWeekCourses(false);
      expect(await service.loadShowNonCurrentWeekCourses(), isFalse);

      await service.saveShowNonCurrentWeekCourses(true);
      expect(await service.loadShowNonCurrentWeekCourses(), isTrue);
    });
  });
}
