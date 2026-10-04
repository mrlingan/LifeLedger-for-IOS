import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: LedgerStore
    func pref<T>(_ path: WritableKeyPath<Preferences, T>) -> Binding<T> {
        Binding(get: { store.data.preferences[keyPath: path] }, set: { value in store.change { $0.preferences[keyPath: path] = value } })
    }
    var body: some View {
        Form {
            Section(store.t("个人与记录", "Profile & records")) {
                SettingsLink(store.t("个人资料", "Profile"), symbol: "person.crop.circle") { ProfileEditor() }
                SettingsLink(store.t("首页板块", "Home layout"), symbol: "rectangle.3.group") { HomeLayoutView() }
                SettingsLink(store.t("成就偏好", "Achievement preferences"), symbol: "checkmark.seal") { AchievementPreferencesView() }
            }
            Section(store.t("外观与语言", "Appearance & language")) {
                Picker(store.t("主题", "Theme"), selection: pref(\.theme)) {
                    Text(store.t("跟随系统", "System")).tag("system"); Text(store.t("浅色", "Light")).tag("light"); Text(store.t("深色", "Dark")).tag("dark")
                }
                Picker(store.t("语言", "Language"), selection: pref(\.language)) {
                    Text(store.t("跟随系统", "System")).tag("system"); Text("简体中文").tag("zh"); Text("English").tag("en")
                }
                SettingsLink(store.t("背景图片", "Background image"), symbol: "photo") { BackgroundSettingsView() }
            }
            Section(store.t("通知与数据", "Notifications & data")) {
                SettingsLink(store.t("每日提醒", "Daily reminder"), symbol: "bell") { ReminderView() }
                SettingsLink(store.t("数据安全", "Data security"), symbol: "lock.shield") { SecurityView() }
                SettingsLink(store.t("备份与恢复", "Backup & restore"), symbol: "externaldrive") { BackupView() }
            }
            Section(store.t("完成反馈", "Completion feedback")) {
                Toggle(store.t("完成触感反馈", "Completion haptics"), isOn: pref(\.haptics))
                Toggle(store.t("完成音效", "Completion sound"), isOn: pref(\.sound))
            }
            Section(store.t("关于", "About")) {
                LabeledContent("LifeLedger for iOS", value: "1.0.0")
                Text(store.t("离线记录 · 无账号 · 无埋点", "Offline · No account · No tracking")).foregroundStyle(.secondary)
                Link(store.t("项目源码与 MIT 许可证", "Source code & MIT license"), destination: URL(string: "https://github.com/mrlingan/LifeLedger")!)
            }
        }.navigationTitle(store.t("设置", "Settings"))
    }
}
struct AchievementPreferencesView: View {
    @EnvironmentObject var store: LedgerStore
    var body: some View {
        Form {
            Section {
                TextField(store.t("默认图标（Emoji）", "Default icon (emoji)"), text: Binding(get: { store.data.preferences.defaultIcon }, set: { value in store.change { $0.preferences.defaultIcon = value } }))
                Toggle(store.t("标记完成前确认", "Confirm completion"), isOn: Binding(get: { store.data.preferences.confirmCompletion }, set: { value in store.change { $0.preferences.confirmCompletion = value } }))
            }
            Section(store.t("关注的分类", "Favorite categories")) { ForEach(store.categories, id: \.self) { category in
                Toggle(store.category(category), isOn: Binding(get: { store.data.preferences.favoriteCategories.contains(category) }, set: { value in store.change { state in state.preferences.favoriteCategories.removeAll { $0 == category }; if value { state.preferences.favoriteCategories.append(category) } } }))
            } }
        }.navigationTitle(store.t("成就偏好", "Achievement preferences")).navigationBarTitleDisplayMode(.inline)
    }
}
struct HomeLayoutView: View {
    @EnvironmentObject var store: LedgerStore
    @State private var imagePicker = false
    var body: some View {
        List {
            Section { ForEach(store.data.preferences.homeOrder) { section in
                Toggle(store.t(section.zh, section.en), isOn: Binding(get: { store.data.preferences.homeEnabled.contains(section) }, set: { enabled in store.change { state in state.preferences.homeEnabled.removeAll { $0 == section }; if enabled { state.preferences.homeEnabled.append(section) } } }))
            }.onMove { from, to in store.change { $0.preferences.homeOrder.move(fromOffsets: from, toOffset: to) } } } footer: { Text(store.t("拖动右侧把手排序，修改即时生效。", "Drag the handles to reorder. Changes apply immediately.")) }
            Section { Button(store.t("选择首页图片", "Choose home image")) { imagePicker = true }; Button(store.t("恢复默认布局", "Restore default layout")) { store.change { $0.preferences.homeOrder = HomeSection.allCases; $0.preferences.homeEnabled = [.progress, .shortcuts, .statistics, .categories] } } }
        }.environment(\.editMode, .constant(.active))
            .navigationTitle(store.t("首页板块", "Home layout")).navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $imagePicker) { MediaPicker(imagesOnly: true) { items in if let path = items.first?.path {
                if !store.change({ $0.preferences.homeImage = path; if !$0.preferences.homeEnabled.contains(.image) { $0.preferences.homeEnabled.append(.image) } }) { store.removeMedia(items) }
            } } }
    }
}
struct BackgroundSettingsView: View {
    @EnvironmentObject var store: LedgerStore
    @State private var picker = false
    var body: some View {
        Form {
            if let path = store.data.preferences.backgroundImage, let image = UIImage(contentsOfFile: store.mediaURL(path).path) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 260) }
            Button(store.t("选择背景图片", "Choose background image")) { picker = true }
            Slider(value: Binding(get: { store.data.preferences.backgroundOpacity }, set: { value in store.change { $0.preferences.backgroundOpacity = value } }), in: 0...1) { Text(store.t("显示强度", "Opacity")) }
            Button(store.t("移除背景", "Remove background"), role: .destructive) { store.change { $0.preferences.backgroundImage = nil } }
        }.navigationTitle(store.t("背景图片", "Background image")).navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $picker) { MediaPicker(imagesOnly: true) { items in if let path = items.first?.path { if !store.change({ $0.preferences.backgroundImage = path }) { store.removeMedia(items) } } } }
    }
}
struct ReminderView: View {
    @EnvironmentObject var store: LedgerStore
    @State private var date = Date()
    @State private var busy = false
    @State private var status = ""
    var body: some View {
        Form {
            Section {
                Toggle(store.t("每日提醒", "Daily reminder"), isOn: Binding(get: { store.data.preferences.reminder }, set: { value in save(enabled: value) })).disabled(busy)
                DatePicker(store.t("提醒时间", "Reminder time"), selection: $date, displayedComponents: .hourAndMinute).disabled(busy).onChange(of: date) { _, _ in if store.data.preferences.reminder { save(enabled: true) } }
            } footer: { Text(store.t("开启时才会申请通知权限。提醒由 iOS 在本机安排。", "Notification permission is requested only when enabled. iOS schedules reminders locally.")) }
            if !status.isEmpty { Text(status).foregroundStyle(.secondary) }
        }.navigationTitle(store.t("提醒设置", "Reminders")).navigationBarTitleDisplayMode(.inline)
            .onAppear { date = Calendar.current.date(bySettingHour: store.data.preferences.reminderHour, minute: store.data.preferences.reminderMinute, second: 0, of: Date())! }
    }
    func save(enabled: Bool) {
        busy = true
        let time = Calendar.current.dateComponents([.hour, .minute], from: date)
        Task {
            do {
                if enabled { try await ReminderService.schedule(hour: time.hour!, minute: time.minute!, zh: store.zh) }
                else { await ReminderService.cancel() }
                if !store.change({ $0.preferences.reminder = enabled; $0.preferences.reminderHour = time.hour!; $0.preferences.reminderMinute = time.minute! }) { await ReminderService.cancel() }
                status = enabled ? store.t("每日提醒已安排", "Daily reminder scheduled") : ""
            } catch { store.error = error.localizedDescription }
            busy = false
        }
    }
}
