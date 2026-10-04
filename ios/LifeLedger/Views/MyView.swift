import SwiftUI

struct MyView: View {
    @EnvironmentObject var store: LedgerStore
    @Binding var tab: LedgerTab
    var body: some View {
        List {
            ProfileProgressSection()
            Section(store.t("我的档案", "My story")) {
                Metric(value: "\(store.data.achievements.count)", label: store.t("总记录", "Records"))
                Metric(value: "\(store.stats.completed.count)", label: store.t("已完成", "Completed"))
                Metric(value: "\(store.stats.unlocked.count)", label: store.t("图鉴解锁", "Unlocked"))
                Metric(value: "\(store.stats.streak())", label: store.t("连续记录", "Streak"))
            }
            Section(store.t("我的人生", "My life")) {
                Metric(value: "\(max(1, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: store.data.startedAt), to: Calendar.current.startOfDay(for: Date())).day! + 1))", label: store.t("记录天数", "Days"))
                Metric(value: "\(store.data.notes.count)", label: store.t("笔记", "Notes"))
                Metric(value: "\(store.data.notes.flatMap(\.attachments).count)", label: store.t("图片 · 视频", "Media"))
            }
            Section(store.t("我的收藏", "My collections")) {
                SettingsLink(store.t("全部成就", "All achievements"), symbol: "list.bullet") { AchievementsView() }
                Button(store.t("成就图鉴", "Achievement codex"), systemImage: "safari") { tab = .codex }
                Button(store.t("我的成长", "My growth"), systemImage: "star") { tab = .growth }
                SettingsLink(store.t("积分商城", "Reward store"), symbol: "gift") { RewardStoreView() }
            }
            Section(store.t("设置", "Settings")) {
                SettingsLink(store.t("个人资料", "Profile"), symbol: "person.crop.circle") { ProfileEditor() }
                SettingsLink(store.t("提醒设置", "Reminders"), symbol: "bell") { ReminderView() }
                SettingsLink(store.t("备份与恢复", "Backup & restore"), symbol: "externaldrive") { BackupView() }
                SettingsLink(store.t("全部设置", "All settings"), symbol: "gearshape") { SettingsView() }
            }
        }.listStyle(.insetGrouped).modifier(LedgerListBackground()).navigationTitle(store.t("我的档案", "My story"))
    }
}
struct ProfileEditor: View {
    @EnvironmentObject var store: LedgerStore
    @Environment(\.dismiss) var dismiss
    @State private var profile = Profile()
    @State private var loaded = false
    @State private var picker = false
    @State private var added: [Attachment] = []
    @State private var saved = false
    var body: some View {
        Form {
            Section(store.t("个人资料", "Profile")) {
                HStack { IconTile(icon: profile.avatar, size: 62); TextField(store.t("昵称", "Nickname"), text: $profile.nickname) }
                TextField(store.t("个人签名", "Signature"), text: $profile.signature, axis: .vertical)
                Picker(store.t("性别", "Gender"), selection: $profile.gender) { Text(store.t("未设置", "Not set")).tag(""); Text(store.t("女", "Female")).tag("female"); Text(store.t("男", "Male")).tag("male"); Text(store.t("其他", "Other")).tag("other") }
                Picker("MBTI", selection: $profile.mbti) { Text(store.t("未设置", "Not set")).tag(""); ForEach(["INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"], id: \.self) { Text($0).tag($0) } }
            }
            Section(store.t("头像", "Avatar")) {
                Picker(store.t("内置头像", "Built-in avatar"), selection: $profile.avatar) {
                    if profile.avatar.hasPrefix("media/") { Text(store.t("自定义照片", "Custom photo")).tag(profile.avatar) }
                    ForEach(["🌄", "🌊", "⛰️", "🍃", "🌙", "☁️", "✨", "🌸"], id: \.self) { Text($0).tag($0) }
                }
                Button(store.t("从照片选择", "Choose a photo")) { picker = true }
            }
        }.navigationTitle(store.t("个人资料", "Profile")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.t("保存", "Save")) { if store.change({ $0.profile = profile }) { saved = true; dismiss() } } } }
            .onAppear { if !loaded { profile = store.data.profile; loaded = true } }
            .sheet(isPresented: $picker) { MediaPicker(imagesOnly: true) { items in added += items; if let path = items.first?.path { profile.avatar = path } } }
            .onDisappear { store.removeMedia(added.filter { !saved || $0.path != profile.avatar }) }
    }
}
