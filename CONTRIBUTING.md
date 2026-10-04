# 贡献指南 / Contributing

欢迎提交 Issue 和 Pull Request。请先阅读 [README.md](README.md) 或 [README.en.md](README.en.md)，了解运行方式和平台限制。

## 开发与验证

- 使用 Xcode 26 或更新版本，打开 `ios/LifeLedger.xcodeproj`，选择 LifeLedger scheme。
- 目标系统为 iOS 17+，不引入额外依赖即可运行。
- 涉及账本、积分、备份、加密或迁移时，添加能验证真实行为和失败恢复的测试。
- 在自己的模拟器上运行 README 中的 `xcodebuild test`，保持模拟器签名开启。
- 工程文件已提交，通常无需重新生成。确有需要时运行 `python3 ios/scripts/generate_project.py`，并检查工程差异。

测试目录中的 ZIP 均为合成测试数据。`unsafe_fixture.zip` 故意包含目录穿越路径，用于验证导入拒绝不安全内容。

## 变更约定

- 保持系统原生控件、无应用账号和本地优先的数据体验。
- 界面文案同时提供简体中文与英文。
- 修改持久化结构时兼容旧记录；备份和 Android 导入必须先验证后覆盖。
- XP 通过积分流水计算，不能因重复完成、取消或退款而重复发放。
- 不提交签名证书、个人媒体、真实账本、测试输出或 Xcode 用户状态。
- PR 描述说明问题、变更后的行为、验证结果及数据兼容性的影响。

## Bug 反馈

请附 iOS/Xcode 版本、重现步骤、预期和实际结果。可以提供使用测试数据的截图，避免上传真实私人账本或备份口令。

## English

Open the shared Xcode project and run the commands in the English README using an installed simulator. Keep the iOS 17 deployment target, native controls, bilingual UI strings, and backward-compatible data decoding. Add meaningful tests for changes to persistence, XP, backups, encryption, or migration. Explain the trigger, resulting behavior, validation, and compatibility implications in your pull request. Submit only source files and intentional assets; exclude signing credentials, personal ledgers, media, and build outputs.

Contributions are distributed under this repository's [MIT license](LICENSE).
