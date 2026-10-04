import SwiftUI

struct GoalsView: View {
    @EnvironmentObject var store: LedgerStore
    @State private var adding = false
    var body: some View {
        List {
            if store.data.goals.isEmpty { EmptyState(symbol: "target", title: store.t("把远方拆成每天的一小步", "Turn a goal into small daily steps"), detail: store.t("创建目标，为它安排任务，完成后获得积分。", "Create a goal, plan tasks, and earn XP as you complete them.")) }
            ForEach(store.data.goals.sorted { $0.start > $1.start }) { goal in
                let tasks = store.data.tasks.filter { $0.goalID == goal.id }
                let completed = tasks.filter { $0.completedAt != nil }.count
                Section {
                    NavigationLink { GoalDetailView(id: goal.id) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Text(goal.title).font(.headline); Spacer(); Pill(text: store.t(goal.paused ? "已暂停" : (!tasks.isEmpty && completed == tasks.count) ? "已完成" : goal.due < Date() ? "已逾期" : "进行中", goal.paused ? "Paused" : (!tasks.isEmpty && completed == tasks.count) ? "Completed" : goal.due < Date() ? "Overdue" : "Active")) }
                            Text(store.t("截止 ", "Due ") + store.date(goal.due, full: true)).font(.caption).foregroundStyle(.secondary)
                            ProgressView(value: Double(completed), total: Double(max(1, tasks.count)))
                            Text(store.t("\(completed) / \(tasks.count) 个任务", "\(completed) / \(tasks.count) tasks")).font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.automatic)
                }
            }
        }.navigationTitle(store.t("长期目标", "Long term goals"))
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $adding) { NavigationStack { GoalEditor() } }
    }
}
struct GoalEditor: View {
    @EnvironmentObject var store: LedgerStore
    @Environment(\.dismiss) var dismiss
    @State private var goal: Goal
    init(goal: Goal? = nil) { _goal = State(initialValue: goal ?? Goal(title: "", due: Calendar.current.date(byAdding: .month, value: 1, to: Date())!)) }
    var body: some View {
        Form {
            TextField(store.t("目标名称", "Goal title"), text: $goal.title)
            TextField(store.t("描述", "Description"), text: $goal.detail, axis: .vertical)
            DatePicker(store.t("开始日期", "Start date"), selection: $goal.start, displayedComponents: .date)
            DatePicker(store.t("截止日期", "Due date"), selection: $goal.due, in: goal.start..., displayedComponents: .date)
            Toggle(store.t("暂停目标", "Pause goal"), isOn: $goal.paused)
        }.navigationTitle(store.t("目标", "Goal")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(store.t("取消", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(store.t("保存", "Save")) {
                    goal.title = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    if store.change({ state in
                        if let i = state.goals.firstIndex(where: { $0.id == goal.id }) { state.goals[i] = goal } else { state.goals.append(goal) }
                    }) { dismiss() }
                }.disabled(goal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || goal.due < goal.start) }
            }
    }
}
struct GoalDetailView: View {
    @EnvironmentObject var store: LedgerStore
    @Environment(\.dismiss) var dismiss
    let id: UUID
    @State private var adding = false
    @State private var editing = false
    @State private var deleting = false
    var goal: Goal? { store.data.goals.first { $0.id == id } }
    var body: some View {
        List {
            if let goal {
                Section { Text(goal.title).font(.headline); if !goal.detail.isEmpty { Text(goal.detail).foregroundStyle(.secondary) } }
                Section { HStack { Text(store.t("截止日期", "Due date")); Spacer(); Text(store.date(goal.due, full: true)).foregroundStyle(.secondary) } }
                HStack { SectionTitle(title: store.t("每日任务", "Daily tasks")); Spacer(); Button { adding = true } label: { Image(systemName: "plus.circle") } }
                ForEach(store.data.tasks.filter { $0.goalID == id }.sorted { $0.scheduledAt < $1.scheduledAt }) { task in
                    Section {
                        HStack {
                            Button { store.completeTask(task.id) } label: { Image(systemName: task.completedAt == nil ? "circle" : "checkmark.circle.fill").font(.title2) }.buttonStyle(.borderless).disabled(task.completedAt != nil || goal.paused)
                            VStack(alignment: .leading, spacing: 5) { Text(task.title).font(.subheadline.weight(.medium)); Text(store.date(task.scheduledAt, full: true)).font(.caption).foregroundStyle(.secondary) }
                            Spacer(); Pill(text: "+\(task.reward) XP")
                            if task.completedAt == nil { Button(role: .destructive) { store.change { $0.tasks.removeAll { $0.id == task.id } } } label: { Image(systemName: "trash") }.buttonStyle(.borderless) }
                        }
                    }
                }
                if store.data.tasks.filter({ $0.goalID == id }).isEmpty { EmptyState(title: store.t("安排第一步", "Plan the first step"), detail: store.t("点击 + 添加任务。", "Tap + to add a task.")) }
            }
        }.navigationTitle(store.t("目标详情", "Goal details")).navigationBarTitleDisplayMode(.inline)
            .toolbar { Menu { Button(store.t("编辑目标", "Edit goal")) { editing = true }; Button(store.t("删除目标", "Delete goal"), role: .destructive) { deleting = true } } label: { Image(systemName: "ellipsis.circle") } }
            .sheet(isPresented: $adding) { NavigationStack { TaskEditor(goalID: id) } }
            .sheet(isPresented: $editing) { if let goal { NavigationStack { GoalEditor(goal: goal) } } }
            .alert(store.t("删除目标和任务？", "Delete goal and tasks?"), isPresented: $deleting) {
                Button(store.t("删除", "Delete"), role: .destructive) { store.change { $0.goals.removeAll { $0.id == id }; $0.tasks.removeAll { $0.goalID == id } }; dismiss() }
                Button(store.t("取消", "Cancel"), role: .cancel) { }
            } message: { Text(store.t("已获得的积分流水会保留。", "XP entries already earned will remain.")) }
    }
}
struct TaskEditor: View {
    @EnvironmentObject var store: LedgerStore
    @Environment(\.dismiss) var dismiss
    let goalID: UUID
    @State private var title = ""
    @State private var date = Date()
    @State private var reward = 10
    var body: some View {
        Form { TextField(store.t("任务名称", "Task title"), text: $title); DatePicker(store.t("计划日期", "Scheduled date"), selection: $date, displayedComponents: .date); Stepper(store.t("奖励 \(reward) XP", "Reward \(reward) XP"), value: $reward, in: 0...10000, step: 10) }
            .navigationTitle(store.t("添加任务", "Add task")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(store.t("取消", "Cancel")) { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(store.t("保存", "Save")) { if store.change({ $0.tasks.append(GoalTask(goalID: goalID, title: title.trimmingCharacters(in: .whitespacesAndNewlines), scheduledAt: date, reward: reward)) }) { dismiss() } }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
    }
}
