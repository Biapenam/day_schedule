import 'package:flutter/material.dart';
import '../models/course.dart';
import '../models/schedule.dart';
import '../utils/app_modal_sheet.dart';
import 'course_detail_sheet.dart';
import 'dart:math' as math;
import '../utils/app_colors.dart';

const double _cellHeight = 58.0;
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
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
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

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF9C8FFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: _sectionLabelWidth),
          for (int d = 1; d <= visibleDays; d++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final dayDate = weekMonday.add(Duration(days: d - 1));
                  final isToday = widget.isCurrentWeek && d == todayWeekday;
                  final isWeekend = d >= 6;
                  return Column(
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        '周${dayChars[d]}',
                        style: TextStyle(
                          color: isToday
                              ? Colors.white
                              : isWeekend
                              ? Colors.white54
                              : Colors.white70,
                          fontSize: 11,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      isToday
                          ? Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${dayDate.day}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              '${dayDate.day}',
                              style: TextStyle(
                                color: isWeekend
                                    ? Colors.white38
                                    : Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                      const SizedBox(height: 6),
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
                  child: Column(
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
                          color: Color(0xFFBBBBCC),
                        ),
                      ),
                    ],
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
                    right: BorderSide(color: Color(0xFFF5F5FA), width: 0.5),
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
    final color = Color(course.colorValue);

    if (isNonCurrentWeek) {
      Color textColor = color;
      if (ThemeData.estimateBrightnessForColor(color) == Brightness.light) {
        textColor = HSLColor.fromColor(color).withLightness(0.35).toColor();
      }

      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withValues(alpha: 0.38), width: 1),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return _buildNonCurrentWeekContent(
                constraints.maxWidth,
                constraints.maxHeight,
                textColor,
              );
            },
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.88), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        // 内容：用 LayoutBuilder 获取实际列宽，动态调整字体
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _buildContent(constraints.maxWidth, constraints.maxHeight);
          },
        ),
      ),
    );
  }

  Widget _buildNonCurrentWeekContent(
    double colWidth,
    double height,
    Color textColor,
  ) {
    final availH = height - 8;

    final hasLocation = course.location.isNotEmpty;
    final hasTeacher = course.teacher.isNotEmpty;

    final nameFontBase = colWidth < 44
        ? 10.0
        : colWidth >= 150
        ? 12.0
        : 11.0;
    final infoFontBase = colWidth < 44
        ? 9.0
        : colWidth >= 150
        ? 11.0
        : 10.0;
    final nameLineH = nameFontBase * 1.3;
    final infoLineH = infoFontBase * 1.3;
    const gap = 2.0;

    final weekSummary = Course.formatWeeksSummary(course.weeks);

    // 预留周次标注高度
    final reserveForWeek = infoLineH + gap;
    final reserveForInfo = hasLocation ? (gap + infoLineH) : 0.0;
    final nameAvailH = availH - reserveForWeek - reserveForInfo;
    final nameLines = math.max(1, (nameAvailH / nameLineH).floor().clamp(1, 3));

    final usedSoFarWithWeek = nameLineH * nameLines + gap + infoLineH;
    final showLocation =
        hasLocation && (availH - usedSoFarWithWeek) >= gap + infoLineH;

    final usedWithLoc =
        usedSoFarWithWeek + (showLocation ? gap + infoLineH : 0.0);
    final showTeacher = hasTeacher && (availH - usedWithLoc) >= gap + infoLineH;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 3, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 课程名 + (非本周)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: course.name,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.95),
                    fontSize: nameFontBase,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                TextSpan(
                  text: ' (非本周)',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.70),
                    fontSize: math.max(8.0, nameFontBase - 2.5),
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
            maxLines: nameLines,
            overflow: TextOverflow.ellipsis,
          ),

          // 具体是第几周的课程
          const SizedBox(height: gap),
          Text(
            '[$weekSummary]',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.75),
              fontSize: math.max(7.5, infoFontBase - 1.5),
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // 地点
          if (showLocation) ...[
            const SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: textColor.withValues(alpha: 0.65),
                    size: infoFontBase,
                  ),
                ),
                const SizedBox(width: 1),
                Expanded(
                  child: Text(
                    course.location,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.70),
                      fontSize: infoFontBase,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // 教师
          if (showTeacher) ...[
            const SizedBox(height: gap),
            Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  color: textColor.withValues(alpha: 0.55),
                  size: infoFontBase,
                ),
                const SizedBox(width: 1),
                Expanded(
                  child: Text(
                    course.teacher,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.60),
                      fontSize: infoFontBase,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(double colWidth, double height) {
    // 可用空间
    final availW = colWidth - 8; // 左右各4px padding
    final availH = height - 8; // 上下各4px padding

    final hasLocation = course.location.isNotEmpty;
    final hasTeacher = course.teacher.isNotEmpty;

    // ── 动态字体：列越窄字越小，但不低于8sp ──────────────────
    // 标准列宽约55px（5列）；7列时约45px；平板横屏列宽可达180px
    // 基准字体：名称11，地点10；列宽<44时各降1；
    // 平板宽列（>=150px）时温和提升到 名称12 / 地点11，避免大屏上偏小
    final nameFontBase = colWidth < 44
        ? 10.0
        : colWidth >= 150
        ? 12.0
        : 11.0;
    final infoFontBase = colWidth < 44
        ? 9.0
        : colWidth >= 150
        ? 11.0
        : 10.0;
    final nameLineH = nameFontBase * 1.3;
    final infoLineH = infoFontBase * 1.3;
    const gap = 3.0;

    // ── 计算课程名行数 ────────────────────────────────────────
    // 每行能放几个汉字（汉字宽约等于字号）
    final charsPerLine = (availW / nameFontBase).floor().clamp(1, 20);
    final nameCharCount = course.name.length;
    final nameNaturalLines = (nameCharCount / charsPerLine).ceil().clamp(1, 10);

    // 预留地点空间：至少2行infoLineH + gap
    final reserveForInfo = hasLocation ? (gap + infoLineH * 2) : 0.0;
    final nameAvailH = availH - reserveForInfo;
    final nameLines = (nameAvailH / nameLineH)
        .floor()
        .clamp(1, nameNaturalLines)
        .clamp(1, 10);

    // ── 计算地点行数 ──────────────────────────────────────────
    final usedByName = nameLineH * nameLines;
    final afterName = availH - usedByName;
    final charsPerLineInfo = (availW / infoFontBase).floor().clamp(1, 20);
    final locCharCount = course.location.length;
    final locNaturalLines = ((locCharCount + 1) / charsPerLineInfo)
        .ceil()
        .clamp(1, 6); // +1 for icon

    int locationLines = 0;
    if (hasLocation && afterName >= gap + infoLineH) {
      final locAvailH = afterName - gap - (hasTeacher ? gap + infoLineH : 0);
      final computedLines = (locAvailH / infoLineH).floor();
      locationLines = math.max(1, math.min(computedLines, locNaturalLines));
      locationLines = locationLines.clamp(1, 6);
    }

    // ── 教师显示判断 ──────────────────────────────────────────
    final usedSoFar =
        usedByName + (locationLines > 0 ? gap + infoLineH * locationLines : 0);
    final showTeacher = hasTeacher && (availH - usedSoFar) >= gap + infoLineH;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 3, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 课程名
          Text(
            course.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: nameFontBase,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            maxLines: nameLines,
            overflow: TextOverflow.ellipsis,
          ),

          // 地点
          if (locationLines > 0) ...[
            const SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: Colors.white70,
                    size: infoFontBase,
                  ),
                ),
                const SizedBox(width: 1),
                Expanded(
                  child: Text(
                    course.location,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: infoFontBase,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: locationLines.clamp(2, 6),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // 教师
          if (showTeacher) ...[
            const SizedBox(height: gap),
            Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  color: Colors.white60,
                  size: infoFontBase,
                ),
                const SizedBox(width: 1),
                Expanded(
                  child: Text(
                    course.teacher,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: infoFontBase,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
