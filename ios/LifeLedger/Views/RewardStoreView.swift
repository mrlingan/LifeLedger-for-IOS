import SwiftUI

struct RewardStoreView: View {
    @EnvironmentObject var store: LedgerStore
    @State private var adding = false
    @State private var history = false
    @State private var chosen: Reward?
    @State private var editing: Reward?
    @State private var category = ""
    var body: some View {
        List {
            Section {
                LabeledContent(store.t("可用积分", "Available XP"), value: "\(store.balance) XP")
                Button(store.t("我的奖励", "My rewards"), systemImage: "gift") { history = true }
            }
            Section {
                Picker(store.t("分类", "Category"), selection: $category) {
                    Text(store.t("全部", "All")).tag("")
                    ForEach(Array(Set(store.data.rewards.map(\.category))).sorted(), id: \.self) { Text(store.category($0)).tag($0) }
                }
            }
            Section(store.t("奖励目录", "Rewards")) {
                ForEach(store.data.rewards.filter { category.isEmpty || $0.category == category }.sorted { $0.price < $1.price }) { reward in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            IconTile(icon: reward.icon)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.rewardTitle(reward)).font(.headline)
                                Text(store.category(reward.category)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Menu {
                                if reward.catalogIndex == nil { Button(store.t("编辑", "Edit")) { editing = reward } }
                                Button(store.t("删除", "Delete"), role: .destructive) { store.change { $0.rewards.removeAll { $0.id == reward.id } } }
                            } label: { Image(systemName: "ellipsis") }.buttonStyle(.borderless)
                        }
                        HStack {
                            Text("\(reward.price) XP").monospacedDigit()
                            Spacer()
                            Button(store.t("兑换", "Redeem")) { chosen = reward }.buttonStyle(.bordered).disabled(store.balance < reward.price)
                        }
                    }
                }
            }
        }.navigationTitle(store.t("积分商城", "Reward store"))
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $adding) { NavigationStack { RewardEditor() } }
            .sheet(item: $editing) { reward in NavigationStack { RewardEditor(reward: reward) } }
            .sheet(isPresented: $history) { NavigationStack { MyRewardsView() } }
            .alert(store.t("兑换这份奖励？", "Redeem this reward?"), isPresented: Binding(get: { chosen != nil }, set: { if !$0 { chosen = nil } })) {
                if let reward = chosen { Button(store.t("确认兑换", "Redeem")) { store.redeem(reward); chosen = nil } }
                Button(store.t("取消", "Cancel"), role: .cancel) { chosen = nil }
            } message: { if let reward = chosen { Text(store.rewardTitle(reward) + " · \(reward.price) XP") } }
    }
}
struct RewardEditor: View {
    @EnvironmentObject var store: LedgerStore
    @Environment(\.dismiss) var dismiss
    @State private var reward: Reward
    init(reward: Reward? = nil) { _reward = State(initialValue: reward ?? Reward(title: "", icon: "🎁", category: "生活", price: 100)) }
    var body: some View {
        Form {
            TextField(store.t("名称", "Title"), text: $reward.title)
            TextField(store.t("图标", "Icon"), text: $reward.icon)
            TextField(store.t("分类", "Category"), text: $reward.category)
            TextField(store.t("描述", "Description"), text: $reward.detail, axis: .vertical)
            TextField(store.t("价格（XP）", "Price (XP)"), value: $reward.price, format: .number).keyboardType(.numberPad)
        }.navigationTitle(store.t("奖励", "Reward")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(store.t("取消", "Cancel")) { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(store.t("保存", "Save")) { if store.change({ state in if let i = state.rewards.firstIndex(where: { $0.id == reward.id }) { state.rewards[i] = reward } else { state.rewards.append(reward) } }) { dismiss() } }.disabled(reward.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !(1...1_000_000).contains(reward.price)) } }
    }
}
struct MyRewardsView: View {
    @EnvironmentObject var store: LedgerStore
    @Environment(\.dismiss) var dismiss
    @State private var refund: Redemption?
    var body: some View {
        List {
            if store.data.redemptions.isEmpty { Text(store.t("还没有兑换记录", "No rewards redeemed yet")).foregroundStyle(.secondary) }
            ForEach(store.data.redemptions.sorted { $0.createdAt > $1.createdAt }) { item in
                HStack {
                    Text(item.icon).font(.title)
                    VStack(alignment: .leading, spacing: 5) { Text(item.title); Text("\(item.price) XP · " + store.date(item.createdAt, full: true)).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    if item.refundedAt == nil { Button(store.t("撤销", "Refund")) { refund = item }.font(.caption).buttonStyle(.bordered) }
                    else { Text(store.t("已退还", "Refunded")).font(.caption).foregroundStyle(.secondary) }
                }
            }
        }.navigationTitle(store.t("我的奖励", "My rewards"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.t("完成", "Done")) { dismiss() } } }
            .alert(store.t("撤销这次兑换？", "Refund this redemption?"), isPresented: Binding(get: { refund != nil }, set: { if !$0 { refund = nil } })) {
                if let item = refund { Button(store.t("退还积分", "Refund XP")) { store.refund(item.id); refund = nil } }
                Button(store.t("取消", "Cancel"), role: .cancel) { refund = nil }
            }
    }
}
