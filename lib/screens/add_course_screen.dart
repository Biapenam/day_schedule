import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../models/schedule.dart';
import '../services/course_service.dart';
import '../services/widget_service.dart';
import '../utils/app_colors.dart';
import '../widgets/app_components.dart';

class AddCourseScreen extends StatefulWidget {
  final int totalWeeks;
  final Course? editingCourse;

  const AddCourseScreen({
    super.key,
    required this.totalWeeks,
    this.editingCourse,
  });

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final CourseService _service = CourseService();

  late TextEditingController _nameCtrl;
  late TextEditingController _teacherCtrl;
  late TextEditingController _locationCtrl;

  int _dayOfWeek = 1;
  int _startSection = 1;
  int _endSection = 2;
  int _selectedColor = courseColors[0];
  Set<int> _selectedWeeks = {};
  bool _saving = false;
  int _dailySections = 12;
  List<String> _sectionStartTimes = [];
  int _sectionDuration = 45;

  bool get _isEditing => widget.editingCourse != null;

  @override
  void initState() {
    super.initState();
    final c = widget.editingCourse;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _teacherCtrl = TextEditingController(text: c?.teacher ?? '');
    _locationCtrl = TextEditingController(text: c?.location ?? '');
    _dayOfWeek = c?.dayOfWeek ?? 1;
    _startSection = c?.startSection ?? 1;
    _endSection = c?.endSection ?? 2;
    _selectedColor = c?.colorValue ?? courseColors[0];
    _selectedWeeks = c != null ? Set<int>.from(c.weeks) : {};
    if (_selectedWeeks.isEmpty) {
      _selectedWeeks = Set<int>.from(
        List.generate(widget.totalWeeks, (i) => i + 1),
      );
    }
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final sections = await _service.loadDailySections();
    final times = await _service.loadSectionStartTimes();
    final duration = await _service.loadSectionDuration();
    if (!mounted) return;
    setState(() {
      _dailySections = sections;
      _sectionStartTimes = times;
      _sectionDuration = duration;
      if (_startSection > sections) _startSection = 1;
      if (_endSection > sections) _endSection = sections;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _teacherCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  String _getStartTime(int section) =>
      Schedule.sectionStartTimeAt(_sectionStartTimes, section);

  String _getEndTime(int section) =>
      Schedule.calcEndTime(_getStartTime(section), _sectionDuration);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWeeks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少选择一个上课周次')));
      return;
    }
    final conflicts = await _findConflicts();
    if (!mounted) return;
    if (conflicts.isNotEmpty) {
      final shouldContinue = await _showConflictDialog(conflicts);
      if (shouldContinue != true) return;
    }
    setState(() => _saving = true);
    final course = Course(
      id: _isEditing ? widget.editingCourse!.id : const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      teacher: _teacherCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      colorValue: _selectedColor,
      weeks: _selectedWeeks.toList()..sort(),
      dayOfWeek: _dayOfWeek,
      startSection: _startSection,
      endSection: _endSection,
    );
    try {
      if (_isEditing) {
        await _service.updateCourse(course);
      } else {
        await _service.addCourse(course);
      }
      await WidgetService().updateWidget();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('save course failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存课程失败，请重试')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<Course>> _findConflicts() async {
    final courses = await _service.loadCourses();
    final candidate = Course(
      id: _isEditing ? widget.editingCourse!.id : 'editing',
      name: '',
      teacher: '',
      location: '',
      colorValue: 0,
      weeks: _selectedWeeks.toList(),
      dayOfWeek: _dayOfWeek,
      startSection: _startSection,
      endSection: _endSection,
    );
    return courses.where((course) {
      if (_isEditing && course.id == widget.editingCourse!.id) return false;
      return Course.overlaps(candidate, course);
    }).toList();
  }

  Future<bool?> _showConflictDialog(List<Course> conflicts) {
    final names = conflicts.take(3).map((c) => '「${c.name}」').join('、');
    final extra = conflicts.length > 3 ? '等 ${conflicts.length} 门课程' : '';

    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('课程时间可能冲突'),
        content: Text(
          '当前时间与 $names$extra 有重叠。仍然保存吗？',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('返回修改'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑课程' : '添加课程'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.onPrimary,
                      ),
                    )
                  : const Text(
                      '保存',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        // 平板（宽度 >= 840）：双栏布局，充分利用横向空间；
        // 手机 / 窄屏：保持单栏。
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final twoColumn = constraints.maxWidth >= 840;
                final padding = twoColumn ? 24.0 : 16.0;
                // 周次格子在双栏下按栏宽动态决定列数
                final weekColumns = twoColumn
                    ? (((constraints.maxWidth - padding * 2 - 20) / 2 / 72)
                          .floor()
                          .clamp(4, 8))
                    : constraints.maxWidth < 360
                    ? 4
                    : 5;
                return ListView(
                  padding: EdgeInsets.all(padding),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (!twoColumn) ...[
                      _sectionBasicInfo(),
                      const SizedBox(height: 20),
                      _sectionClassTime(),
                      const SizedBox(height: 20),
                      _sectionWeeks(weekColumns),
                      const SizedBox(height: 20),
                      _sectionColor(),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _sectionBasicInfo(),
                                const SizedBox(height: 20),
                                _sectionClassTime(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _sectionWeeks(weekColumns),
                                const SizedBox(height: 20),
                                _sectionColor(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── 双栏 / 单栏共享的 section ─────────────────────────────
  Widget _sectionBasicInfo() {
    return _IntroGate(
      child: _buildSection('基本信息', [
        _buildTextField(
          _nameCtrl,
          '课程名称 *',
          Icons.book_rounded,
          validator: (v) => (v == null || v.trim().isEmpty) ? '请输入课程名称' : null,
        ),
        const SizedBox(height: 12),
        _buildTextField(_teacherCtrl, '任课教师（可选）', Icons.person_rounded),
        const SizedBox(height: 12),
        _buildTextField(_locationCtrl, '上课地点（可选）', Icons.location_on_rounded),
      ]),
    );
  }

  Widget _sectionClassTime() {
    return _IntroGate(
      delay: 40.ms,
      child: _buildSection('上课时间', [
        _buildDayPicker(),
        const SizedBox(height: 14),
        _buildSectionPicker(),
      ]),
    );
  }

  Widget _sectionWeeks(int crossAxisCount) {
    return _IntroGate(
      delay: 80.ms,
      child: _buildSection('上课周次', [
        _buildWeekPicker(crossAxisCount: crossAxisCount),
      ]),
    );
  }

  Widget _sectionColor() {
    return _IntroGate(
      delay: 120.ms,
      child: _buildSection('课程颜色', [_buildColorPicker()]),
    );
  }

  Widget _buildSection(String title, List<Widget> children) => AppSectionCard(
    title: title,
    subtitle: switch (title) {
      '基本信息' => '填写课程名称，教师与地点可稍后补充',
      '上课时间' => '选择星期与连续上课节次',
      '上课周次' => '按学期安排，支持单周与双周',
      _ => '在课表中快速识别这门课程',
    },
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      textInputAction: TextInputAction.next,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: context.colors.primary),
      ),
    );
  }

  Widget _buildDayPicker() {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Wrap on narrow screens instead of shrinking seven targets below 48 dp.
        final columns = constraints.maxWidth < 7 * 52 ? 4 : 7;
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(
            7,
            (i) => SizedBox(
              width: (constraints.maxWidth - (columns - 1) * 4) / columns,
              child: AppChoiceButton(
                label: days[i],
                semanticLabel: '星期${days[i]}',
                selected: _dayOfWeek == i + 1,
                onPressed: () => setState(() => _dayOfWeek = i + 1),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '节次',
          style: TextStyle(
            fontSize: 12,
            color: context.colors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SectionDropdown(
                label: '开始节次',
                value: _startSection,
                max: _dailySections,
                onChanged: (v) {
                  setState(() {
                    _startSection = v;
                    if (_endSection < v) _endSection = v;
                  });
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '—',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 18,
                ),
              ),
            ),
            Expanded(
              child: _SectionDropdown(
                label: '结束节次',
                value: _endSection,
                min: _startSection,
                max: _dailySections,
                onChanged: (v) => setState(() => _endSection = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${_getStartTime(_startSection)} — ${_getEndTime(_endSection)}',
          style: TextStyle(
            fontSize: 12,
            color: context.colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekPicker({int crossAxisCount = 5}) {
    final allSelected = _selectedWeeks.length == widget.totalWeeks;
    // 单周：1,3,5...  双周：2,4,6...
    final oddWeeks = List.generate(
      widget.totalWeeks,
      (i) => i + 1,
    ).where((w) => w.isOdd).toSet();
    final evenWeeks = List.generate(
      widget.totalWeeks,
      (i) => i + 1,
    ).where((w) => w.isEven).toSet();
    final isOddSelected =
        _selectedWeeks.containsAll(oddWeeks) &&
        _selectedWeeks.difference(oddWeeks).isEmpty;
    final isEvenSelected =
        _selectedWeeks.containsAll(evenWeeks) &&
        _selectedWeeks.difference(evenWeeks).isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部：已选信息 + 全选
        Row(
          children: [
            Expanded(
              child: Text(
                '已选 ${_selectedWeeks.length} / ${widget.totalWeeks} 周',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _QuickChip(
              label: '全选',
              active: allSelected,
              onTap: () => setState(() {
                if (allSelected) {
                  _selectedWeeks.clear();
                } else {
                  _selectedWeeks = Set<int>.from(
                    List.generate(widget.totalWeeks, (i) => i + 1),
                  );
                }
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 快捷选择：单周 / 双周
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _QuickChip(
              label: '单周',
              icon: Icons.looks_one_rounded,
              active: isOddSelected,
              onTap: () =>
                  setState(() => _selectedWeeks = Set<int>.from(oddWeeks)),
            ),
            _QuickChip(
              label: '双周',
              icon: Icons.looks_two_rounded,
              active: isEvenSelected,
              onTap: () =>
                  setState(() => _selectedWeeks = Set<int>.from(evenWeeks)),
            ),
            _QuickChip(
              label: '清空',
              icon: Icons.clear_rounded,
              active: false,
              onTap: () => setState(() => _selectedWeeks.clear()),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 周格子（列数按可用宽度动态调整）
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: 48,
          ),
          itemCount: widget.totalWeeks,
          itemBuilder: (_, i) {
            final week = i + 1;
            final selected = _selectedWeeks.contains(week);
            return AppChoiceButton(
              label: '$week',
              semanticLabel: '第 $week 周',
              selected: selected,
              onPressed: () => setState(() {
                if (selected) {
                  _selectedWeeks.remove(week);
                } else {
                  _selectedWeeks.add(week);
                }
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _buildColorPicker() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: List.generate(courseColors.length, (i) {
      final colorVal = courseColors[i];
      final color = Color(colorVal);
      final selected = _selectedColor == colorVal;
      final foreground =
          ThemeData.estimateBrightnessForColor(color) == Brightness.dark
          ? Colors.white
          : Colors.black;
      return Semantics(
        selected: selected,
        child: Tooltip(
          message: '课程颜色 ${i + 1}',
          child: IconButton(
            onPressed: () => setState(() => _selectedColor = colorVal),
            style: IconButton.styleFrom(
              backgroundColor: color,
              foregroundColor: foreground,
              fixedSize: const Size(48, 48),
              side: selected
                  ? BorderSide(color: context.colors.textPrimary, width: 2)
                  : BorderSide.none,
            ),
            icon: Icon(
              selected ? Icons.check_rounded : Icons.circle,
              size: selected ? 22 : 0,
            ),
          ),
        ),
      );
    }),
  );
}

// ── 快捷选择按钮 ──────────────────────────────────────────────
class _QuickChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: active,
    onSelected: (_) => onTap(),
    visualDensity: VisualDensity.compact,
    avatar: icon == null ? null : Icon(icon, size: 16),
  );
}

/// 一次性入场动画门：动画只在首次挂载时播放一次，
/// 避免父级 setState 重建时 section 反复重放入场动画造成闪烁。
class _IntroGate extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _IntroGate({required this.child, this.delay = Duration.zero});

  @override
  State<_IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<_IntroGate> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done || MediaQuery.disableAnimationsOf(context)) return widget.child;
    return widget.child
        .animate(
          onComplete: (_) {
            if (mounted) setState(() => _done = true);
          },
        )
        .fadeIn(delay: widget.delay, duration: 220.ms)
        .slideY(begin: 0.04);
  }
}

// ── 节次下拉框 ────────────────────────────────────────────────
class _SectionDropdown extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _SectionDropdown({
    required this.label,
    required this.value,
    this.min = 1,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: context.colors.inputFill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: DropdownButton<int>(
          value: value.clamp(min, max),
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: context.colors.surface,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: List.generate(max - min + 1, (i) {
            final s = min + i;
            return DropdownMenuItem(value: s, child: Text('第 $s 节'));
          }),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }
}
