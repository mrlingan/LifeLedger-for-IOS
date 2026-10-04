import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: LedgerStore
    @Binding var tab: LedgerTab
    @Binding var adding: Bool
    var body: some View {
        List {
            Section {
                Text(store.date(Date())).foregroundStyle(.secondary)
                Text(store.t("每一个小小的坚持，都在构建更好的你。", "Every small step builds a better you.")).font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(store.data.preferences.homeOrder.filter { store.data.preferences.homeEnabled.contains($0) }) { section in
                switch section {
                case .progress: ProfileProgressSection()
                case .shortcuts:
                    Section(store.t("快捷入口", "Shortcuts")) {
                        Button(store.t("写记录", "Record"), systemImage: "square.and.pencil") { adding = true }
                        SettingsLink(store.t("目标", "Goals"), symbol: "target") { GoalsView() }
                        Button(store.t("成就图鉴", "Achievement codex"), systemImage: "safari") { tab = .codex }
                        SettingsLink(store.t("全部成就", "All achievements"), symbol: "list.bullet") { AchievementsView() }
                    }
                case .statistics:
                    Section(store.t("核心数据", "Your journey")) {
                        Metric(value: "\(store.stats.completed.count)", label: store.t("已完成", "Completed"))
                        Metric(value: "\(store.data.achievements.count - store.stats.completed.count)", label: store.t("进行中", "In progress"))
                        Metric(value: "\(store.data.achievements.count)", label: store.t("总记录", "Records"))
                        Metric(value: "\(store.stats.recordedDays)", label: store.t("坚持天数", "Active days"))
                    }
                case .categories:
                    Section(store.t("分类进度", "Collections")) {
                        Metric(value: "\(store.stats.unlocked.count) / 109", label: store.t("图鉴已解锁", "Codex unlocked"))
                        ForEach(Array(store.categories.prefix(5)), id: \.self) { category in
                            let presets = Catalog.presets.filter { $0.category == category }
                            let count = presets.filter { store.stats.unlocked.contains($0.id) }.count
                            VStack(alignment: .leading, spacing: 8) {
                                LabeledContent(store.category(category), value: "\(count) / \(presets.count)")
                                ProgressView(value: Double(count), total: Double(max(1, presets.count))).tint(Color.category(category))
                            }
                        }
                        Button(store.t("查看全部分类", "View all categories")) { tab = .codex }
                    }
                case .recent:
                    Section(store.t("最近解锁", "Recent unlocks")) {
                        if store.stats.completed.isEmpty { Text(store.t("下一个值得纪念的瞬间，等你来记录。", "Your next memorable moment is waiting.")).foregroundStyle(.secondary) }
                        ForEach(Array(store.stats.completed.sorted { $0.completedAt! > $1.completedAt! }.prefix(3))) { item in
                            NavigationLink { AchievementDetailView(id: item.id) } label: { AchievementRow(item: item, showToggle: false) }
                        }
                    }
                case .start:
                    Section(store.t("记录起点", "Your beginning")) { Text(store.date(store.data.startedAt, full: true)) }
                case .image:
                    if let path = store.data.preferences.homeImage, let image = UIImage(contentsOfFile: store.mediaURL(path).path) {
                        Section { Image(uiImage: image).resizable().scaledToFit() }
                    }
                }
            }
            if store.data.preferences.homeEnabled.isEmpty { Section { NavigationLink(store.t("定制首页板块", "Customize home")) { HomeLayoutView() } } }
        }.listStyle(.insetGrouped).modifier(LedgerListBackground())
            .navigationTitle(store.t("你好，", "Hello, ") + store.name)
            .toolbar {
                RecordToolbar(adding: $adding)
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }.accessibilityLabel(store.t("设置", "Settings")).accessibilityIdentifier("settings")
                }
            }
    }
}
struct ProfileProgressSection: View {
    @EnvironmentObject var store: LedgerStore
    var body: some View {
        Section(store.t("人生进度", "Life progress")) {
            NavigationLink { ProfileEditor() } label: {
                HStack(spacing: 12) { Avatar(); VStack(alignment: .leading, spacing: 4) { Text(store.name).font(.headline); Text("Lv.\(store.stats.level)").font(.subheadline).foregroundStyle(.secondary) } }
            }
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent(store.t("已完成", "Completed"), value: "\(store.stats.completed.count) / \(store.data.achievements.count)")
                ProgressView(value: store.stats.progress)
                Text(store.t("距离下一阶段还有 \(store.stats.toNext) 条", "\(store.stats.toNext) achievements to your next level")).font(.caption).foregroundStyle(.secondary)
            }
            if !store.data.profile.signature.isEmpty { Text(store.data.profile.signature).foregroundStyle(.secondary) }
        }
    }
}
