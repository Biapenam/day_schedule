# 贡献指南

感谢你为 Day Schedule 提交问题或代码。当前版本为 `v1.1.5`，Android 是主要适配平台，其他平台暂未适配。

## 本地开发

环境建议使用 Flutter 3.41.9 stable，并确保 Android SDK 可用：

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

提交前请确保格式化、静态分析和测试均通过。涉及界面或交互变化时，请在 PR 描述中说明验证方式；截图不是必需项。

## 提交 Pull Request

- 每个 PR 聚焦一个问题，描述背景、改动和已验证的行为。
- 新增行为应尽量补充测试；修复问题时请附上可复现步骤或测试用例。
- 不要提交 keystore、`android/key.properties`、导出的个人课表或其他敏感信息。
- 平台相关改动请明确说明测试平台；未适配平台不要声称已支持。

## 发布签名

Release 构建必须配置正式签名。请复制 `android/key.properties.example` 为本地的
`android/key.properties`，不要将密钥文件或配置提交到仓库。缺少正式签名配置时，Release 构建会主动失败，不会回退到 debug 签名。

## 许可证

项目使用 [Day Schedule Non-Commercial License (DSNCL) v1.0](LICENSE)。非商业用途可按许可证使用；商业用途须事先取得书面许可。提交贡献即表示你同意贡献内容可在该许可证下随项目分发。
