import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var store: LedgerStore
    @State private var search = ""
    @State private var filter = 0
    @State private var adding = false
    var results: [Achievement] {
        store.data.achievements.filter {
            (filter == 0 || (filter == 1 ? $0.isCompleted : !$0.isCompleted)) &&
            (search.isEmpty || store.title($0).localizedCaseInsensitiveContains(search) || store.detail($0).localizedCaseInsensitiveContains(search))
        }.sorted { $0.createdAt > $1.createdAt }
    }
    var body: some View {
        List {
            Picker(store.t("状态", "Status"), selection: $filter) {
                Text(store.t("全部", "All")).tag(0); Text(store.t("已完成", "Completed")).tag(1); Text(store.t("进行中", "In progress")).tag(2)
            }.pickerStyle(.segmented).padding(.bottom, 10)
            if results.isEmpty { EmptyState(title: store.t("每一步都值得记录", "Every step counts"), detail: store.t("点击右上角 +，写下自己的成就。", "Tap + to record an achievement of your own.")) }
            ForEach(results) { item in
                Section { NavigationLink { AchievementDetailView(id: item.id) } label: { AchievementRow(item: item) }}
            }
        }.navigationTitle(store.t("全部成就", "Achievements"))
            .searchable(text: $search, prompt: store.t("搜索成就", "Search achievements"))
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel(store.t("记录成就", "Record achievement")) }
            .sheet(isPresented: $adding) { NavigationStack { AchievementEditor() } }
    }
}
struct AchievementRow: View {
    @EnvironmentObject var store: LedgerStore
    let item: Achievement
    var showToggle = true
    @State private var completing = false
    var body: some View {
        HStack(spacing: 14) {
            IconTile(icon: item.icon)
            VStack(alignment: .leading, spacing: 6) {
                Text(store.title(item)).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(2)
                if !item.detail.isEmpty { Text(store.detail(item)).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                HStack {
                    Text(store.category(item.category)).font(.caption2).foregroundStyle(.secondary)
                    if let id = item.presetID, let preset = Catalog.presets.first(where: { $0.id == id }) { Pill(text: store.t(preset.tier.zh, preset.tier.en), color: preset.tier.color) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if showToggle {
                Button {
                    if item.isCompleted || store.data.preferences.confirmCompletion { completing = true }
                    else { store.complete(item.id) }
                } label: { Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(item.isCompleted ? Color.ledgerAccent : .secondary) }.buttonStyle(.borderless).accessibilityLabel(store.t(item.isCompleted ? "取消完成" : "标记完成", item.isCompleted ? "Undo completion" : "Mark completed"))
            }
        }.sheet(isPresented: $completing) { CompletionSheet(item: item) }
    }
}
struct CompletionSheet: View {
    @EnvironmentObject var store: LedgerStore
    @Environment(\.dismiss) var dismiss
    let item: Achievement
    @State private var date = Date()
    var body: some View {
        NavigationStack {
            Form {
                Section { Text(store.title(item)).font(.headline); Text(store.t(item.isCompleted ? "取消完成会在积分账本中记入 −50 XP。" : "完成后获得 50 XP。选择属于这个瞬间的日期。", item.isCompleted ? "Undoing completion records −50 XP in your ledger." : "Earn 50 XP. Choose the date of this moment.")).foregroundStyle(.secondary) }
                if !item.isCompleted { DatePicker(store.t("完成日期", "Completion date"), selection: $date, in: ...Date(), displayedComponents: .date) }
                Button(store.t(item.isCompleted ? "取消完成" : "确认完成", item.isCompleted ? "Undo completion" : "Confirm completion"), role: item.isCompleted ? .destructive : nil) {
                    store.complete(item.id, date: item.isCompleted ? nil : date); dismiss()
                }.accessibilityIdentifier("confirmCompletion")
            }.navigationTitle(store.t("记录这一刻", "Remember this moment")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(store.t("返回", "Cancel")) { dismiss() } } }
        }.presentationDetents([.medium])
    }
}
struct AchievementEditor: View {
    @EnvironmentObject var store: LedgerStore
    @Environment(\.dismiss) var dismiss
    @State private var item: Achievement
    @State private var picker = false
    @State private var completed = false
    @State private var date = Date()
    @State private var customIcon = false
    @State private var newMedia: [Attachment] = []
    @State private var saved = false
    let editing: Bool
    init(item: Achievement? = nil, preset: Preset? = nil) {
        editing = item != nil
        _item = State(initialValue: item ?? preset.map(LedgerStore.achievement) ?? Achievement(title: ""))
    }
    var body: some View {
        Form {
            if !editing {
                Section { Button { picker = true } label: { Label(store.t("从成就图鉴挑选", "Choose from the codex"), systemImage: "safari") } }
            }
            Section(store.t("成就", "Achievement")) {
                HStack { IconTile(icon: item.icon, size: 44); TextField(store.t("标题", "Title"), text: $item.title).accessibilityIdentifier("achievementTitle") }
                TextField(store.t("描述这个值得记住的瞬间", "Describe this memorable moment"), text: $item.detail, axis: .vertical).lineLimit(3...6)
                if item.presetID == nil {
                    TextField(store.t("图标（Emoji）", "Icon (emoji)"), text: $item.icon)
                    Button(store.t("使用自己的图片", "Use my own image")) { customIcon = true }
                    TextField(store.t("分类（也可以新建）", "Category (or create one)"), text: $item.category)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack { ForEach(store.categories, id: \.self) { category in Button(store.category(category)) { item.category = category }.buttonStyle(.bordered).font(.caption) } }
                    }
                }
            }
            if !editing {
                Section {
                    Toggle(store.t("已经完成", "Already completed"), isOn: $completed)
                    if completed { DatePicker(store.t("完成日期", "Completion date"), selection: $date, in: ...Date(), displayedComponents: .date) }
                }
            }
        }.navigationTitle(store.t(editing ? "编辑成就" : "记录成就", editing ? "Edit achievement" : "Record achievement")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(store.t("取消", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(store.t("保存", "Save")) {
                    item.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    if store.save(item) { if !editing && completed { store.complete(item.id, date: date) }; saved = true; dismiss() }
                }.disabled(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("saveAchievement") }
            }
            .sheet(isPresented: $picker) { NavigationStack { PresetPicker { preset in item = LedgerStore.achievement(preset); picker = false } } }
            .sheet(isPresented: $customIcon) { MediaPicker(imagesOnly: true) { result in
                newMedia += result
                if let path = result.first?.path { item.icon = path }
            } }
            .onAppear { if !editing && item.presetID == nil && item.title.isEmpty { item.icon = store.data.preferences.defaultIcon } }
            .onDisappear { store.removeMedia(newMedia.filter { !saved || $0.path != item.icon }) }
    }
}
struct PresetPicker: View {
    @EnvironmentObject var store: LedgerStore
    @Environment(\.dismiss) var dismiss
    var onSelect: (Preset) -> Void
    @State private var query = ""
    var body: some View {
        List(Catalog.presets.filter { store.record(for: $0) == nil && (query.isEmpty || store.presetText($0, "t").localizedCaseInsensitiveContains(query)) }) { preset in
            Button { onSelect(preset) } label: { HStack { Text(preset.icon); VStack(alignment: .leading) { Text(store.presetText(preset, "t")).foregroundStyle(.primary); Text(store.presetText(preset, "d")).font(.caption).foregroundStyle(.secondary) } } }
        }.navigationTitle(store.t("挑选成就", "Choose an achievement")).searchable(text: $query)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(store.t("取消", "Cancel")) { dismiss() } } }
    }
}
struct AchievementDetailView: View {
    @EnvironmentObject var store: LedgerStore
    @Environment(\.dismiss) var dismiss
    let id: UUID
    @State private var editing = false
    @State private var completing = false
    @State private var addingNote = false
    @State private var deleting = false
    @State private var date = Date()
    var item: Achievement? { store.data.achievements.first { $0.id == id } }
    var body: some View {
        Group {
            if let item {
                List {
                    Section {
                        VStack(spacing: 18) {
                            IconTile(icon: item.icon, size: 96)
                            Text(store.title(item)).font(.title.weight(.bold)).multilineTextAlignment(.center)
                            Text(store.detail(item)).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            HStack { Pill(text: store.category(item.category)); if let presetID = item.presetID, let preset = Catalog.presets.first(where: { $0.id == presetID }) { Pill(text: store.t(preset.tier.zh, preset.tier.en), color: preset.tier.color) } }
                            PrimaryButton(title: store.t(item.isCompleted ? "已完成 · 管理状态" : "标记完成 · +50 XP", item.isCompleted ? "Completed · Manage" : "Mark completed · +50 XP"), symbol: item.isCompleted ? "checkmark.circle.fill" : "checkmark.circle") { completing = true }
                        }.frame(maxWidth: .infinity)
                    }
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: store.t("时间线", "Timeline"))
                            Label(store.t("创建于 ", "Created ") + store.date(item.createdAt, full: true), systemImage: "circle")
                            if let completed = item.completedAt {
                                Label(store.t("解锁于 ", "Unlocked ") + store.date(completed, full: true), systemImage: "checkmark.circle.fill").foregroundStyle(Color.ledgerAccent)
                                DatePicker(store.t("调整完成日期", "Change completion date"), selection: Binding(get: { completed }, set: { store.complete(id, date: $0) }), in: ...Date(), displayedComponents: .date)
                            }
                        }.font(.subheadline)
                    }
                    if let presetID = item.presetID, let preset = Catalog.presets.first(where: { $0.id == presetID }) { Section { VStack(alignment: .leading, spacing: 12) { SectionTitle(title: store.t("成就故事", "The story")); Text(store.presetText(preset, "s")).font(.subheadline).foregroundStyle(.secondary).lineSpacing(5) } } }
                    HStack { SectionTitle(title: store.t("记事本", "Notebook")); Spacer(); Button { addingNote = true } label: { Label(store.t("写笔记", "Add note"), systemImage: "plus") }.font(.subheadline) }
                    if store.notes(for: id).isEmpty { Section { Text(store.t("写下当时的细节，让回忆有迹可循。", "Capture the details so your memories have a home.")).font(.subheadline).foregroundStyle(.secondary) } }
                    ForEach(store.notes(for: id)) { note in NoteSection(note: note) }
                }.sheet(isPresented: $editing) { NavigationStack { AchievementEditor(item: item) } }
                    .sheet(isPresented: $completing) { CompletionSheet(item: item) }
                    .sheet(isPresented: $addingNote) { NavigationStack { NoteEditor(achievementID: id) } }
            } else { ContentUnavailableView(store.t("成就已删除", "Achievement deleted"), systemImage: "tray") }
        }.navigationTitle(store.t("成就详情", "Achievement details")).navigationBarTitleDisplayMode(.inline)
            .toolbar { Menu {
                Button(store.t("编辑", "Edit"), systemImage: "pencil") { editing = true }
                Button(store.t("删除成就", "Delete achievement"), systemImage: "trash", role: .destructive) { deleting = true }
            } label: { Image(systemName: "ellipsis.circle") } }
            .alert(store.t("删除这条成就？", "Delete this achievement?"), isPresented: $deleting) {
                Button(store.t("删除", "Delete"), role: .destructive) { store.deleteAchievement(id); dismiss() }
                Button(store.t("取消", "Cancel"), role: .cancel) { }
            } message: { Text(store.t("相关笔记和媒体也会删除。", "Its notes and media will also be deleted.")) }
    }
}
