class Course {
  static const maxSection = 16;
  final String id;
  final String name;
  final String teacher;
  final String location;
  final int colorValue;
  final List<int> weeks; // 哪些周有课，如 [1,2,3,...,16]
  final int dayOfWeek; // 1=周一，2=周二，...，7=周日
  final int startSection; // 开始节次（1-12）
  final int endSection; // 结束节次（1-12）

  Course({
    required this.id,
    required this.name,
    required this.teacher,
    required this.location,
    required this.colorValue,
    required List<int> weeks,
    required int dayOfWeek,
    required int startSection,
    required int endSection,
  }) : weeks = normalizeWeeks(weeks),
       dayOfWeek = dayOfWeek.clamp(1, 7).toInt(),
       startSection = startSection.clamp(1, maxSection).toInt(),
       endSection = endSection
           .clamp(startSection.clamp(1, maxSection), maxSection)
           .toInt();

  static List<int> normalizeWeeks(Iterable<int> weeks) =>
      weeks.where((week) => week > 0).toSet().toList()..sort();

  /// 判断两门课程是否时间冲突：
  /// 同一天、上课周次有交集、且节次区间重叠。
  static bool overlaps(Course a, Course b) {
    if (a.dayOfWeek != b.dayOfWeek) return false;
    if (!a.weeks.any(b.weeks.contains)) return false;
    return a.startSection <= b.endSection && a.endSection >= b.startSection;
  }

  /// 将周次列表格式化为紧凑周次说明，如 [1, 2, 3, 4, 7, 8] -> "第1-4,7-8周"
  static String formatWeeksSummary(List<int> weeks) {
    if (weeks.isEmpty) return '';
    final sorted = List<int>.from(weeks)..sort();
    final parts = <String>[];
    int start = sorted.first;
    int prev = sorted.first;

    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == prev + 1) {
        prev = sorted[i];
      } else {
        parts.add(start == prev ? '$start' : '$start-$prev');
        start = sorted[i];
        prev = sorted[i];
      }
    }
    parts.add(start == prev ? '$start' : '$start-$prev');
    return '第${parts.join(',')}周';
  }

  // 深拷贝修改
  Course copyWith({
    String? id,
    String? name,
    String? teacher,
    String? location,
    int? colorValue,
    List<int>? weeks,
    int? dayOfWeek,
    int? startSection,
    int? endSection,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      location: location ?? this.location,
      colorValue: colorValue ?? this.colorValue,
      weeks: weeks ?? List.from(this.weeks),
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startSection: startSection ?? this.startSection,
      endSection: endSection ?? this.endSection,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teacher': teacher,
    'location': location,
    'colorValue': colorValue,
    'weeks': weeks,
    'dayOfWeek': dayOfWeek,
    'startSection': startSection,
    'endSection': endSection,
  };

  factory Course.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    String readString(String key) => (json[key] ?? '').toString();

    final rawWeeks = json['weeks'];
    final weeks = rawWeeks is List
        ? rawWeeks
              .map((w) => w is int ? w : int.tryParse(w.toString()))
              .whereType<int>()
              .where((w) => w > 0)
              .toList()
        : <int>[];

    final startSection = readInt(
      'startSection',
      1,
    ).clamp(1, maxSection).toInt();
    final endSection = readInt(
      'endSection',
      startSection,
    ).clamp(startSection, maxSection).toInt();

    return Course(
      id: readString('id'),
      name: readString('name'),
      teacher: readString('teacher'),
      location: readString('location'),
      colorValue: readInt('colorValue', courseColors[0]),
      weeks: weeks,
      dayOfWeek: readInt('dayOfWeek', 1).clamp(1, 7).toInt(),
      startSection: startSection,
      endSection: endSection,
    );
  }
}

// 预设课程颜色
const List<int> courseColors = [
  0xFF6C63FF, // 紫色
  0xFFFF6584, // 粉红
  0xFF43C6AC, // 青绿
  0xFFFF9A3C, // 橙色
  0xFF4FC3F7, // 天蓝
  0xFFAB47BC, // 深紫
  0xFF26A69A, // 墨绿
  0xFFEF5350, // 红色
  0xFF66BB6A, // 绿色
  0xFFFFCA28, // 黄色（文字用深色）
];

const List<String> dayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
