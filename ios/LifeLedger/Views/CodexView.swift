import SwiftUI

struct CodexView: View {
    @EnvironmentObject var store: LedgerStore
    @State private var query = ""
    @State private var category = ""
    @State private var filter = 0
    var narrowed: Bool { !query.isEmpty || !category.isEmpty || filter != 0 }
    var results: [Preset] {
        Catalog.presets.filter { preset in
            let unlocked = store.stats.unlocked.contains(preset.id)
            return (category.isEmpty || category == preset.category) && (filter == 0 || (filter == 1 ? unlocked : !unlocked)) &&
                (query.isEmpty || store.presetText(preset, "t").localizedCaseInsensitiveContains(query) || store.presetText(preset, "d").localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        List {
            if !narrowed {
                Section(store.t("收集进度", "Collection progress")) {
                    LabeledContent(store.t("图鉴已解锁", "Codex unlocked"), value: "\(store.stats.unlocked.count) / 109")
                    ProgressView(value: Double(store.stats.unlocked.count), total: 109)
                    Text(store.t("每一次解锁，都是你走过的路。", "Every unlock is a path you've walked.")).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Section(store.t("筛选", "Filters")) {
                Picker(store.t("分类", "Category"), selection: $category) {
                    Text(store.t("全部分类", "All categories")).tag("")
                    ForEach(Catalog.categories, id: \.self) { Text(store.category($0)).tag($0) }
                }
                Picker(store.t("图鉴状态", "Codex status"), selection: $filter) {
                    Text(store.t("全部", "All")).tag(0); Text(store.t("已解锁", "Unlocked")).tag(1); Text(store.t("未解锁", "Locked")).tag(2)
                }.pickerStyle(.segmented)
            }
            if !narrowed {
                Section(store.t("稀有度收藏", "Rarity collection")) {
                    ForEach(Rarity.allCases, id: \.rawValue) { tier in
                        let items = Catalog.presets.filter { $0.tier == tier }
                        let count = items.filter { store.stats.unlocked.contains($0.id) }.count
                        LabeledContent(store.t(tier.zh, tier.en), value: "\(count) / \(items.count)").foregroundStyle(tier.color)
                    }
                }
            }
            Section(store.t("经历索引 · \(results.count) 条", "Life index · \(results.count) entries")) {
                if results.isEmpty { EmptyState(symbol: "magnifyingglass", title: store.t("没有找到成就", "No achievements found"), detail: store.t("试试其他关键词或分类。", "Try another keyword or category.")) }
                ForEach(results) { preset in
                    NavigationLink { PresetDetailView(preset: preset) } label: { PresetRow(preset: preset) }
                }
            }
        }.listStyle(.insetGrouped).modifier(LedgerListBackground()).navigationTitle(store.t("成就图鉴", "Achievement codex"))
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: store.t("搜索 109 条成就", "Search 109 achievements"))
    }
}
struct PresetRow: View {
    @EnvironmentObject var store: LedgerStore
    let preset: Preset
    var body: some View {
        let unlocked = store.stats.unlocked.contains(preset.id)
        HStack(alignment: .top, spacing: 12) {
            IconTile(icon: preset.icon)
            VStack(alignment: .leading, spacing: 6) {
                Text(store.presetText(preset, "t")).font(.headline)
                Text(store.presetText(preset, "d")).font(.subheadline).foregroundStyle(.secondary)
                Text(store.t(preset.tier.zh, preset.tier.en)).font(.caption).foregroundStyle(preset.tier.color)
            }
            Spacer(minLength: 0)
            if unlocked { Image(systemName: "checkmark.seal.fill").foregroundStyle(.tint) }
        }.accessibilityElement(children: .combine)
    }
}
struct PresetDetailView: View {
    @EnvironmentObject var store: LedgerStore
    let preset: Preset
    @State private var adding = false
    var body: some View {
        List {
            Section {
                HStack { IconTile(icon: preset.icon, size: 64); Text(store.presetText(preset, "d")) }
                LabeledContent(store.t("分类", "Category"), value: store.category(preset.category))
                LabeledContent(store.t("稀有度", "Rarity"), value: store.t(preset.tier.zh, preset.tier.en))
                LabeledContent(store.t("达成率", "Achievement rate"), value: String(format: "%g%%", preset.rate))
                if let record = store.record(for: preset) {
                    NavigationLink(store.t(record.isCompleted ? "查看我的成就" : "已加入 · 继续记录", record.isCompleted ? "View my achievement" : "Added · Continue recording")) { AchievementDetailView(id: record.id) }
                } else { Button(store.t("加入我的成就", "Add to my achievements"), systemImage: "plus") { adding = true } }
            }
            Section(store.t("成就故事", "The story")) { Text(store.presetText(preset, "s")) }
        }.navigationTitle(store.presetText(preset, "t")).navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $adding) { NavigationStack { AchievementEditor(preset: preset) } }
    }
}
