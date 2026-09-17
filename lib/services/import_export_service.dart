import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../models/schedule.dart';

/// 导出的课表解析结果
class ExportData {
  final Schedule schedule; // id 已重新生成
  final List<Course> courses; // id 已重新生成

  const ExportData({required this.schedule, required this.courses});
}

/// 课表「口令」导入导出服务。
///
/// 口令格式：
/// ```text
/// OS1:<payload><checksum>
/// ```
/// - `OS1:` 前缀用于识别与版本控制
/// - `payload` = `base64Url(无 padding)` 编码的 `gzip(JSON)`
/// - `checksum` = FNV-1a 哈希的 4 位可读校验字符（Crockford 风格字符集）
///
/// 特性：
/// - 压缩后口令更短，适合复制粘贴 / 聊天发送
/// - 校验码可在粘贴错误时立即发现，而不是导入后才报错
/// - 导入时会为新课表 / 课程重新生成 id，避免跨设备冲突
class ImportExportService {
  static const String prefix = 'OS1:';
  static const int _version = 1;

  /// 校验字符集（去掉 0/O/1/I/L/U 等易混淆字符）
  static const String _checkChars = '23456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// 把课表及其课程编码为口令字符串
  static String encode(Schedule schedule, List<Course> courses) {
    final map = <String, dynamic>{
      'v': _version,
      'name': schedule.name,
      'semesterStart': schedule.semesterStart?.toIso8601String(),
      'totalWeeks': schedule.totalWeeks,
      'dailySections': schedule.dailySections,
      'sectionDuration': schedule.sectionDuration,
      'sectionStartTimes': schedule.sectionStartTimes,
      'courses': courses
          .map(
            (c) => {
              'name': c.name,
              'teacher': c.teacher,
              'location': c.location,
              'colorValue': c.colorValue,
              'weeks': c.weeks,
              'dayOfWeek': c.dayOfWeek,
              'startSection': c.startSection,
              'endSection': c.endSection,
            },
          )
          .toList(),
    };
    final jsonStr = jsonEncode(map);
    final gz = gzip.encode(utf8.encode(jsonStr));
    final payload = base64Url.encode(gz).replaceAll('=', '');
    return '$prefix$payload${_checksum(payload)}';
  }

  /// 解析口令为课表与课程。
  ///
  /// 口令无效 / 校验失败 / 版本过新时抛出 [FormatException]。
  static ExportData decode(String code) {
    var text = code.trim();
    // 去掉粘贴时可能混入的空白与换行
    text = text.replaceAll(RegExp(r'\s+'), '');
    if (!text.startsWith(prefix)) {
      throw const FormatException('口令格式不正确，请确认以 OS1: 开头');
    }
    final body = text.substring(prefix.length);
    if (body.length <= 4) {
      throw const FormatException('口令内容不完整');
    }
    final payload = body.substring(0, body.length - 4);
    final givenCheck = body.substring(body.length - 4);
    if (_checksum(payload) != givenCheck) {
      throw const FormatException('口令校验失败，可能粘贴有误');
    }

    final decoded = base64Url.decode(_restorePadding(payload));
    final jsonStr = utf8.decode(gzip.decode(decoded));
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;

    final version = (map['v'] as num?)?.toInt() ?? 1;
    if (version > _version) {
      throw FormatException('口令版本过新（v$version），请升级应用后再导入');
    }

    final courses = ((map['courses'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_courseFromMap)
        .where((c) => c.name.isNotEmpty)
        .toList();

    final rawStart = map['semesterStart']?.toString() ?? '';
    final schedule = Schedule(
      id: const Uuid().v4(),
      name: map['name']?.toString() ?? '导入课表',
      semesterStart: rawStart.isEmpty ? null : DateTime.tryParse(rawStart),
      totalWeeks: _readInt(map, 'totalWeeks', 20),
      dailySections: _readInt(map, 'dailySections', 12),
      sectionStartTimes: (map['sectionStartTimes'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      sectionDuration: _readInt(map, 'sectionDuration', 45),
    );

    return ExportData(schedule: schedule, courses: courses);
  }

  // ── 内部工具 ─────────────────────────────────────────────

  static Course _courseFromMap(Map<String, dynamic> c) {
    final startSection = _readInt(
      c,
      'startSection',
      1,
    ).clamp(1, Course.maxSection).toInt();
    final endSection = _readInt(
      c,
      'endSection',
      startSection,
    ).clamp(startSection, Course.maxSection).toInt();
    return Course(
      id: const Uuid().v4(),
      name: (c['name'] ?? '').toString(),
      teacher: (c['teacher'] ?? '').toString(),
      location: (c['location'] ?? '').toString(),
      colorValue: _readInt(c, 'colorValue', courseColors[0]),
      weeks: ((c['weeks'] is List) ? (c['weeks'] as List) : const [])
          .whereType<num>()
          .map((e) => e.toInt())
          .where((w) => w > 0)
          .toList(),
      dayOfWeek: _readInt(c, 'dayOfWeek', 1).clamp(1, 7),
      startSection: startSection,
      endSection: endSection,
    );
  }

  static int _readInt(Map<String, dynamic> map, String key, int fallback) {
    final v = map[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  /// 计算 payload 的 4 位校验字符（FNV-1a 32 位）
  static String _checksum(String data) {
    final bytes = utf8.encode(data);
    var hash = 0x811c9dc5;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final sb = StringBuffer();
    var value = hash;
    for (int i = 0; i < 4; i++) {
      // 用取模而非 & 0x1F：字符集是 30 个字符，按位掩码会产生 30/31 越界索引
      sb.write(_checkChars[value % _checkChars.length]);
      value ~/= _checkChars.length;
    }
    return sb.toString();
  }

  /// base64 解码需要正确的 padding
  static String _restorePadding(String s) {
    final rem = s.length % 4;
    if (rem == 0) return s;
    return s.padRight(s.length + (4 - rem), '=');
  }
}
