import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../models/schedule.dart';

class CourseService {
  static const _schedulesKey = 'schedules';
  static const _schedulesBackupKey = 'schedules_backup';
  static const _activeScheduleIdKey = 'active_schedule_id';

  // 旧的全局 key（用于一次性迁移）
  static const _legacyCoursesKey = 'courses';
  static const _legacySemesterStartKey = 'semester_start';
  static const _legacyTotalWeeksKey = 'total_weeks';
  static const _legacyDailySectionsKey = 'daily_sections';
  static const _legacySectionTimesKey = 'section_times';
  static const _legacySectionDurationKey = 'section_duration';

  static const _uuid = Uuid();
  // 写队列：串行化本实例的写入操作，避免交错写导致的数据竞争。
  // 注意不能是 static：跨 testWidgets 的 FakeAsync 区域会残留未完成的
  // Future 链，导致后续测试的写操作永远等待。
  Future<void> _writeQueue = Future<void>.value();
  // 迁移单飞：正在进行的迁移 Future（完成后保持已完成的 Future）
  Future<void>? _migrating;

  Future<T> _serializeWrite<T>(Future<T> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  String _coursesKey(String scheduleId) => 'courses_$scheduleId';

  String _coursesBackupKey(String scheduleId) => 'courses_${scheduleId}_backup';

  Future<void> _setStringWithBackup(
    SharedPreferences prefs,
    String key,
    String value, {
    required String backupKey,
  }) async {
    final previous = prefs.getString(key);
    if (previous != null && previous.isNotEmpty) {
      await prefs.setString(backupKey, previous);
    }
    await prefs.setString(key, value);
  }

  void _logStorageWarning(String message) {
    developer.log(message, name: 'day_schedule.storage');
  }

  // ─── 迁移与初始化 ──────────────────────────────────────────

  /// 确保数据已迁移到多课表结构。App 启动时调用一次即可。
  /// 单飞（single-flight）：并发调用共享同一个迁移 Future，避免重复迁移。
  Future<void> ensureMigrated() => _migrating ??= _doMigrate();

  Future<void> _doMigrate() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_schedulesKey) == null) {
      await _migrateFromLegacy(prefs);
    }
  }

  Future<void> _migrateFromLegacy(SharedPreferences prefs) async {
    final rawCourses = prefs.getString(_legacyCoursesKey);
    final rawStart = prefs.getString(_legacySemesterStartKey);
    final totalWeeks = prefs.getInt(_legacyTotalWeeksKey) ?? 20;
    final dailySections = prefs.getInt(_legacyDailySectionsKey) ?? 12;
    final rawTimes = prefs.getString(_legacySectionTimesKey);
    final duration = prefs.getInt(_legacySectionDurationKey) ?? 45;

    DateTime? start;
    if (rawStart != null) start = DateTime.tryParse(rawStart);

    List<String> times = List<String>.from(defaultSectionStartTimes);
    if (rawTimes != null) {
      try {
        final decoded = jsonDecode(rawTimes);
        if (decoded is List) {
          times = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        // 使用默认时间，避免损坏的旧配置阻塞应用启动。
      }
    }

    final id = _uuid.v4();
    final schedule = Schedule(
      id: id,
      name: '我的课表',
      semesterStart: start,
      totalWeeks: totalWeeks,
      dailySections: dailySections,
      sectionStartTimes: times,
      sectionDuration: duration,
    );

    await prefs.setString(_schedulesKey, jsonEncode([schedule.toJson()]));
    await prefs.setString(_activeScheduleIdKey, id);

    // 迁移课程到 schedule 专属 key
    if (rawCourses != null) {
      try {
        final decoded = jsonDecode(rawCourses);
        if (decoded is List) {
          final courses = decoded
              .whereType<Map<String, dynamic>>()
              .map(Course.fromJson)
              .where((c) => c.id.isNotEmpty && c.name.isNotEmpty)
              .toList();
          await prefs.setString(
            _coursesKey(id),
            jsonEncode(courses.map((c) => c.toJson()).toList()),
          );
        }
      } catch (_) {}
    }

    // 清理旧的全局 key
    await prefs.remove(_legacyCoursesKey);
    await prefs.remove(_legacySemesterStartKey);
    await prefs.remove(_legacyTotalWeeksKey);
    await prefs.remove(_legacyDailySectionsKey);
    await prefs.remove(_legacySectionTimesKey);
    await prefs.remove(_legacySectionDurationKey);
  }

  // ─── 课表（学期）管理 ─────────────────────────────────────

  Future<List<Schedule>> loadSchedules() async {
    await ensureMigrated();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_schedulesKey);
    if (raw == null) return [];

    final schedules = _decodeSchedules(raw);
    if (schedules != null) return schedules;

    final backupRaw = prefs.getString(_schedulesBackupKey);
    final backupSchedules = _decodeSchedules(backupRaw);
    if (backupSchedules != null) {
      _logStorageWarning(
        'Primary schedule data was invalid; restored the last valid backup.',
      );
      await prefs.setString(_schedulesKey, backupRaw!);
      return backupSchedules;
    }

    _logStorageWarning(
      'Primary and backup schedule data were invalid; returning an empty list.',
    );
    return [];
  }

  Future<void> _saveSchedules(List<Schedule> schedules) async {
    final prefs = await SharedPreferences.getInstance();
    await _setStringWithBackup(
      prefs,
      _schedulesKey,
      jsonEncode(schedules.map((s) => s.toJson()).toList()),
      backupKey: _schedulesBackupKey,
    );
  }

  List<Schedule>? _decodeSchedules(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Schedule.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<String?> getActiveScheduleId() async {
    await ensureMigrated();
    final schedules = await loadSchedules();
    if (schedules.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString(_activeScheduleIdKey);
    if (storedId != null &&
        schedules.any((schedule) => schedule.id == storedId)) {
      return storedId;
    }

    // 修复缺失或失效的 active id，避免界面回退到第一张课表但课程仍按
    // 无效 id 读取为空。
    final fallbackId = schedules.first.id;
    await prefs.setString(_activeScheduleIdKey, fallbackId);
    return fallbackId;
  }

  /// 获取当前激活的课表。若 active id 失效则回退到第一个。
  Future<Schedule?> getActiveSchedule() async {
    final schedules = await loadSchedules();
    if (schedules.isEmpty) return null;
    final id = await getActiveScheduleId();
    if (id == null) return schedules.first;
    return schedules.firstWhere(
      (s) => s.id == id,
      orElse: () => schedules.first,
    );
  }

  /// 切换当前激活课表
  Future<void> setActiveSchedule(String id) async {
    await ensureMigrated();
    final schedules = await loadSchedules();
    if (!schedules.any((schedule) => schedule.id == id)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeScheduleIdKey, id);
  }

  /// 创建新课表，返回创建的课表（不自动切换）
  Future<Schedule> createSchedule(String name) async {
    return _serializeWrite(() async {
      final schedules = await loadSchedules();
      final schedule = Schedule(
        id: _uuid.v4(),
        name: name.trim().isEmpty ? '新课表' : name.trim(),
      );
      await _saveSchedules([...schedules, schedule]);
      return schedule;
    });
  }

  /// 重命名课表
  Future<void> renameSchedule(String id, String name) async {
    await _serializeWrite(() async {
      final schedules = await loadSchedules();
      final idx = schedules.indexWhere((s) => s.id == id);
      if (idx == -1) return;
      schedules[idx] = schedules[idx].copyWith(name: name);
      await _saveSchedules(schedules);
    });
  }

  /// 删除课表（至少保留一个）。若删除的是当前激活课表，自动切换。
  Future<void> deleteSchedule(String id) async {
    await _serializeWrite(() async {
      final schedules = await loadSchedules();
      final remaining = schedules.where((s) => s.id != id).toList();
      if (remaining.isEmpty) return; // 至少保留一个课表
      await _saveSchedules(remaining);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_coursesKey(id));
      await prefs.remove(_coursesBackupKey(id));
      final activeId = await getActiveScheduleId();
      if (activeId == id) await setActiveSchedule(remaining.first.id);
    });
  }

  /// 更新某个课表的元数据（不存在则新增）
  Future<void> saveScheduleMeta(Schedule updated) async {
    await _serializeWrite(() async {
      final schedules = await loadSchedules();
      final idx = schedules.indexWhere((s) => s.id == updated.id);
      if (idx == -1) {
        await _saveSchedules([...schedules, updated]);
      } else {
        schedules[idx] = updated;
        await _saveSchedules(schedules);
      }
    });
  }

  // ─── 课程 CRUD（作用于当前激活课表） ───────────────────────

  Future<List<Course>> loadCourses() async {
    final id = await getActiveScheduleId();
    if (id == null) return [];
    return loadCoursesFor(id);
  }

  Future<List<Course>> loadCoursesFor(String scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _coursesKey(scheduleId);
    final raw = prefs.getString(key);
    if (raw == null) return [];

    final courses = _decodeCourses(raw);
    if (courses != null) return courses;

    final backupRaw = prefs.getString(_coursesBackupKey(scheduleId));
    final backupCourses = _decodeCourses(backupRaw);
    if (backupCourses != null) {
      _logStorageWarning(
        'Primary course data was invalid; restored the last valid backup for '
        'schedule $scheduleId.',
      );
      await prefs.setString(key, backupRaw!);
      return backupCourses;
    }

    _logStorageWarning(
      'Primary and backup course data were invalid for schedule $scheduleId; '
      'returning an empty list.',
    );
    return [];
  }

  List<Course>? _decodeCourses(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Course.fromJson)
          .where((course) => course.id.isNotEmpty && course.name.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// 保存某指定课表的课程列表（用于导入课表等场景）
  Future<void> saveCoursesFor(String scheduleId, List<Course> courses) async {
    await _serializeWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(courses.map((c) => c.toJson()).toList());
      await _setStringWithBackup(
        prefs,
        _coursesKey(scheduleId),
        raw,
        backupKey: _coursesBackupKey(scheduleId),
      );
    });
  }

  Future<void> addCourse(Course course) async {
    await _serializeWrite(() async {
      final courses = await loadCourses();
      final id = await getActiveScheduleId();
      if (id == null) return;
      courses.add(course);
      final prefs = await SharedPreferences.getInstance();
      await _setStringWithBackup(
        prefs,
        _coursesKey(id),
        jsonEncode(courses.map((c) => c.toJson()).toList()),
        backupKey: _coursesBackupKey(id),
      );
    });
  }

  Future<void> updateCourse(Course updated) async {
    await _serializeWrite(() async {
      final courses = await loadCourses();
      final id = await getActiveScheduleId();
      if (id == null) return;
      final idx = courses.indexWhere((c) => c.id == updated.id);
      if (idx != -1) courses[idx] = updated;
      final prefs = await SharedPreferences.getInstance();
      await _setStringWithBackup(
        prefs,
        _coursesKey(id),
        jsonEncode(courses.map((c) => c.toJson()).toList()),
        backupKey: _coursesBackupKey(id),
      );
    });
  }

  Future<void> deleteCourse(String id) async {
    await _serializeWrite(() async {
      final courses = await loadCourses();
      final activeId = await getActiveScheduleId();
      if (activeId == null) return;
      courses.removeWhere((c) => c.id == id);
      final prefs = await SharedPreferences.getInstance();
      await _setStringWithBackup(
        prefs,
        _coursesKey(activeId),
        jsonEncode(courses.map((c) => c.toJson()).toList()),
        backupKey: _coursesBackupKey(activeId),
      );
    });
  }

  // ─── 学期设置（作用于当前激活课表元数据） ──────────────────

  Future<void> saveSemesterStart(DateTime date) async {
    final s = await getActiveSchedule();
    if (s == null) return;
    await saveScheduleMeta(s.copyWith(semesterStart: date));
  }

  Future<void> saveTotalWeeks(int weeks) async {
    final s = await getActiveSchedule();
    if (s == null) return;
    await saveScheduleMeta(s.copyWith(totalWeeks: weeks));
  }

  // ─── 每日节数 ─────────────────────────────────────────────

  Future<int> loadDailySections() async {
    final s = await getActiveSchedule();
    return s?.dailySections ?? 12;
  }

  Future<void> saveDailySections(int sections) async {
    final s = await getActiveSchedule();
    if (s == null) return;
    await saveScheduleMeta(s.copyWith(dailySections: sections));
  }

  // ─── 节次时间设置 ──────────────────────────────────────────

  /// 加载每节课开始时间列表（格式 "HH:mm"），不存在则返回默认值
  Future<List<String>> loadSectionStartTimes() async {
    final s = await getActiveSchedule();
    return s?.sectionStartTimes ?? List<String>.from(defaultSectionStartTimes);
  }

  Future<void> saveSectionStartTimes(List<String> times) async {
    final s = await getActiveSchedule();
    if (s == null) return;
    await saveScheduleMeta(s.copyWith(sectionStartTimes: times));
  }

  /// 每节课时长（分钟）
  Future<int> loadSectionDuration() async {
    final s = await getActiveSchedule();
    return s?.sectionDuration ?? 45;
  }

  Future<void> saveSectionDuration(int minutes) async {
    final s = await getActiveSchedule();
    if (s == null) return;
    await saveScheduleMeta(s.copyWith(sectionDuration: minutes));
  }

  // ─── 非本周课程显示设置 ──────────────────────────────────
  static const _showNonCurrentWeekCoursesKey = 'show_non_current_week_courses';

  Future<bool> loadShowNonCurrentWeekCourses() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showNonCurrentWeekCoursesKey) ?? true;
  }

  Future<void> saveShowNonCurrentWeekCourses(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showNonCurrentWeekCoursesKey, show);
  }

  // ─── 工具方法 ─────────────────────────────────────────────

  /// 计算当前周（真实值，不 clamp）。
  /// 返回值可能 < 1（学期未开始）或 > totalWeeks（学期已结束），
  /// 调用方需自行判断是否在学期范围内。
  int currentWeek(DateTime semesterStart, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final diff = currentTime.difference(semesterStart).inDays;
    if (diff < 0) return (diff ~/ 7) - 1;
    return (diff ~/ 7) + 1;
  }
}
