import SwiftUI

enum LedgerTab: Int, CaseIterable { case home, codex, growth, profile }
struct RootView: View {
    @EnvironmentObject var store: LedgerStore
    @Environment(\.scenePhase) var phase
    @State private var selected: LedgerTab = .home
    @State private var adding = false
    @State private var locked = false
    var needsLock: Bool { store.data.preferences.biometricLock || ((try? LedgerSecurity.getSecret("app-pin")) != nil) }
    var body: some View {
        ZStack {
            LedgerBackground()
            if store.loadFailed {
                NavigationStack {
                    List {
                        EmptyState(symbol: "externaldrive.badge.exclamationmark", title: store.t("无法读取本地记录", "Unable to read local records"), detail: store.t("原文件已保留。可以从经过验证的备份恢复。", "Your original file is preserved. Restore a verified backup to continue."))
                        NavigationLink(store.t("备份与恢复", "Backup & restore")) { BackupView() }.buttonStyle(.borderedProminent)
                    }
                }
            } else if !store.data.onboarded { OnboardingView() }
            else {
                TabView(selection: $selected) {
                    NavigationStack { HomeView(tab: $selected, adding: $adding) }
                        .tabItem { Label(store.t("首页", "Home"), systemImage: "house") }.tag(LedgerTab.home)
                    NavigationStack { CodexView().toolbar { RecordToolbar(adding: $adding) } }
                        .tabItem { Label(store.t("图鉴", "Codex"), systemImage: "safari") }.tag(LedgerTab.codex)
                    NavigationStack { GrowthView().toolbar { RecordToolbar(adding: $adding) } }
                        .tabItem { Label(store.t("成长", "Growth"), systemImage: "star") }.tag(LedgerTab.growth)
                    NavigationStack { MyView(tab: $selected).toolbar { RecordToolbar(adding: $adding) } }
                        .tabItem { Label(store.t("我的", "Me"), systemImage: "person.crop.circle") }.tag(LedgerTab.profile)
                }
                .sheet(isPresented: $adding) { NavigationStack { AchievementEditor() } }
            }
            if needsLock && locked && !store.loadFailed { LockView { locked = false }.zIndex(2) }
            if phase == .inactive && needsLock {
                LedgerBackground().overlay(Image(systemName: "lock.shield").font(.system(size: 54)).foregroundStyle(Color.ledgerAccent)).zIndex(3)
            }
        }
        .onAppear { locked = needsLock }
        .onChange(of: phase) { _, value in if value == .background && needsLock { locked = true } }
        .alert(store.t("提示", "Notice"), isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button(store.t("知道了", "OK"), role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var store: LedgerStore
    var body: some View {
        List {
            Image(systemName: "book.closed.fill").font(.system(size: 58)).foregroundStyle(Color.ledgerAccent).frame(maxWidth: .infinity)
            VStack(spacing: 14) {
                Text(store.t("人生账本", "LifeLedger")).font(.largeTitle.weight(.bold))
                Text(store.t("每个人都是自己人生的主角。", "You are the main character of your life.")).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity)
            Section {
                Text(store.t("收藏你走过的每一步。所有记录只保存在这台设备，无需账号。", "Collect the steps you've taken. Your records stay on this device. No account required.")).foregroundStyle(.secondary)
                Button(store.t("从 109 条预设成就开始", "Start with 109 achievements"), systemImage: "sparkles") { store.onboarding(includePresets: true) }.accessibilityIdentifier("startPresets")
                Button(store.t("从空白开始，自己记录", "Start fresh, write my own")) { store.onboarding(includePresets: false) }.accessibilityIdentifier("startEmpty")
            } header: { Text(store.t("从哪里开始？", "Where will you begin?")) }
            footer: { Text(store.t("两种选择都可以随时浏览和解锁图鉴。", "The full codex is always available with either choice.")) }

        }
    }
}
