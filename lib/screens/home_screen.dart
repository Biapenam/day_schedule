import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/course.dart';
import '../models/schedule.dart';
import '../services/course_service.dart';
import '../services/widget_service.dart';
import '../utils/responsive.dart';
import '../widgets/schedule_grid.dart';
import '../widgets/schedule_manager_sheet.dart';
import '../widgets/week_selector.dart';
import 'add_course_screen.dart';
import 'settings_screen.dart';
import '../utils/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final CourseService _service = CourseService();

  Map<int, List<Course>> _coursesByWeek = {};
  List<Course> _allCourses = [];
  bool _showNonCurrentWeekCourses = true;
  int _currentWeek = 1; // 传给子组件：学期在范围内为真实值，否则为 -1
  int _selectedWeek = 1;
  int _totalWeeks = 20;
  int _dailySections = 12;
  List<String> _sectionStartTimes = [];
  int _sectionDuration = 45;
  bool _loading = true;

  DateTime? _semesterStart;
  bool _semesterEnded = false;
  bool _semesterNotStarted = false;
  bool _semesterNotSet = false;

  String _scheduleName = '我的课表';

  PageController? _pageController;
  final ValueNotifier<int> _selectedWeekNotifier = ValueNotifier(1);
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(vsync: this, duration: 300.ms);
    _loadData();
  }

  @override
  void dispose() {
    _fabController.dispose();
    _pageController?.dispose();
    _selectedWeekNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _service.ensureMigrated();
    final schedule = await _service.getActiveSchedule();
    final courses = await _service.loadCourses();
    final showNonCurrent = await _service.loadShowNonCurrentWeekCourses();
    final start = schedule?.semesterStart;
    final totalWeeks = schedule?.totalWeeks ?? 20;
    final dailySections = schedule?.dailySections ?? 12;
    final sectionStartTimes =
        schedule?.sectionStartTimes ??
        List<String>.from(defaultSectionStartTimes);
    final sectionDuration = schedule?.sectionDuration ?? 45;

    int rawWeek = 1;
    bool ended = false;
    bool notStarted = false;
    bool notSet = false;
    if (start != null) {
      rawWeek = _service.currentWeek(start);
      if (rawWeek > totalWeeks) {
        ended = true;
      } else if (rawWeek < 1) {
        notStarted = true;
      }
    } else {
      notSet = true;
    }

    // 传给子组件的 currentWeek：学期在范围内才显示本周标记
    final displayCurrentWeek = (ended || notStarted || notSet)
        ? -1
        : rawWeek.clamp(1, totalWeeks).toInt();
    // PageView 初始页：学期结束定位最后一周，未设置/未开始定位第一周
    final initialPage = ended
        ? totalWeeks - 1
        : (notStarted || notSet)
        ? 0
        : displayCurrentWeek - 1;

    if (!mounted) return;
    _pageController?.dispose();
    _pageController = PageController(initialPage: initialPage);
    setState(() {
      _allCourses = courses;
      _showNonCurrentWeekCourses = showNonCurrent;
      _coursesByWeek = _groupCoursesByWeek(courses, totalWeeks);
      _currentWeek = displayCurrentWeek;
      _selectedWeek = (initialPage + 1).clamp(1, totalWeeks);
      _selectedWeekNotifier.value = _selectedWeek;
      _totalWeeks = totalWeeks;
      _dailySections = dailySections;
      _sectionStartTimes = sectionStartTimes;
      _sectionDuration = sectionDuration;
      _semesterStart = start;
      _semesterEnded = ended;
      _semesterNotStarted = notStarted;
      _semesterNotSet = notSet;
      _scheduleName = schedule?.name ?? '我的课表';
      _loading = false;
    });
    _fabController.forward();
    await WidgetService().updateWidget();
  }

  Future<void> _refresh() async {
    final courses = await _service.loadCourses();
    final showNonCurrent = await _service.loadShowNonCurrentWeekCourses();
    if (!mounted) return;
    setState(() {
      _allCourses = courses;
      _showNonCurrentWeekCourses = showNonCurrent;
      _coursesByWeek = _groupCoursesByWeek(courses, _totalWeeks);
    });
    WidgetService().updateWidget();
  }

  Map<int, List<Course>> _groupCoursesByWeek(
    List<Course> courses,
    int totalWeeks,
  ) {
    final grouped = <int, List<Course>>{
      for (var week = 1; week <= totalWeeks; week++) week: <Course>[],
    };
    for (final course in courses) {
      for (final week in course.weeks) {
        grouped[week]?.add(course);
      }
    }
    return grouped;
  }

  void _goToWeek(int week) {
    final target = week.clamp(1, _totalWeeks);
    _pageController?.animateToPage(
      target - 1,
      duration: 350.ms,
      curve: Curves.easeInOutCubic,
    );
  }

  void _openAddCourse() async {
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, _) => AddCourseScreen(totalWeeks: _totalWeeks),
        transitionsBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: 400.ms,
      ),
    );
    if (result == true) _refresh();
  }

  void _openSettings() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (mounted) _loadData();
  }

  // ─── 课表管理 ──────────────────────────────────────────────

  void _showScheduleManager() async {
    await ScheduleManagerSheet.show(
      context,
      service: _service,
      onChanged: () {
        Navigator.pop(context);
        _loadData();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        // 平板：内容整体限宽居中，避免横屏下横跨整屏；
        // 手机：不限制宽度，保持现有单栏布局。
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentMaxWidth =
                constraints.maxWidth >= Responsive.tabletBreakpoint
                ? math.min(constraints.maxWidth, Responsive.contentMaxWidth)
                : constraints.maxWidth;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Column(
                  children: [
                    _buildHeader(),
                    if (_semesterEnded ||
                        _semesterNotStarted ||
                        _semesterNotSet)
                      _buildSemesterBanner(),
                    ValueListenableBuilder<int>(
                      valueListenable: _selectedWeekNotifier,
                      builder: (context, selectedWeek, child) => WeekSelector(
                        currentWeek: _currentWeek,
                        selectedWeek: selectedWeek,
                        totalWeeks: _totalWeeks,
                        onWeekChanged: _goToWeek,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController!,
                        itemCount: _totalWeeks,
                        onPageChanged: (page) {
                          _selectedWeek = page + 1;
                          _selectedWeekNotifier.value = _selectedWeek;
                        },
                        itemBuilder: (context, index) {
                          final week = index + 1;
                          final weekCourses =
                              _coursesByWeek[week] ?? const <Course>[];
                          return ScheduleGrid(
                            courses: weekCourses,
                            allCourses: _allCourses,
                            showNonCurrentWeekCourses:
                                _showNonCurrentWeekCourses,
                            isCurrentWeek: week == _currentWeek,
                            onCourseDeleted: _refresh,
                            onCourseEdited: _refresh,
                            totalWeeks: _totalWeeks,
                            dailySections: _dailySections,
                            weekNumber: week,
                            currentWeek: _currentWeek,
                            semesterStart: _semesterStart,
                            sectionStartTimes: _sectionStartTimes,
                            sectionDuration: _sectionDuration,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(
          parent: _fabController,
          curve: Curves.elasticOut,
        ),
        child: FloatingActionButton(
          onPressed: _openAddCourse,
          tooltip: '添加课程',
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final todayStr = '${now.month}月${now.day}日 ${weekdays[now.weekday]}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showScheduleManager,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _scheduleName,
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  todayStr,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterBanner() {
    Color color;
    IconData icon;
    String message;
    VoidCallback onTap;

    if (_semesterNotSet) {
      color = AppColors.primary;
      icon = Icons.info_outline_rounded;
      message = '请先在设置中选择学期开始日期';
      onTap = _openSettings;
    } else if (_semesterEnded) {
      color = const Color(0xFFFF9A3C);
      icon = Icons.event_busy_rounded;
      message = '「$_scheduleName」已结束，点击标题可创建新课表';
      onTap = _showScheduleManager;
    } else {
      // notStarted
      color = const Color(0xFF4FC3F7);
      icon = Icons.hourglass_top_rounded;
      final s = _semesterStart!;
      message = '「$_scheduleName」将于 ${s.year}年${s.month}月${s.day}日 开始';
      onTap = _openSettings;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
