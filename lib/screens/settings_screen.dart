import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/schedule.dart';
import '../services/course_service.dart';
import '../services/import_export_service.dart';
import '../services/widget_service.dart';
import '../utils/app_modal_sheet.dart';
import '../widgets/import_export_sheet.dart';
import '../widgets/schedule_manager_sheet.dart';
import '../utils/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static final _licenseUrl = Uri.parse(
    'https://github.com/Biapenam/open_schedule/blob/main/LICENSE',
  );
  static final _githubUrl = Uri.parse(
    'https://github.com/Biapenam/open_schedule',
  );

  final CourseService _service = CourseService();

  String _scheduleName = '我的课表';
  DateTime? _semesterStart;
  int _totalWeeks = 20;
  int _dailySections = 12;
  int _sectionDuration = 45;
  List<String> _sectionStartTimes = [];
  bool _showNonCurrentWeekCourses = true;
  bool _loading = true;
  bool _saving = false;
  bool _addingWidget = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _service.ensureMigrated();
    final schedule = await _service.getActiveSchedule();
    final start = schedule?.semesterStart;
    final weeks = schedule?.totalWeeks ?? 20;
    final sections = schedule?.dailySections ?? 12;
    final duration = schedule?.sectionDuration ?? 45;
    final times =
        schedule?.sectionStartTimes ?? await _service.loadSectionStartTimes();
    final showNonCurrent = await _service.loadShowNonCurrentWeekCourses();
    if (!mounted) return;
    setState(() {
      _scheduleName = schedule?.name ?? '我的课表';
      _semesterStart = start;
      _totalWeeks = weeks;
      _dailySections = sections;
      _sectionDuration = duration;
      _sectionStartTimes = times;
      _showNonCurrentWeekCourses = showNonCurrent;
      _loading = false;
    });
  }

  Future<void> _openScheduleManager() async {
    await ScheduleManagerSheet.show(
      context,
      service: _service,
      onChanged: () {
        Navigator.pop(context);
        _load();
      },
    );
  }

  /// 导出当前课表为口令
  Future<void> _openExport() async {
    final schedule = await _service.getActiveSchedule();
    if (!mounted) return;
    if (schedule == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前没有可导出的课表')));
      return;
    }
    final courses = await _service.loadCoursesFor(schedule.id);
    if (!mounted) return;
    final code = ImportExportService.encode(schedule, courses);
    showAppModalSheet(
      context,
      builder: (_) => ExportSheet(
        code: code,
        scheduleName: schedule.name,
        courseCount: courses.length,
      ),
    );
  }

  /// 从口令导入课表；成功后刷新并同步桌面小卡片
  Future<void> _openImport() async {
    final result = await showAppModalSheet<bool>(
      context,
      // 键盘弹出时把面板抬到输入法上方，避免挡住口令输入框
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: ImportSheet(service: _service),
      ),
    );
    if (result == true) {
      _load();
      WidgetService().updateWidget();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _semesterStart ?? DateTime.now(),
      // 允许选择过去若干年（历史学期），上限为一年后，避免硬编码年份过期
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '选择学期开始日期（第1周周一）',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _semesterStart = picked);
  }

  void _showChangelog() {
    showAppModalSheet(
      context,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '更新日志',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: const [
                  _ChangelogEntry(
                    version: 'v1.1.5',
                    isLatest: true,
                    changes: ['将应用更名为 Day Schedule', '添加了开源许可证', '修复了一些已知问题'],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.1.4',
                    isLatest: false,
                    changes: ['新增了显示非本周课程的功能'],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.1.3',
                    isLatest: false,
                    changes: ['使用吃白饭的蓝色大肥鱼修复了一些已知问题、优化了使用体验和性能开销'],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.1.2',
                    isLatest: false,
                    changes: ['新增了对Pad大屏设备的适配（测试中）', '修复了已知问题', '优化了性能开销'],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.1.1',
                    isLatest: false,
                    changes: ['修复了已知问题'],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.1.0',
                    isLatest: false,
                    changes: ['新增多课表管理功能，支持在不同课表之间切换', '修复了已知问题'],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.0.6',
                    isLatest: false,
                    changes: ['修复了已知问题'],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.0.5',
                    isLatest: false,
                    changes: ['优化了使用体验', '修复了已知问题'],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.0.4',
                    isLatest: false,
                    changes: ['修复了已知问题'],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.0.3',
                    isLatest: false,
                    changes: ['优化了使用体验', '修复了已知问题'],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.0.2',
                    isLatest: false,
                    changes: ['优化了使用体验', '修复了已知问题'],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.0.1',
                    isLatest: false,
                    changes: [
                      '新增桌面小组件功能（测试中）',
                      '将应用更名为 Open Schedule',
                      '优化了使用体验',
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_semesterStart != null) {
        await _service.saveSemesterStart(_semesterStart!);
      }
      await _service.saveTotalWeeks(_totalWeeks);
      await _service.saveDailySections(_dailySections);
      await _service.saveSectionDuration(_sectionDuration);
      await _service.saveSectionStartTimes(_sectionStartTimes);
      await _service.saveShowNonCurrentWeekCourses(_showNonCurrentWeekCourses);
      await WidgetService().updateWidget();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('设置已保存'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('save settings failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存设置失败，请重试')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // 编辑某节课的开始时间
  Future<void> _pickSectionTime(int index) async {
    final current = _sectionStartTimes.length > index
        ? _sectionStartTimes[index]
        : '08:00';
    final parts = current.split(':');
    final initTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initTime,
      helpText: '设置第 ${index + 1} 节开始时间',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        final h = picked.hour.toString().padLeft(2, '0');
        final m = picked.minute.toString().padLeft(2, '0');
        while (_sectionStartTimes.length <= index) {
          _sectionStartTimes.add('08:00');
        }
        _sectionStartTimes[index] = '$h:$m';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_scheduleName · 设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          // 平板下限制内容最大宽度并居中，避免横屏时卡片横跨整屏
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── 课表管理 ──
                    _buildCard(
                      title: '课表管理',
                      icon: Icons.collections_bookmark_rounded,
                      children: [
                        ListTile(
                          leading: _iconBox(Icons.swap_horiz_rounded),
                          title: const Text(
                            '切换 / 管理课表',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '当前：$_scheduleName',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFCCCCDD),
                          ),
                          onTap: _openScheduleManager,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: _iconBox(Icons.upload_rounded),
                          title: const Text(
                            '导出课表',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            '生成口令，可在另一台设备快速恢复',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFCCCCDD),
                          ),
                          onTap: _openExport,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: _iconBox(Icons.download_rounded),
                          title: const Text(
                            '从口令导入',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            '粘贴口令，恢复课表到本机',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFCCCCDD),
                          ),
                          onTap: _openImport,
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),

                    const SizedBox(height: 16),

                    // ── 学期信息 ──
                    _buildCard(
                      title: '学期信息与显示',
                      icon: Icons.school_rounded,
                      children: [
                        _buildDateTile(),
                        const Divider(height: 1),
                        _buildWeeksTile(),
                        const Divider(height: 1),
                        _buildShowNonCurrentWeekTile(),
                      ],
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),

                    const SizedBox(height: 16),

                    // ── 课程时间 ──
                    _buildCard(
                          title: '课程时间设置',
                          icon: Icons.schedule_rounded,
                          children: [
                            _buildDailySectionsTile(),
                            const Divider(height: 1),
                            _buildDurationTile(),
                            const Divider(height: 1),
                            _buildSectionTimesList(),
                          ],
                        )
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 400.ms)
                        .slideY(begin: 0.2),

                    const SizedBox(height: 16),

                    _buildCard(
                          title: '桌面小卡片',
                          icon: Icons.widgets_rounded,
                          children: [
                            ListTile(
                              leading: _iconBox(
                                Icons.add_to_home_screen_rounded,
                              ),
                              title: const Text(
                                '添加桌面小卡片',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: const Text(
                                '在桌面显示今天的课程',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              trailing: _addingWidget
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFFCCCCDD),
                                    ),
                              onTap: _addingWidget ? null : _requestPinWidget,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: _iconBox(Icons.help_outline_rounded),
                              title: const Text(
                                '如何手动添加',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: const Text(
                                '适用于系统没有弹出添加确认时',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFFCCCCDD),
                              ),
                              onTap: _showManualWidgetGuide,
                            ),
                          ],
                        )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms)
                        .slideY(begin: 0.2),

                    const SizedBox(height: 16),

                    // ── 关于 ──
                    _buildCard(
                          title: '关于',
                          icon: Icons.info_rounded,
                          children: [
                            _buildInfoTile('应用名称', 'Day Schedule'),
                            const Divider(height: 1),
                            _buildInfoTile('版本', '1.1.5'),
                            const Divider(height: 1),
                            _buildInfoTile('开发者', 'Sora'),
                            const Divider(height: 1),
                            _buildLinkTile(title: '开源许可证', uri: _licenseUrl),
                            const Divider(height: 1),
                            _buildLinkTile(
                              title: 'GitHub 项目主页',
                              uri: _githubUrl,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              title: const Text(
                                '更新日志',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFFCCCCDD),
                              ),
                              onTap: _showChangelog,
                            ),
                          ],
                        )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 400.ms)
                        .slideY(begin: 0.2),

                    const SizedBox(height: 32),

                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: const Text(
                        '保存设置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 16,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _requestPinWidget() async {
    setState(() => _addingWidget = true);
    try {
      final result = await WidgetService().requestPinWidget();
      if (!mounted) return;
      final accepted = result == 'accepted';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepted ? '已请求添加小卡片；如桌面未弹出确认，请手动添加' : _pinWidgetErrorText(result),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _addingWidget = false);
    }
  }

  String _pinWidgetErrorText(String result) {
    return switch (result) {
      'launcher_not_supported' => '当前桌面不支持快捷添加小卡片',
      'unsupported_android_version' ||
      'launcher_rejected' ||
      'illegal_state' => '请在桌面小组件列表中添加 Day Schedule',
      _ => '当前桌面无法快捷添加小卡片',
    };
  }

  void _showManualWidgetGuide() {
    showAppModalSheet(
      context,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.widgets_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  '手动添加桌面小卡片',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _GuideStep(index: 1, text: '回到手机桌面，长按桌面空白处。'),
            const _GuideStep(index: 2, text: '进入“小组件”或“插件”列表。'),
            const _GuideStep(index: 3, text: '找到 Day Schedule，选择课程表小卡片并添加到桌面。'),
            const SizedBox(height: 12),
            const Text(
              '不同系统的入口名称可能略有不同。若快捷添加没有弹出确认，请使用这条方式。',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTile() {
    final formatted = _semesterStart != null
        ? DateFormat('yyyy年M月d日 (E)', 'zh_CN').format(_semesterStart!)
        : '未设置';
    return ListTile(
      leading: _iconBox(Icons.calendar_today_rounded),
      title: const Text(
        '学期开始日期',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        formatted,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFFCCCCDD),
      ),
      onTap: _pickDate,
    );
  }

  Widget _buildWeeksTile() {
    return ListTile(
      leading: _iconBox(Icons.view_week_rounded),
      title: const Text(
        '学期总周数',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        '当前：$_totalWeeks 周',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: _stepper(
        value: _totalWeeks,
        min: 1,
        max: 30,
        onChanged: (v) => setState(() => _totalWeeks = v),
      ),
    );
  }

  Widget _buildShowNonCurrentWeekTile() {
    return SwitchListTile(
      secondary: _iconBox(Icons.event_note_rounded),
      title: const Text(
        '显示非本周课程',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: const Text(
        '在当前周课表空位处显示其他周次课程',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      value: _showNonCurrentWeekCourses,
      activeTrackColor: AppColors.primary,
      onChanged: (v) => setState(() => _showNonCurrentWeekCourses = v),
    );
  }

  Widget _buildDailySectionsTile() {
    return ListTile(
      leading: _iconBox(Icons.format_list_numbered_rounded),
      title: const Text(
        '每天课程节数',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        '当前：$_dailySections 节',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: _stepper(
        value: _dailySections,
        min: 4,
        max: 16,
        onChanged: (v) => setState(() => _dailySections = v),
      ),
    );
  }

  Widget _buildDurationTile() {
    return ListTile(
      leading: _iconBox(Icons.timer_rounded),
      title: const Text(
        '每节课时长',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        '当前：$_sectionDuration 分钟',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: _stepper(
        value: _sectionDuration,
        min: 20,
        max: 120,
        step: 5,
        onChanged: (v) => setState(() => _sectionDuration = v),
      ),
    );
  }

  Widget _buildSectionTimesList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '各节开始时间',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '点击时间可修改，结束时间根据课程时长自动计算',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_dailySections, (i) {
              final section = i + 1;
              final startTime = Schedule.sectionStartTimeAt(
                _sectionStartTimes,
                section,
              );
              final endTime = Schedule.calcEndTime(startTime, _sectionDuration);
              return GestureDetector(
                onTap: () => _pickSectionTime(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '第${i + 1}节',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        startTime,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        endTime,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return ListTile(
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Text(
        value,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildLinkTile({required String title, required Uri uri}) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(
        Icons.open_in_new_rounded,
        color: Color(0xFFCCCCDD),
        size: 19,
      ),
      onTap: () => _openExternalLink(uri),
    );
  }

  Future<void> _openExternalLink(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂时无法打开链接，请稍后重试')));
    }
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.primary, size: 18),
    );
  }

  Widget _stepper({
    required int value,
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_rounded),
          onPressed: value > min
              ? () => onChanged((value - step).clamp(min, max).toInt())
              : null,
          color: AppColors.primary,
          iconSize: 20,
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_rounded),
          onPressed: value < max
              ? () => onChanged((value + step).clamp(min, max).toInt())
              : null,
          color: AppColors.primary,
          iconSize: 20,
        ),
      ],
    );
  }
}

// ── 更新日志条目组件 ──────────────────────────────────────────
class _ChangelogEntry extends StatelessWidget {
  final String version;
  final bool isLatest;
  final List<String> changes;

  const _ChangelogEntry({
    required this.version,
    required this.isLatest,
    required this.changes,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧时间轴
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isLatest ? AppColors.primary : const Color(0xFFCCCCDD),
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 2, height: 80, color: AppColors.borderLight),
          ],
        ),
        const SizedBox(width: 12),
        // 右侧内容
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isLatest ? AppColors.primary : AppColors.inputFill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      version,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isLatest
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (isLatest) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '最新',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              ...changes.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '•  ',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          c,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textBody,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideStep extends StatelessWidget {
  final int index;
  final String text;

  const _GuideStep({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textBody,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
