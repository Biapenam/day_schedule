import 'package:flutter/material.dart';
import '../models/schedule.dart';
import '../services/course_service.dart';
import '../utils/app_modal_sheet.dart';
import '../utils/app_colors.dart';

/// 课表管理底部面板：新建、切换、重命名、删除课表。
/// 切换或新建后会通过 onChanged 回调通知调用方刷新。
class ScheduleManagerSheet extends StatefulWidget {
  final CourseService service;
  final VoidCallback onChanged;

  const ScheduleManagerSheet({
    super.key,
    required this.service,
    required this.onChanged,
  });

  /// 便捷打开方式
  static Future<void> show(
    BuildContext context, {
    required CourseService service,
    required VoidCallback onChanged,
  }) {
    return showAppModalSheet(
      context,
      builder: (_) =>
          ScheduleManagerSheet(service: service, onChanged: onChanged),
    );
  }

  @override
  State<ScheduleManagerSheet> createState() => _ScheduleManagerSheetState();
}

class _ScheduleManagerSheetState extends State<ScheduleManagerSheet> {
  List<Schedule> _schedules = [];
  String? _activeId;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final schedules = await widget.service.loadSchedules();
    final activeId = await widget.service.getActiveScheduleId();
    if (!mounted) return;
    setState(() {
      _schedules = schedules;
      _activeId = activeId;
      _loading = false;
    });
  }

  Future<void> _switchTo(String id) async {
    if (id == _activeId) {
      Navigator.pop(context);
      return;
    }
    await widget.service.setActiveSchedule(id);
    widget.onChanged();
  }

  Future<void> _createSchedule() async {
    final name = await _showNameDialog(title: '新建课表', hint: '如：2026春季学期');
    if (name == null) return;
    setState(() => _busy = true);
    try {
      final schedule = await widget.service.createSchedule(name);
      await widget.service.setActiveSchedule(schedule.id);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onChanged();
    } catch (e) {
      debugPrint('createSchedule failed: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('新建课表失败，请重试')));
    }
  }

  Future<void> _renameSchedule(Schedule schedule) async {
    final name = await _showNameDialog(
      title: '重命名课表',
      hint: '课表名称',
      initial: schedule.name,
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await widget.service.renameSchedule(schedule.id, name.trim());
      if (!mounted) return;
      setState(() {
        final idx = _schedules.indexWhere((s) => s.id == schedule.id);
        if (idx != -1) {
          _schedules[idx] = _schedules[idx].copyWith(name: name.trim());
        }
      });
    } catch (e) {
      debugPrint('renameSchedule failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('重命名失败，请重试')));
    }
  }

  Future<void> _deleteSchedule(Schedule schedule) async {
    if (_schedules.length <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('至少需要保留一个课表')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除课表'),
        content: Text('确定删除「${schedule.name}」及其所有课程吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final wasActive = schedule.id == _activeId;
    try {
      await widget.service.deleteSchedule(schedule.id);
      if (!mounted) return;
      setState(() {
        _schedules.removeWhere((s) => s.id == schedule.id);
      });
      if (wasActive) {
        widget.onChanged();
      }
    } catch (e) {
      debugPrint('deleteSchedule failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除课表失败，请重试')));
    }
  }

  Future<String?> _showNameDialog({
    required String title,
    required String hint,
    String initial = '',
  }) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: AppColors.inputFill,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        12,
        0,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.collections_bookmark_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  '课表管理',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _busy ? null : _createSchedule,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    '新建',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _schedules.length,
                itemBuilder: (_, index) {
                  final s = _schedules[index];
                  final isActive = s.id == _activeId;
                  return _buildScheduleTile(s, isActive);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleTile(Schedule schedule, bool isActive) {
    String subtitle;
    if (schedule.semesterStart != null) {
      final s = schedule.semesterStart!;
      subtitle = '${s.year}年${s.month}月${s.day}日开始 · ${schedule.totalWeeks}周';
    } else {
      subtitle = '未设置学期开始日期';
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (isActive ? AppColors.primary : const Color(0xFFAAAAAA))
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isActive ? Icons.check_circle_rounded : Icons.calendar_month_rounded,
          color: isActive ? AppColors.primary : AppColors.textSecondary,
          size: 20,
        ),
      ),
      title: Text(
        schedule.name,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            color: AppColors.textSecondary,
            onPressed: () => _renameSchedule(schedule),
            tooltip: '重命名',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: AppColors.secondary,
            onPressed: () => _deleteSchedule(schedule),
            tooltip: '删除',
          ),
        ],
      ),
      onTap: () => _switchTo(schedule.id),
    );
  }
}
