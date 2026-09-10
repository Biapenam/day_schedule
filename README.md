# Open Schedule

一个用 Flutter 制作的课程表应用，主要面向大学课表这种按周、按节次排课的场景。现在重点支持 Android，其他平台目录是 Flutter 项目默认生成的，还没有专门适配。

当前版本：`v1.1.4`

## 目前能做什么

- 按周查看课程表，左右滑动切换周次。
- 支持在课表空位显示非本周课程（虚化淡色显示并注明具体周次）。
- 添加、编辑、删除课程。
- 设置课程名称、老师、地点、星期、节次、上课周次和颜色。
- 支持单周、双周、全选、清空等周次选择。
- 设置学期开始日期、总周数、每天节数、每节课时长和每节开始时间。
- 多课表管理：新建、切换、重命名、删除课表，不同课表独立保存学期设置与课程。
- 口令导入导出：生成课表口令，在另一台设备粘贴即可恢复课表。
- 如果周末有课，课程表会显示周六、周日。
- 保存课程时会提示同一天、同一周、节次重叠的课程。
- 支持平板大屏自适应布局（横竖屏、限宽居中）。
- 本地保存数据，使用 `shared_preferences`。
- Android 桌面小组件可以显示当天课程。

## 运行方式

先确认本机已经安装 Flutter 和 Android SDK：

```bash
flutter doctor
```

获取依赖：

```bash
flutter pub get
```

连接 Android 手机或启动模拟器后运行：

```bash
flutter run
```

打包 APK：

```bash
flutter build apk --release
```

生成文件一般在：

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 项目结构

```text
lib/
├── main.dart
├── app.dart
├── models/
│   ├── course.dart
│   └── schedule.dart
├── services/
│   ├── course_service.dart
│   ├── widget_service.dart
│   └── import_export_service.dart
├── screens/
│   ├── home_screen.dart
│   ├── add_course_screen.dart
│   └── settings_screen.dart
├── utils/
│   └── responsive.dart
└── widgets/
    ├── schedule_grid.dart
    ├── week_selector.dart
    ├── course_detail_sheet.dart
    ├── schedule_manager_sheet.dart
    └── import_export_sheet.dart
```

Android 小组件相关文件主要在：

```text
android/app/src/main/kotlin/com/example/schedule_app/
android/app/src/main/res/layout/schedule_widget_layout.xml
android/app/src/main/res/xml/schedule_widget_info.xml
```

## 主要依赖

- `shared_preferences`：本地存储课程和设置。
- `home_widget`：把当天课程同步给 Android 桌面小组件。
- `flutter_animate`：页面和组件动画。
- `uuid`：生成课程 id。
- `intl`：日期格式化。

## 使用说明

首次使用建议先进入右上角设置页，设置学期开始日期和总周数。设置好后，首页会根据当前日期计算当前周。

添加课程用右下角的加号按钮。课程保存后会写入本地，并同步刷新桌面小组件数据。

桌面小组件显示的是“今天、本周”的课程。点击小组件可以打开应用。

## 更新记录

> 完整更新记录见 [CHANGELOG.md](CHANGELOG.md)。

### v1.1.4

- 新增了显示非本周课程的功能。

### v1.1.3

- 使用吃白饭的蓝色大肥鱼修复了一些已知问题、优化了使用体验和性能开销。

### v1.1.2

- 新增了对Pad大屏设备的适配（测试中）。
- 新增了使用口令在不同设备间传输课表信息的功能。
- 修复了已知问题。
- 优化了性能开销。

### v1.1.1

- 修复了已知问题。

### v1.1.0

- 新增多课表管理功能，支持在不同课表之间切换。
- 修复了已知问题。

### v1.0.6

- 修复了已知问题。

### v1.0.5

- 优化了使用体验。
- 修复了已知问题。

### v1.0.4

- 修复了已知问题。

### v1.0.3 (unreleased)

- 优化了使用体验。
- 修复了已知问题。

### v1.0.2 (unreleased)

- 优化了使用体验。
- 修复了已知问题。

### v1.0.1 (unreleased)

- 新增桌面小组件功能（测试中）。
- 应用更名为 Open Schedule。
- 优化了使用体验。

## 小组件说明

应用内添加桌面小组件的功能还在调试，不同 Android 桌面兼容情况不完全一致。现阶段更建议使用系统自带的小组件添加方式：

1. 回到手机桌面。
2. 长按桌面空白处。
3. 进入“小组件”或“插件”列表。
4. 找到 Open Schedule，把课程表小组件添加到桌面。
