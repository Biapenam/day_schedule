import 'package:flutter/material.dart';
import '../models/course.dart';
import '../models/schedule.dart';
import '../utils/app_modal_sheet.dart';
import 'course_detail_sheet.dart';
import 'dart:math' as math;
import '../utils/app_colors.dart';

const double _cellHeight = 68.0;
const double _sectionLabelWidth = 44.0;

class ScheduleGrid extends StatefulWidget {
  final List<Course> courses;
  final List<Course>? allCourses;
  final bool showNonCurrentWeekCourses;
  final bool isCurrentWeek;
  final VoidCallback onCourseDeleted;
  final VoidCallback onCourseEdited;
  final int totalWeeks;
  final int dailySections;
  final int weekNumber;
  final int currentWeek;
  final DateTime? semesterStart;
  final List<String> sectionStartTimes;
  final int sectionDuration;

  const ScheduleGrid({
    super.key,
    required this.courses,
    this.allCourses,
    this.showNonCurrentWeekCourses = true,
    required this.isCurrentWeek,
    required this.onCourseDeleted,
    required this.onCourseEdited,
    required this.totalWeeks,
    required this.weekNumber,
    required this.currentWeek,
    required this.sectionStartTimes,
    required this.sectionDuration,
    this.dailySections = 12,
    this.semesterStart,
  });

  @override
  State<ScheduleGrid> createState() => _ScheduleGridState();
}

class _ScheduleGridState extends State<ScheduleGrid> {
  String _getStartTime(int section) =>
      Schedule.sectionStartTimeAt(widget.sectionStartTimes, section);

  String _getEndTime(int section) =>
      Schedule.calcEndTime(_getStartTime(section), widget.sectionDuration);

  /// 推算该周周一日期
  /// 优先用学期开始日期计算（准确且不受学期结束影响），
  /// 否则回退到用当前周与今日推算。
  DateTime _getWeekMonday() {
    if (widget.semesterStart != null) {
      return DateTime(
        widget.semesterStart!.year,
        widget.semesterStart!.month,
        widget.semesterStart!.day,
      ).add(Duration(days: (widget.weekNumber - 1) * 7));
    }
    // 学期未设置：把本周一当作第 1 周的起点来推算各周日期
    // （此时 currentWeek 为 -1，不能参与计算）
    final now = DateTime.now();
    final todayMonday = now.subtract(Duration(days: now.weekday - 1));
    return todayMonday.add(Duration(days: (widget.weekNumber - 1) * 7));
  }

  /// 计算本周实际需要显示的天数（周末有课才显示）
  /// 如果开启了显示非本周课程且传入了全部课程，若任意周在周末有课也展开周末
  int _getVisibleDays() {
    final listToCheck =
        (widget.showNonCurrentWeekCourses && widget.allCourses != null)
        ? widget.allCourses!
        : widget.courses;
    final hasWeekend = listToCheck.any(
      (c) => c.weeks.isNotEmpty && c.dayOfWeek >= 6,
    );
    return hasWeekend ? 7 : 5;
  }

  void _showCourseDetail(Course course) {
    showAppModalSheet(
      context,
      backgroundColor: Colors.transparent,
      builder: (_) => CourseDetailSheet(
        course: course,
        onDeleted: widget.onCourseDeleted,
        onEdited: widget.onCourseEdited,
        totalWeeks: widget.totalWeeks,
        sectionStartTimes: widget.sectionStartTimes,
        sectionDuration: widget.sectionDuration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayWeekday = DateTime.now().weekday;
    final weekMonday = _getWeekMonday();
    final visibleDays = _getVisibleDays();
    final allList = widget.allCourses ?? widget.courses;

    // 按天归类本周有课的课程
    final currentWeekCourses = allList
        .where((c) => c.weeks.contains(widget.weekNumber))
        .toList();
    final currentCoursesByDay = <int, List<Course>>{
      for (var day = 1; day <= visibleDays; day++) day: <Course>[],
    };
    for (final course in currentWeekCourses) {
      currentCoursesByDay[course.dayOfWeek]?.add(course);
    }

    // 按天归类并筛选非本周课程（空位且优先展示距离当前查看周最近的课程）
    final otherCoursesByDay = <int, List<Course>>{
      for (var day = 1; day <= visibleDays; day++) day: <Course>[],
    };

    if (widget.showNonCurrentWeekCourses) {
      final otherWeekCourses = allList
          .where(
            (c) => c.weeks.isNotEmpty && !c.weeks.contains(widget.weekNumber),
          )
          .toList();

      for (var day = 1; day <= visibleDays; day++) {
        final dayCurrent = currentCoursesByDay[day] ?? [];
        final dayOtherCandidates = otherWeekCourses
            .where((c) => c.dayOfWeek == day)
            .where(
              (other) => !dayCurrent.any(
                (cur) =>
                    other.startSection <= cur.endSection &&
                    other.endSection >= cur.startSection,
              ),
            )
            .toList();

        // 排序规则：距离当前周最近的排在最前；距离相同时按最小周次与节次排序
        int distanceToWeek(Course c) {
          if (c.weeks.isEmpty) return 999;
          int minDist = 999;
          for (final w in c.weeks) {
            final diff = (w - widget.weekNumber).abs();
            if (diff < minDist) minDist = diff;
          }
          return minDist;
        }

        dayOtherCandidates.sort((a, b) {
          final distA = distanceToWeek(a);
          final distB = distanceToWeek(b);
          if (distA != distB) return distA.compareTo(distB);
          final minWeekA = a.weeks.isEmpty ? 999 : a.weeks.reduce(math.min);
          final minWeekB = b.weeks.isEmpty ? 999 : b.weeks.reduce(math.min);
          if (minWeekA != minWeekB) return minWeekA.compareTo(minWeekB);
          return a.startSection.compareTo(b.startSection);
        });

        // 贪心选择互不冲突的非本周课程
        final selectedOther = <Course>[];
        for (final course in dayOtherCandidates) {
          final hasConflict = selectedOther.any(
            (sel) =>
                course.startSection <= sel.endSection &&
                course.endSection >= sel.startSection,
          );
          if (!hasConflict) {
            selectedOther.add(course);
          }
        }
        otherCoursesByDay[day] = selectedOther;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用宽度与天数列数动态决定网格整体宽度：
        // 单列过宽时（平板横屏 / 4:3 横屏）限制每列宽度并居中，
        // 避免课程块被横向过度拉伸；手机端不受影响。
        const labelAndGap = _sectionLabelWidth;
        final availableForDays = constraints.maxWidth - labelAndGap;
        final dayWidth = availableForDays / visibleDays;
        // 目标单列最大宽度（px）。课程块内部已按列宽自适应字号。
        const targetMaxDayWidth = 180.0;
        final gridWidth = dayWidth > targetMaxDayWidth
            ? labelAndGap + visibleDays * targetMaxDayWidth
            : constraints.maxWidth;

        return Center(
          child: SizedBox(
            width: gridWidth,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  children: [
                    _buildHeader(todayWeekday, weekMonday, visibleDays),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildBody(
                          todayWeekday,
                          visibleDays,
                          currentCoursesByDay,
                          otherCoursesByDay,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 标题行 ─────────────────────────────────────────────────
  Widget _buildHeader(int todayWeekday, DateTime weekMonday, int visibleDays) {
    const dayChars = ['', '一', '二', '三', '四', '五', '六', '日'];
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      color: AppColors.surfaceContainer,
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 12),
      child: Row(
        children: [
          SizedBox(
            width: _sectionLabelWidth,
            child: Text(
              '${weekMonday.month}月',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          for (int day = 1; day <= visibleDays; day++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final date = weekMonday.add(Duration(days: day - 1));
                  final isToday = widget.isCurrentWeek && day == todayWeekday;
                  return Column(
                    children: [
                      Text(
                        '周${dayChars[day]}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 6),
                      Container(
                        width: compact ? 28 : 32,
                        height: compact ? 28 : 32,
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.primary
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isToday
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ── 主体 ───────────────────────────────────────────────────
  Widget _buildBody(
    int todayWeekday,
    int visibleDays,
    Map<int, List<Course>> currentCoursesByDay,
    Map<int, List<Course>> otherCoursesByDay,
  ) {
    final totalHeight = _cellHeight * widget.dailySections;

    return SizedBox(
      height: totalHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 节次标签列（固定宽度）
          SizedBox(
            width: _sectionLabelWidth,
            height: totalHeight,
            child: Column(
              children: List.generate(widget.dailySections, (i) {
                final section = i + 1;
                return Container(
                  height: _cellHeight,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.borderLight,
                        width: 1,
                      ),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$section',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          _getStartTime(section),
                          style: const TextStyle(
                            fontSize: 8,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          _getEndTime(section),
                          style: const TextStyle(
                            fontSize: 7,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          // 每天的列，用 Expanded 平分剩余宽度
          for (int day = 1; day <= visibleDays; day++)
            Expanded(
              child: _buildDayColumn(
                day,
                todayWeekday,
                totalHeight,
                currentCoursesByDay[day] ?? [],
                otherCoursesByDay[day] ?? [],
              ),
            ),
        ],
      ),
    );
  }

  // ── 单天列 ────────────────────────────────────────────────
  Widget _buildDayColumn(
    int day,
    int todayWeekday,
    double totalHeight,
    List<Course> dayCourses,
    List<Course> dayOtherCourses,
  ) {
    final isToday = widget.isCurrentWeek && day == todayWeekday;
    final isWeekend = day >= 6;
    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // 背景格线
          Column(
            children: List.generate(
              widget.dailySections,
              (i) => Container(
                height: _cellHeight,
                decoration: BoxDecoration(
                  color: isToday
                      ? AppColors.primary.withValues(alpha: 0.04)
                      : isWeekend
                      ? const Color(0xFF000000).withValues(alpha: 0.01)
                      : Colors.transparent,
                  border: const Border(
                    bottom: BorderSide(color: AppColors.borderLight, width: 1),
                    right: BorderSide(color: AppColors.borderLight, width: 0.5),
                  ),
                ),
              ),
            ),
          ),
          // 非本周课程（空位虚化/变淡显示）
          for (final course in dayOtherCourses)
            Positioned(
              top: (course.startSection - 1) * _cellHeight + 2,
              left: 2,
              right: 2,
              height:
                  (course.endSection - course.startSection + 1) * _cellHeight -
                  4,
              child: RepaintBoundary(
                child: _CourseBlock(
                  course: course,
                  isNonCurrentWeek: true,
                  blockHeight:
                      (course.endSection - course.startSection + 1) *
                          _cellHeight -
                      4,
                  onTap: () => _showCourseDetail(course),
                ),
              ),
            ),
          // 本周正式课程（绝对定位）
          for (final course in dayCourses)
            Positioned(
              top: (course.startSection - 1) * _cellHeight + 2,
              left: 2,
              right: 2,
              height:
                  (course.endSection - course.startSection + 1) * _cellHeight -
                  4,
              child: RepaintBoundary(
                child: _CourseBlock(
                  course: course,
                  isNonCurrentWeek: false,
                  blockHeight:
                      (course.endSection - course.startSection + 1) *
                          _cellHeight -
                      4,
                  onTap: () => _showCourseDetail(course),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 课程块（独立 StatelessWidget，用 LayoutBuilder 获取实际宽度）──
class _CourseBlock extends StatelessWidget {
  final Course course;
  final double blockHeight;
  final VoidCallback onTap;
  final bool isNonCurrentWeek;

  const _CourseBlock({
    required this.course,
    required this.blockHeight,
    required this.onTap,
    this.isNonCurrentWeek = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(seedColor: Color(course.colorValue));
    final foreground = isNonCurrentWeek
        ? AppColors.textSecondary
        : colors.onPrimaryContainer;
    return Semantics(
      button: true,
      label:
          '${course.name}，${course.location}，第${course.startSection}至${course.endSection}节${isNonCurrentWeek ? '，非本周' : ''}',
      child: Material(
        color: isNonCurrentWeek
            ? AppColors.surfaceContainer
            : colors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ListenableBuilder(
            // Flutter Web may load a Chinese fallback font after the first
            // layout. Re-measure when font metrics change, just as Text does.
            listenable: PaintingBinding.instance.systemFonts,
            builder: (context, _) => LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 65;
                final padding = compact ? 5.0 : 9.0;
                final textWidth = math.max(
                  1.0,
                  constraints.maxWidth - padding * 2,
                );
                final availableHeight = math.max(
                  0.0,
                  constraints.maxHeight - padding * 2 - 8,
                );
                final name =
                    '${course.name}${isNonCurrentWeek ? ' (非本周)' : ''}';
                final baseStyle = DefaultTextStyle.of(context).style;
                final nameStyle = baseStyle.copyWith(
                  fontSize: compact ? 11 : 13,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                  height: 1.3,
                );
                final infoStyle = baseStyle.copyWith(
                  fontSize: compact ? 9 : 11,
                  height: 1.3,
                  color: foreground,
                );
                final weekStyle = infoStyle.copyWith(
                  fontSize: compact ? 8 : 10,
                );
                final teacherStyle = infoStyle.copyWith(fontSize: 10);
                final weekLabel =
                    '[${Course.formatWeeksSummary(course.weeks)}]';

                // Measure actual wrapping, including the system text scale. Course
                // names get the available height first; metadata uses what is left.
                TextPainter measure(
                  String text,
                  TextStyle style, {
                  int? maxLines,
                }) => TextPainter(
                  text: TextSpan(text: text, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: maxLines,
                )..layout(maxWidth: textWidth);

                final namePainter = measure(name, nameStyle);
                final weekPainter = measure(weekLabel, weekStyle, maxLines: 1);
                final locationPainter = measure(
                  course.location,
                  infoStyle,
                  maxLines: 1,
                );
                final teacherPainter = measure(
                  course.teacher,
                  teacherStyle,
                  maxLines: 1,
                );
                final lines = namePainter.computeLineMetrics();
                final firstLineHeight = lines.isEmpty
                    ? 0.0
                    : lines.first.height;
                final showWeeks =
                    isNonCurrentWeek &&
                    availableHeight >= firstLineHeight + 3 + weekPainter.height;
                final nameBudget =
                    availableHeight - (showWeeks ? 3 + weekPainter.height : 0);
                var nameLines = 0;
                var nameHeight = 0.0;
                for (final line in lines) {
                  if (nameHeight + line.height > nameBudget) break;
                  nameHeight += line.height;
                  nameLines++;
                }
                nameLines = math.max(1, nameLines);
                var remaining = nameBudget - nameHeight;
                final nameFits = nameLines >= lines.length;
                final showLocation =
                    nameFits &&
                    course.location.isNotEmpty &&
                    remaining >= 5 + locationPainter.height;
                if (showLocation) remaining -= 5 + locationPainter.height;
                final showTeacher =
                    nameFits &&
                    course.teacher.isNotEmpty &&
                    remaining >= 3 + teacherPainter.height;
                namePainter.dispose();
                weekPainter.dispose();
                locationPainter.dispose();
                teacherPainter.dispose();

                return Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18,
                        height: 3,
                        decoration: BoxDecoration(
                          color: isNonCurrentWeek
                              ? AppColors.textSecondary
                              : colors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Flexible(
                        child: Text(
                          name,
                          maxLines: nameLines,
                          overflow: TextOverflow.ellipsis,
                          style: nameStyle,
                        ),
                      ),
                      if (showWeeks) ...[
                        const SizedBox(height: 3),
                        Text(
                          weekLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: weekStyle,
                        ),
                      ],
                      if (showLocation) ...[
                        const SizedBox(height: 5),
                        Text(
                          course.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: infoStyle,
                        ),
                      ],
                      if (showTeacher) ...[
                        const SizedBox(height: 3),
                        Text(
                          course.teacher,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: teacherStyle,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
