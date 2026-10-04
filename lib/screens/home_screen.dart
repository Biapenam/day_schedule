import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/course.dart';
import '../models/schedule.dart';
import '../services/course_service.dart';
import '../services/widget_service.dart';
import '../widgets/schedule_grid.dart';
import '../widgets/schedule_manager_sheet.dart';
import '../widgets/week_selector.dart';
import 'add_course_screen.dart';
import 'settings_screen.dart';
import '../utils/app_colors.dart';
import '../widgets/day_overview.dart';

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
    if (_allCourses.isEmpty) {
      _selectedWeek = target;
      _selectedWeekNotifier.value = target;
      _pageController?.dispose();
      _pageController = PageController(initialPage: target - 1);
      return;
    }
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        final compact = constraints.maxWidth < 600;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (wide) _buildRail(),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          wide ? 28 : 8,
                          compact ? 0 : 8,
                          wide ? 28 : 8,
                          0,
                        ),
                        child: Column(
                          children: [
                            _buildHeader(wide, compact),
                            if (_semesterEnded ||
                                _semesterNotStarted ||
                                _semesterNotSet)
                              _buildSemesterBanner(),
                            SizedBox(height: compact ? 4 : 12),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        ValueListenableBuilder<int>(
                                          valueListenable:
                                              _selectedWeekNotifier,
                                          builder: (context, selectedWeek, _) =>
                                              WeekSelector(
                                                currentWeek: _currentWeek,
                                                selectedWeek: selectedWeek,
                                                totalWeeks: _totalWeeks,
                                                onWeekChanged: _goToWeek,
                                              ),
                                        ),
                                        SizedBox(height: compact ? 4 : 12),
                                        Expanded(
                                          child: _allCourses.isEmpty
                                              ? _buildEmptyState()
                                              : _buildPages(),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    ),
                                  ),
                                  if (wide) ...[
                                    const SizedBox(width: 20),
                                    SizedBox(
                                      width: 280,
                                      child: SingleChildScrollView(
                                        child: DayOverview(
                                          courses:
                                              _coursesByWeek[_currentWeek] ??
                                              const [],
                                          sectionStartTimes: _sectionStartTimes,
                                          onAddCourse: _openAddCourse,
                                          onCourseTap: (course) =>
                                              Navigator.push<bool>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      AddCourseScreen(
                                                        totalWeeks: _totalWeeks,
                                                        editingCourse: course,
                                                      ),
                                                ),
                                              ).then((saved) {
                                                if (saved == true) _refresh();
                                              }),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: 0,
                  onDestinationSelected: _onNavigate,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.calendar_view_week_outlined),
                      selectedIcon: Icon(Icons.calendar_view_week_rounded),
                      label: '课表',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      label: '课表管理',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.tune_rounded),
                      label: '设置',
                    ),
                  ],
                ),
          floatingActionButton: wide
              ? null
              : ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _fabController,
                    curve: Curves.easeOutBack,
                  ),
                  child: FloatingActionButton.extended(
                    onPressed: _openAddCourse,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('添加课程'),
                  ),
                ),
        );
      },
    );
  }

  void _onNavigate(int index) {
    if (index == 1) _showScheduleManager();
    if (index == 2) _openSettings();
  }

  Widget _buildRail() => NavigationRail(
    selectedIndex: 0,
    onDestinationSelected: _onNavigate,
    labelType: NavigationRailLabelType.all,
    minWidth: 96,
    groupAlignment: -0.65,
    leading: Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.spa_rounded, size: 32, color: AppColors.primary),
          const SizedBox(height: 32),
          FloatingActionButton(
            onPressed: _openAddCourse,
            tooltip: '添加课程',
            child: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    ),
    destinations: const [
      NavigationRailDestination(
        icon: Icon(Icons.calendar_view_week_outlined),
        selectedIcon: Icon(Icons.calendar_view_week_rounded),
        label: Text('课表'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        label: Text('课表管理'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.tune_rounded),
        label: Text('设置'),
      ),
    ],
  );

  Widget _buildPages() => PageView.builder(
    controller: _pageController!,
    itemCount: _totalWeeks,
    onPageChanged: (page) {
      _selectedWeek = page + 1;
      _selectedWeekNotifier.value = _selectedWeek;
    },
    itemBuilder: (context, index) => ScheduleGrid(
      courses: _coursesByWeek[index + 1] ?? const <Course>[],
      allCourses: _allCourses,
      showNonCurrentWeekCourses: _showNonCurrentWeekCourses,
      isCurrentWeek: index + 1 == _currentWeek,
      onCourseDeleted: _refresh,
      onCourseEdited: _refresh,
      totalWeeks: _totalWeeks,
      dailySections: _dailySections,
      weekNumber: index + 1,
      currentWeek: _currentWeek,
      semesterStart: _semesterStart,
      sectionStartTimes: _sectionStartTimes,
      sectionDuration: _sectionDuration,
    ),
  );

  Widget _buildEmptyState() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 88),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              size: 40,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无课程',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text('可添加课程，或在设置中导入课表。', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _openAddCourse,
            icon: const Icon(Icons.add_rounded),
            label: const Text('添加第一门课程'),
          ),
        ],
      ),
    ),
  );

  Widget _buildHeader(bool wide, bool compact) {
    final now = DateTime.now();
    const weekdays = ['', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Tooltip(
                message: _scheduleName,
                child: InkWell(
                  onTap: _showScheduleManager,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            _scheduleName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.expand_more_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${now.month}/${now.day} ${weekdays[now.weekday].replaceFirst('星期', '周')}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12, wide ? 16 : 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.spa_outlined,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'DAY SCHEDULE',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${now.month}月${now.day}日 · ${weekdays[now.weekday]}',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: '切换课表',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _showScheduleManager,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _scheduleName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: wide
                                  ? Theme.of(context).textTheme.displayLarge
                                  : Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.expand_more_rounded,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (wide)
                FilledButton.icon(
                  onPressed: _openAddCourse,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('添加课程'),
                ),
            ],
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
      color = AppColors.secondary;
      icon = Icons.event_busy_rounded;
      message = '「$_scheduleName」已结束，点击标题可创建新课表';
      onTap = _showScheduleManager;
    } else {
      // notStarted
      color = AppColors.primary;
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
            borderRadius: BorderRadius.circular(20),
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
