# Day Schedule

[![release](https://img.shields.io/badge/release-v1.1.5-0d8bdc?style=flat-square)](CHANGELOG.md#v115) [![Flutter](https://img.shields.io/badge/Flutter-3.41.9-02569B?logo=flutter&logoColor=white&style=flat-square)](.github/workflows/ci.yml) [![license](https://img.shields.io/badge/license-DSNCL--1.0-f47c20?style=flat-square)](LICENSE) [![Android](https://img.shields.io/badge/Android-supported-3ddc84?logo=android&logoColor=white&style=flat-square)](#)

> 重命名说明：本次重命名同步更新了 Flutter 包名及各平台应用标识。旧版安装包与新版本不会被系统视为同一应用，正式发布前请先安排数据导出或迁移。

一个用 Flutter 制作的课程表应用，主要面向大学课表这种按周、按节次排课的场景。现在重点支持 Android。

当前版本：`v1.1.5`

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

Release 构建必须使用正式签名，不会回退到 debug 签名。首次配置时复制
`android/key.properties.example` 为 `android/key.properties`，填写正式 keystore
信息，并将 keystore 文件放在本地；`android/key.properties` 和 keystore 都不会被提交到仓库。

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
android/app/src/main/kotlin/com/biapenam/day_schedule/
android/app/src/main/res/layout/schedule_widget_layout.xml
android/app/src/main/res/xml/schedule_widget_info.xml
```

## 主要依赖

- `shared_preferences`：本地存储课程和设置。
- `home_widget`：把当天课程同步给 Android 桌面小组件。
- `flutter_animate`：页面和组件动画。
- `uuid`：生成课程 id。
- `intl`：日期格式化。

## 数据与隐私

- 课程表和应用设置仅保存在设备本地的 `shared_preferences` 中，目前没有账号、云同步、广告或分析服务。
- 口令导入导出内容包含课程表数据，请仅通过可信渠道传递，不要公开发布含个人信息的口令。
- 写入本地数据时会保留最近一次有效 JSON 备份；检测到主数据损坏时，应用会尝试自动恢复并记录本地日志。
- 卸载应用、清除应用数据或更换设备可能导致本地数据丢失，请在重要变更前导出课表。

## 已知限制

- 目前只有 Android 经过专门适配和测试，其他平台未适配。
- Android 桌面小组件的显示效果可能因系统桌面实现而异。
- 重命名应用后的新包名不会自动继承旧包名应用的数据；升级前请先导出课表。

## 使用说明

首次使用建议先进入右上角设置页，设置学期开始日期和总周数。设置好后，首页会根据当前日期计算当前周。

添加课程用右下角的加号按钮。课程保存后会写入本地，并同步刷新桌面小组件数据。

桌面小组件显示的是“今天、本周”的课程。点击小组件可以打开应用。

## 更新记录

> 完整更新记录见 [CHANGELOG.md](CHANGELOG.md)。

### v1.1.5

- 将应用更名为 Day Schedule。
- 添加了开源许可证。
- 修复了一些已知问题。

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
- 将应用更名为 Open Schedule。
- 优化了使用体验。

## 小组件说明

应用内添加桌面小组件的功能还在调试，不同 Android 桌面兼容情况不完全一致。现阶段更建议使用系统自带的小组件添加方式：

1. 回到手机桌面。
2. 长按桌面空白处。
3. 进入“小组件”或“插件”列表。
4. 找到 Day Schedule，把课程表小组件添加到桌面。
