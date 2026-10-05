# Day Schedule

[![release](https://img.shields.io/badge/release-v1.2.1-0d8bdc?style=flat-square)](CHANGELOG.md#v121) [![Flutter](https://img.shields.io/badge/Flutter-3.41.9-02569B?logo=flutter&logoColor=white&style=flat-square)](.github/workflows/ci.yml) [![license](https://img.shields.io/badge/license-PolyForm_Noncommercial_1.0.0-f47c20?style=flat-square)](LICENSE) [![Android](https://img.shields.io/badge/Android-supported-3ddc84?logo=android&logoColor=white&style=flat-square)](#)

> 升级说明：v1.2.1 沿用 v1.1.5 的应用标识与数据格式，使用相同正式签名可覆盖升级。

一个用 Flutter 制作的课程表应用，主要面向大学课表这种按周、按节次排课的场景。现在重点支持 Android。

当前版本：`v1.2.1`

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
- 口令导入导出内容包含课程表数据，且仅提供完整性校验，不提供加密或来源认证；请仅通过可信渠道传递。
- 写入本地数据时会保留最近一次有效 JSON 备份；检测到主数据损坏时，应用会尝试自动恢复并记录本地日志。
- 卸载应用、清除应用数据或更换设备可能导致本地数据丢失，请在重要变更前导出课表。

## 已知限制

- 目前只有 Android 经过专门适配和测试，其他平台未适配。
- Android 桌面小组件的显示效果可能因系统桌面实现而异。
- 从独立 M3 测试版或历史不同包名的版本迁移时，需要通过口令导出、导入课程。

## 使用说明

首次使用建议先进入底部导航或侧边导航的设置页，设置学期开始日期和总周数。设置好后，首页会根据当前日期计算当前周。

添加课程用右下角的加号按钮。课程保存后会写入本地，并同步刷新桌面小组件数据。

桌面小组件显示的是“今天、本周”的课程。点击小组件可以打开应用。

## 更新记录

> 完整更新记录见 [CHANGELOG.md](CHANGELOG.md)。

### v1.2.1

- 优化了新UI的视觉体验
- 修复了已知问题

### v1.2.0

- 对UI进行了重新设计
- 完成了对Pad大屏设备的调试

### v1.1.5

- 将应用更名为 Day Schedule。
- 使用 PolyForm Noncommercial License 1.0.0。
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

## 界面设计与验证

- 基于 Material 3，默认跟随系统深浅模式。全局主题在 `lib/app.dart`，语义颜色映射在 `lib/utils/app_colors.dart`。
- `AppSectionCard` 统一表单与设置分组；`AppChoiceButton` 统一选择状态、焦点和点击反馈；`SheetHeading` 统一弹层标题与关闭入口。
- 手机优先显示课表；宽屏提供侧边导航、今日概览。课程编辑在 840 logical px 起使用双栏，最大内容宽度为 1120。
- 课程颜色从已有数据生成明暗色调，不修改存储的课程数据。短卡片优先显示课程名。
- 页面尊重减少动画设置；设置页固定保存操作，长弹层可滚动。
- `test/design_system_test.dart` 覆盖文字对比度、系统深色模式、320px 窄屏放大文字，以及 30 周横屏选择面板。

视觉预览使用独立的内存数据入口，不写入实际课表：

```bash
flutter run -d chrome -t lib/preview.dart
```

Web 预览 URL 可附加 `?theme=dark` 或 `?theme=light` 检查外观。生产入口仍为 `lib/main.dart`。

验证命令：

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```
