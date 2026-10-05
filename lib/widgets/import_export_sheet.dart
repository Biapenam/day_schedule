import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/course.dart';
import '../models/schedule.dart';
import '../services/course_service.dart';
import '../services/import_export_service.dart';
import '../utils/app_colors.dart';
import 'app_components.dart';

// ─────────────────────────────────────────────────────────────
// 导出课表：展示口令 + 复制
// ─────────────────────────────────────────────────────────────
class ExportSheet extends StatelessWidget {
  final String code;
  final String scheduleName;
  final int courseCount;

  const ExportSheet({
    super.key,
    required this.code,
    required this.scheduleName,
    required this.courseCount,
  });

  /// 每 4 位分组展示，方便核对
  String _grouped(String s) {
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final display = _grouped(code);
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            SheetHeading(title: '导出课表口令', icon: Icons.upload_rounded),
            const SizedBox(height: 12),
            Text(
              '口令包含「$scheduleName」（$courseCount 门课程）。在另一台设备打开「设置 → 课表管理 → 从口令导入」并粘贴即可恢复。',
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // 口令卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.inputFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.colors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  display,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.6,
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('口令已复制，去另一台设备粘贴导入吧'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text(
                  '复制口令',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 导入课表：粘贴口令 → 解析预览 → 确认导入（含冲突处理）
// ─────────────────────────────────────────────────────────────
class ImportSheet extends StatefulWidget {
  final CourseService service;

  const ImportSheet({super.key, required this.service});

  @override
  State<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<ImportSheet> {
  final TextEditingController _ctrl = TextEditingController();
  ExportData? _parsed;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _parse() {
    final input = _ctrl.text.trim();
    if (input.isEmpty) {
      setState(() {
        _error = '请先粘贴或输入口令';
        _parsed = null;
      });
      return;
    }
    try {
      final data = ImportExportService.decode(input);
      setState(() {
        _parsed = data;
        _error = null;
      });
    } on FormatException catch (e) {
      setState(() {
        _parsed = null;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _parsed = null;
        _error = '口令解析失败，请确认口令完整无误';
      });
    }
  }

  /// 执行导入，处理同名课表冲突。
  /// 导入成功后以 `true` 关闭面板。
  Future<void> _doImport() async {
    final data = _parsed;
    if (data == null) return;

    final schedules = await widget.service.loadSchedules();
    final sameName = schedules
        .where((s) => s.name == data.schedule.name)
        .toList();

    if (sameName.isNotEmpty) {
      final action = await _askConflict(data.schedule.name);
      if (action == null) return; // 用户取消
      if (action == 'overwrite') {
        // 覆盖同名课表：保留原 id，更新元数据与课程
        final existing = sameName.first;
        await _runImport(
          schedule: existing.copyWith(
            semesterStart: data.schedule.semesterStart,
            totalWeeks: data.schedule.totalWeeks,
            dailySections: data.schedule.dailySections,
            sectionStartTimes: data.schedule.sectionStartTimes,
            sectionDuration: data.schedule.sectionDuration,
          ),
          courses: data.courses,
        );
        return;
      }
      // 'new'：另存为新课表（名称加后缀）
      await _runImport(
        schedule: data.schedule.copyWith(name: '${data.schedule.name} (导入)'),
        courses: data.courses,
      );
      return;
    }

    // 无同名冲突：直接以口令中的名称导入
    await _runImport(schedule: data.schedule, courses: data.courses);
  }

  /// 真正写入课表与课程（显示忙碌状态，完成后关闭面板）
  Future<void> _runImport({
    required Schedule schedule,
    required List<Course> courses,
  }) async {
    setState(() => _busy = true);
    try {
      await widget.service.saveScheduleMeta(schedule);
      await widget.service.saveCoursesFor(schedule.id, courses);
      await widget.service.setActiveSchedule(schedule.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('import failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('导入失败，请重试')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askConflict(String name) {
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('已存在同名课表'),
        content: Text('本机已有名为「$name」的课表。选择如何处理？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'new'),
            child: const Text('另存为新课表'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'overwrite'),
            child: const Text('覆盖'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            SheetHeading(title: '从口令导入课表', icon: Icons.download_rounded),
            const SizedBox(height: 12),
            Text(
              '粘贴另一台设备导出的口令，即可恢复课表。',
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              minLines: 2,
              style: const TextStyle(fontSize: 13, height: 1.5),
              decoration: InputDecoration(
                hintText: '例如：OS1:xxxxx...（长按可粘贴）',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
              onSubmitted: (_) => _parse(),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _parse,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text(
                  '解析口令',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: context.colors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (parsed != null) ...[
              const SizedBox(height: 12),
              _buildPreview(parsed),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _doImport,
                  icon: _busy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.onPrimary,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                  label: Text(
                    _busy ? '正在导入…' : '导入 ${parsed.schedule.name}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(ExportData data) {
    final s = data.schedule;
    final startText = s.semesterStart == null
        ? '未设置'
        : '${s.semesterStart!.year}年${s.semesterStart!.month}月${s.semesterStart!.day}日';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '即将导入',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${data.courses.length} 门课程 · 共 ${s.totalWeeks} 周 · '
            '每天 ${s.dailySections} 节 · 学期开始 $startText',
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
