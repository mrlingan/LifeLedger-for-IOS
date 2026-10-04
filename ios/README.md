# LifeLedger · 人生账本 iOS

[LifeLedger](https://github.com/mrlingan/LifeLedger) 的 SwiftUI 原生 iPhone / iPad 版本。记录默认保存在设备上，无需应用账号，无自建服务器、无第三方 SDK；可手动备份到 iCloud Drive。本仓库独立维护 iOS 工程，Android 版本请访问原项目。

## 用 Xcode 运行

1. 用 **Xcode 26 或更新版本**打开 `ios/LifeLedger.xcodeproj`。
2. Scheme 选择 **LifeLedger**，设备选择 iPhone 或 iPad 模拟器。
3. 按 **⌘R** 运行。最低系统为 **iOS 17**，无须安装 CocoaPods 或下载 Swift Package。
4. 真机运行时，在 **Signing & Capabilities → Team** 选择自己的 Apple 开发团队，并根据需要修改 Bundle Identifier。模拟器无需开发者账号。

首次运行可以把 109 条预设成就加入账本，或从空白开始。两种选择都可浏览完整图鉴。

## 已实现

- **首页**：日期、问候语、资料和阶段、人生进度、快捷入口、四项核心数据、分类进度、最近解锁、记录起点和自定义图片。设置中可开关、拖动排序。
- **成就**：新增、编辑、删除、关键词搜索、完成状态筛选、手动指定或调整完成日期；删除会清理相关笔记和媒体。
- **图鉴**：复用 Android 的 109 条预设、14 个分类和完整英文翻译；按达成率计算五档稀有度；支持搜索、分类和解锁状态筛选。
- **笔记与媒体**：笔记增删改；系统照片选择器导入照片、视频、Live Photo；保留原始媒体副本，视频可播放，长按 Live Photo 打开系统菜单播放配对视频。
- **成长**：每完成一条成就 +50 XP，每 5 条提升一个阶段；分类属性每 200 XP 提升一级；累计积分曲线、今日/本周/本月变化、成长流水。
- **目标和任务**：创建/编辑/暂停/删除目标，添加任务，完成后记入积分；任务全完成即显示目标完成。
- **积分商城**：6 个起始奖励、自定义奖励增删改、分类筛选、积分兑换、兑换历史和撤销。积分由不可变流水求和；反复完成、取消或退款不会重复记账。
- **个人资料**：昵称、签名、Emoji 头像、照片头像、性别、MBTI。
- **设置**：系统/浅色/深色主题，系统/简体中文/English，背景图强度、默认图标、关注分类、完成确认、音效和触感。
- **每日提醒**：由 iOS 本地通知安排；仅开启时申请通知权限。
- **应用锁**：系统数字键盘输入 6 位应用 PIN，Face ID / Touch ID / 设备密码；进入后台后重新上锁。PIN 使用盐和 PBKDF2 派生值存于 Keychain。
- **本地加密**：可选 AES-256-GCM 加密结构化账本，设备密钥保存在 Keychain。所有私有文件启用 iOS 文件保护。
- **iCloud Drive 备份**：在备份页点击“备份到 iCloud Drive”，用系统文件保存面板选择 iCloud Drive 文件夹。可使用与本地导出相同的备份口令。已有云端备份可通过系统文件选择器导入。仅在系统确认保存后显示保存成功，取消不会产生成功提示。
- **备份**：ZIP 包含所有 iOS 结构化数据和媒体，覆盖成长、积分、目标、任务和商城。可设口令加密；先验证后确认覆盖，使用暂存目录恢复，失败时保留原账本。
- **Android 迁移**：可读取原应用普通 ZIP 或 `LIFELED1` 加密备份（PBKDF2-HMAC-SHA256、120000 次、AES-256-GCM），迁移成就、笔记、媒体、昵称、签名和头像。

## 平台差异与当前限制

- 界面统一使用原生 TabView、NavigationStack、List、Form、Section、Button、Picker 和 ProgressView。材质和交互由 iOS 版本与系统设置决定；不提供自定义玻璃开关。内置头像使用 Emoji。
- iOS 版已移除开发者选项、演示数据生成入口及生成代码。
- iOS 每日一言使用本地文案，未接入 Android 的可选联网每日一言。
- Android 的现有备份不含积分流水、目标、任务和商城；迁移时按已完成成就重建积分，每条 +50 XP，商城使用起始目录。Android 的平台设置不直接迁移。
- **迁移方向目前为 Android → iOS**。iOS 的完整 ZIP 使用独立数据结构，原 Android 应用尚不能导入它。
- 媒体使用 iOS 文件保护，不进行额外 AES 内容加密。PIN 和设备密钥不包含在备份中；恢复后通知和设备认证锁需重新开启。
- ZIP 导入与导出目前在内存中处理：单文件上限 512 MiB、总包上限 1 GiB。大型视频备份仍受设备内存限制。
- 已验证模拟器构建及自动化流程。Face ID、真实照片库的 Live Photo 和通知到达行为需在真机继续验证；尚未配置发行签名或提交 App Store。

## 验证与预览

使用 Xcode 27.0 完成 Debug 模拟器构建、Release 真机目标编译，以及 13 项单元测试和 3 项界面测试（全部通过，包含系统保存面板的保存与取消流程）。真机目标编译使用无签名方式，仅验证编译，不代表已安装到物理设备。

| 首页（首次添加预设） | 成就图鉴 | 成就详情与笔记 |
| --- | --- | --- |
| ![首页](../docs/screenshots/ios/home.png) | ![图鉴](../docs/screenshots/ios/codex.png) | ![详情](../docs/screenshots/ios/detail.png) |

## 保存到 iCloud Drive

1. 在系统设置中登录 Apple 账户并开启 iCloud Drive。
2. 打开应用“设置 → 备份与恢复”，按需填写备份口令。
3. 点击“备份到 iCloud Drive”，在系统保存面板的“浏览 / 位置”中选择 iCloud Drive，选择文件夹并保存。
4. 在另一台设备的“选择备份文件”中选择这份 ZIP，输入口令、验证内容，再确认恢复。

该入口使用 Apple 的 [SwiftUI fileExporter 导出 API](https://developer.apple.com/documentation/swiftui/view/fileexporter(ispresented:document:contenttypes:defaultfilename:oncompletion:oncancellation:))。保存位置由用户选择，云端上传由 iCloud Drive 处理；不是自动连续同步或 CloudKit 数据库。应用不需要专属 iCloud 容器，模拟器未登录 Apple 账户时无法验证实际云端上传。

## 工程结构

```text
LifeLedger.xcodeproj/          已共享的 LifeLedger scheme
LifeLedger/
  Models/Models.swift         数据结构、图鉴、统计和编码格式
  Services/LedgerStore.swift  统一状态、原子持久化与积分账本
  Services/BackupService.swift ZIP 备份、Android 迁移和恢复
  Services/Archive.swift      无第三方依赖的 ZIP/DEFLATE
  Services/Security.swift     Keychain、PBKDF2、AES-GCM、设备认证
  Services/ReminderService.swift 本地通知
  Views/                     原生 SwiftUI 页面及数据展示组件
  Resources/                 图鉴、中英文文案、音效、App Icon
LifeLedgerTests/             账本、备份、加密、Android ZIP、安全路径等测试
LifeLedgerUITests/           原生导航、成就、笔记、图鉴和 iCloud 保存面板测试
scripts/generate_project.py  可选的工程再生成工具（仅需 Python 3）
```

数据位于应用私有 `Library/Application Support/LifeLedger/`，媒体使用相对路径，换设备后仍能恢复。本地文件无法解码时会显示恢复入口，不会自动清空。调试 UI 测试使用独立 `LifeLedger-UITests/` 目录，避免影响用户账本。

## 命令行验证

```bash
xcodebuild -project ios/LifeLedger.xcodeproj -scheme LifeLedger \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath ios/.build build

xcodebuild -project ios/LifeLedger.xcodeproj -scheme LifeLedger \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath ios/.build -parallel-testing-enabled NO test
```

请把模拟器名称换成自己安装的设备。不要禁用模拟器签名：Keychain 和本地加密测试需要系统正常签名。

## 许可证与来源

遵循仓库根目录 [MIT License](../LICENSE)，© 2026 mrlingan。109 条预设及中英文文案复用本仓库资源；成就内容来源为 [EarthOnline-Achievement](https://github.com/LKlingkong/EarthOnline-Achievement)。本目录不引入 Android 的 AGSL 玻璃实现或第三方库。
