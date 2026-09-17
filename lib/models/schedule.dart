import 'package:uuid/uuid.dart';

/// 课表（学期）模型：每个课表拥有独立的学期设置与课程列表。
class Schedule {
  static const minTotalWeeks = 1;
  static const maxTotalWeeks = 30;
  static const minDailySections = 4;
  static const maxDailySections = 16;
  static const minSectionDuration = 20;
  static const maxSectionDuration = 120;
  final String id;
  final String name;
  final DateTime? semesterStart;
  final int totalWeeks;
  final int dailySections;
  final List<String> sectionStartTimes;
  final int sectionDuration;

  Schedule({
    required this.id,
    required this.name,
    this.semesterStart,
    int totalWeeks = 20,
    int dailySections = 12,
    List<String>? sectionStartTimes,
    int sectionDuration = 45,
  }) : totalWeeks = totalWeeks.clamp(minTotalWeeks, maxTotalWeeks).toInt(),
       dailySections = dailySections
           .clamp(minDailySections, maxDailySections)
           .toInt(),
       sectionStartTimes = normalizeSectionStartTimes(
         sectionStartTimes,
         dailySections.clamp(minDailySections, maxDailySections).toInt(),
       ),
       sectionDuration = sectionDuration
           .clamp(minSectionDuration, maxSectionDuration)
           .toInt();

  static List<String> normalizeSectionStartTimes(
    List<String>? raw,
    int dailySections,
  ) {
    final defaults = List<String>.from(defaultSectionStartTimes);
    final values = raw ?? <String>[];
    return List<String>.generate(dailySections, (index) {
      final value = index < values.length ? values[index] : null;
      return _isValidTime(value)
          ? value!
          : (index < defaults.length ? defaults[index] : '08:00');
    });
  }

  static bool _isValidTime(String? value) {
    if (value == null) return false;
    final match = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').firstMatch(value);
    return match != null;
  }

  // ─── 节次时间工具 ─────────────────────────────────────────

  /// 取某节课的开始时间（1 起）。
  /// 越界时回退默认时间表，最后兜底 '08:00'。
  static String sectionStartTimeAt(List<String> times, int section) {
    final idx = section - 1;
    if (idx >= 0 && idx < times.length) return times[idx];
    if (idx >= 0 && idx < defaultSectionStartTimes.length) {
      return defaultSectionStartTimes[idx];
    }
    return '08:00';
  }

  /// 本课表中某节课的开始时间。
  String sectionStartTime(int section) =>
      sectionStartTimeAt(sectionStartTimes, section);

  /// 根据开始时间和时长计算结束时间字符串。
  /// 跨天（超过 24:00）时 clamp 到 23:59，避免出现非法时间（如 25:30）。
  static String calcEndTime(String startTime, int durationMinutes) {
    final parts = startTime.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final total = h * 60 + m + durationMinutes;
    if (total >= 24 * 60) return '23:59';
    final eh = total ~/ 60;
    final em = total % 60;
    return '${eh.toString().padLeft(2, '0')}:${em.toString().padLeft(2, '0')}';
  }

  /// 本课表中某节课的结束时间。
  String sectionEndTime(int section) =>
      calcEndTime(sectionStartTime(section), sectionDuration);

  Schedule copyWith({
    String? id,
    String? name,
    DateTime? semesterStart,
    bool clearSemesterStart = false,
    int? totalWeeks,
    int? dailySections,
    List<String>? sectionStartTimes,
    int? sectionDuration,
  }) {
    return Schedule(
      id: id ?? this.id,
      name: name ?? this.name,
      semesterStart: clearSemesterStart
          ? null
          : (semesterStart ?? this.semesterStart),
      totalWeeks: totalWeeks ?? this.totalWeeks,
      dailySections: dailySections ?? this.dailySections,
      sectionStartTimes: sectionStartTimes ?? List.from(this.sectionStartTimes),
      sectionDuration: sectionDuration ?? this.sectionDuration,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'semesterStart': semesterStart?.toIso8601String(),
    'totalWeeks': totalWeeks,
    'dailySections': dailySections,
    'sectionStartTimes': sectionStartTimes,
    'sectionDuration': sectionDuration,
  };

  factory Schedule.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    String readString(String key, {String fallback = ''}) =>
        (json[key] ?? fallback).toString();

    final rawStart = json['semesterStart'];
    DateTime? start;
    if (rawStart is String && rawStart.isNotEmpty) {
      start = DateTime.tryParse(rawStart);
    }

    final rawTimes = json['sectionStartTimes'];
    final times = rawTimes is List
        ? rawTimes.map((e) => e.toString()).toList()
        : List<String>.from(defaultSectionStartTimes);

    return Schedule(
      id: readString('id', fallback: const Uuid().v4()),
      name: readString('name', fallback: '未命名课表'),
      semesterStart: start,
      totalWeeks: readInt('totalWeeks', 20),
      dailySections: readInt('dailySections', 12),
      sectionStartTimes: times,
      sectionDuration: readInt('sectionDuration', 45),
    );
  }
}

// 默认节次开始时间（12节）
const List<String> defaultSectionStartTimes = [
  '08:00',
  '08:55',
  '09:50',
  '10:55',
  '11:50',
  '13:30',
  '14:25',
  '15:20',
  '16:15',
  '18:30',
  '19:25',
  '20:20',
];
