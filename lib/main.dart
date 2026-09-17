import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'services/course_service.dart';
import 'services/widget_service.dart';
import 'utils/responsive.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 相互独立的初始化并行执行，缩短冷启动：
  // 日期本地化数据、小组件服务、旧数据迁移、屏幕方向设置
  await Future.wait([
    initializeDateFormatting('zh_CN', null),
    WidgetService.init(),
    CourseService().ensureMigrated(),
    _setPreferredOrientations(),
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const DayScheduleApp());
}

/// 设置屏幕方向：
/// - 平板（短边 >= 600dp）：允许横竖屏旋转，配合平板响应式布局
/// - 手机：保持原有的竖屏锁定，不改变现有手机端体验
Future<void> _setPreferredOrientations() async {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final logicalSize = view.physicalSize / view.devicePixelRatio;
  final isTablet =
      math.max(logicalSize.width, logicalSize.height) >=
      Responsive.tabletBreakpoint;
  if (isTablet) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
}
