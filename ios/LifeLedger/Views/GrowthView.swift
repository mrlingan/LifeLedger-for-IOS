import SwiftUI
import Charts

struct CurvePoint: Identifiable { var date: Date; var amount: Int; var id: Date { date } }
struct GrowthView: View {
    @EnvironmentObject var store: LedgerStore
    @State private var period = 30
    var curve: [CurvePoint] {
        let calendar = Calendar.current, today = calendar.startOfDay(for: Date())
        let first = store.data.points.map(\.createdAt).min() ?? today
        let start = period == 0 ? calendar.startOfDay(for: min(first, today)) : calendar.date(byAdding: .day, value: -(period - 1), to: today)!
        var balance = store.data.points.filter { $0.createdAt < start }.reduce(0) { $0 + $1.amount }
        let daily = Dictionary(grouping: store.data.points.filter { $0.createdAt >= start }, by: { calendar.startOfDay(for: $0.createdAt) })
        var result: [CurvePoint] = [], cursor = start
        while cursor <= today {
            balance += daily[cursor, default: []].reduce(0) { $0 + $1.amount }
            result.append(CurvePoint(date: cursor, amount: balance))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
            if result.count > 36_600 { break }
        }
        return result
    }
    var body: some View {
        List {
            Section(store.t("人生阶段", "Life stage")) {
                LabeledContent(store.t("阶段", "Level"), value: "Lv.\(store.stats.level)")
                LabeledContent(store.t("本阶段成就", "Achievements this level"), value: "\(store.stats.step) / 5")
                ProgressView(value: Double(store.stats.step), total: 5)
                LabeledContent(store.t("当前积分", "Current XP"), value: "\(store.balance) XP")
                SettingsLink(store.t("积分商城", "Reward store"), symbol: "gift") { RewardStoreView() }
            }
            Section(store.t("人生曲线", "Your life curve")) {
                Picker(store.t("时间范围", "Time range"), selection: $period) {
                    Text(store.t("7 天", "7D")).tag(7); Text(store.t("30 天", "30D")).tag(30); Text(store.t("90 天", "90D")).tag(90); Text(store.t("全部", "All")).tag(0)
                }.pickerStyle(.segmented)
                Chart(curve) { point in
                    AreaMark(x: .value("Date", point.date), y: .value("XP", point.amount)).foregroundStyle(Color.accentColor.opacity(0.1))
                    LineMark(x: .value("Date", point.date), y: .value("XP", point.amount)).foregroundStyle(Color.accentColor)
                }.frame(height: 180).chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
                    .accessibilityLabel(store.t("积分余额变化曲线", "XP balance over time"))
                Metric(value: delta(.day), label: store.t("今日", "Today"))
                Metric(value: delta(.weekOfYear), label: store.t("本周", "This week"))
                Metric(value: delta(.month), label: store.t("本月", "This month"))
            }
            Section(store.t("人生属性", "Life attributes")) {
                ForEach(store.categories, id: \.self) { category in
                    let xp = store.stats.completed.filter { $0.category == category }.count * 50
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent(store.category(category), value: "Lv.\(1 + xp / 200) · \(xp % 200) / 200 XP")
                        ProgressView(value: Double(xp % 200), total: 200).tint(Color.category(category))
                    }
                }
            }
            Section { SettingsLink(store.t("长期目标与每日任务", "Goals & daily tasks"), symbol: "target") { GoalsView() } }
            Section(store.t("成长记录", "Growth ledger")) {
                if store.data.points.isEmpty { Text(store.t("完成成就或任务后，这里会留下成长的足迹。", "Complete achievements or tasks to start your ledger.")).foregroundStyle(.secondary) }
                ForEach(Array(store.data.points.sorted { $0.createdAt > $1.createdAt }.prefix(15))) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entryTitle(entry)).font(.body)
                            Text(kind(entry.kind) + " · " + store.date(entry.createdAt, full: true)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(entry.amount >= 0 ? "+" : "")\(entry.amount) XP").monospacedDigit().foregroundStyle(entry.amount >= 0 ? Color.accentColor : .secondary)
                    }
                }
            }
            Section(store.t("每日一言", "A thought for today")) {
                Text(store.t("人生没有白走的路，每一步都算数。", "No step is wasted. Every step counts."))
            }
        }.listStyle(.insetGrouped).modifier(LedgerListBackground()).navigationTitle(store.t("我的成长", "My growth"))
    }
    func delta(_ component: Calendar.Component) -> String {
        let start = Calendar.current.dateInterval(of: component, for: Date())!.start
        let value = store.data.points.filter { $0.createdAt >= start }.reduce(0) { $0 + $1.amount }
        return "\(value >= 0 ? "+" : "")\(value)"
    }
    func entryTitle(_ entry: PointEntry) -> String {
        if let item = store.data.achievements.first(where: { $0.id == entry.sourceID }) { return store.title(item) }
        return entry.title
    }
    func kind(_ kind: String) -> String {
        switch kind { case "achievement": return store.t("完成成就", "Achievement"); case "achievement_reversal": return store.t("取消完成", "Reversal"); case "daily_task": return store.t("每日任务", "Daily task"); case "reward_redeem": return store.t("兑换奖励", "Reward"); default: return store.t("退还积分", "Refund") }
    }
}
