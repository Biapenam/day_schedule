import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'services/course_service.dart';
import 'services/widget_service.dart';
import 'widgets/adaptive_orientation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 相互独立的初始化并行执行，缩短冷启动：
  // 日期本地化数据、小组件服务、旧数据迁移
  await Future.wait([
    initializeDateFormatting('zh_CN', null),
    WidgetService.init(),
    CourseService().ensureMigrated(),
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const AdaptiveOrientation(child: DayScheduleApp()));
}
