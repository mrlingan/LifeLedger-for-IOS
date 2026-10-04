import SwiftUI

struct SecurityView: View {
    @EnvironmentObject var store: LedgerStore
    @State private var hasPIN = false
    @State private var busy = false
    var body: some View {
        Form {
            Section {
                NavigationLink(store.t(hasPIN ? "修改应用密码" : "设置 6 位应用密码", hasPIN ? "Change app PIN" : "Set a 6-digit app PIN")) { PINSettingsView(removing: false) }
                if hasPIN { NavigationLink(store.t("关闭应用密码", "Remove app PIN")) { PINSettingsView(removing: true) } }
                Toggle(store.t("Face ID / Touch ID / 设备密码", "Face ID / Touch ID / device passcode"), isOn: Binding(get: { store.data.preferences.biometricLock }, set: { value in
                    busy = true
                    Task {
                        do { if try await LedgerSecurity.authenticate(reason: store.t("确认应用锁设置", "Confirm app lock settings")) { store.change { $0.preferences.biometricLock = value } } }
                        catch { store.error = error.localizedDescription }
                        busy = false
                    }
                })).disabled(busy)
            } header: { Text(store.t("应用锁", "App lock")) } footer: { Text(store.t("离开应用进入后台后重新上锁。应用密码保存在系统钥匙串，不包含在备份中。", "The app locks after entering the background. Your PIN stays in the system Keychain and is excluded from backups.")) }
            Section {
                Toggle(store.t("加密本地数据", "Encrypt local data"), isOn: Binding(get: { store.data.preferences.encryptLocalData }, set: { value in store.change { $0.preferences.encryptLocalData = value } }))
            } footer: { Text(store.t("使用 AES-256-GCM 加密结构化账本，密钥由系统钥匙串保管。照片和视频副本受 iOS 文件保护，不进行额外内容加密。", "AES-256-GCM encrypts the structured ledger with a Keychain-protected key. Media uses iOS file protection without additional content encryption.")) }
        }.navigationTitle(store.t("数据安全", "Data security")).navigationBarTitleDisplayMode(.inline)
            .onAppear { hasPIN = (try? LedgerSecurity.getSecret("app-pin")) != nil }
    }
}
struct PINEntry: View {
    @EnvironmentObject var store: LedgerStore
    let title: String
    let subtitle: String
    @Binding var pin: String
    var disabled = false
    var onComplete: (String) -> Void
    @FocusState private var focused: Bool
    var body: some View {
        Form {
            Section {
                Label(title, systemImage: "lock.shield").font(.headline)
                Text(subtitle).foregroundStyle(.secondary)
                SecureField(store.t("6 位应用密码", "6-digit app PIN"), text: $pin)
                    .keyboardType(.numberPad).textContentType(.password).focused($focused).disabled(disabled)
                    .onChange(of: pin) { _, value in
                        let digits = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
                        if digits != value { pin = digits; return }
                        if digits.count == 6 { onComplete(digits) }
                    }
            }
        }.onAppear { focused = true }
    }
}
struct PINSettingsView: View {
    @EnvironmentObject var store: LedgerStore
    @Environment(\.dismiss) var dismiss
    var removing: Bool
    @State private var pin = ""
    @State private var first = ""
    @State private var step = 0
    @State private var status = ""
    @State private var initialized = false
    var body: some View {
        PINEntry(title: store.t(step == 0 ? "输入当前密码" : step == 1 ? "设置新密码" : "再次输入新密码", step == 0 ? "Enter current PIN" : step == 1 ? "Set a new PIN" : "Confirm your new PIN"), subtitle: status.isEmpty ? store.t("使用 6 位数字", "Use six digits") : status, pin: $pin) { value in
            do {
                if step == 0 {
                    guard try LedgerSecurity.verifyPIN(value) else { pin = ""; status = store.t("密码不正确", "Incorrect PIN"); return }
                    if removing { try LedgerSecurity.deleteSecret("app-pin"); dismiss() }
                    else { step = 1; pin = ""; status = "" }
                } else if step == 1 { first = value; step = 2; pin = ""; status = "" }
                else if value == first { try LedgerSecurity.setPIN(value); dismiss() }
                else { step = 1; first = ""; pin = ""; status = store.t("两次密码不同，请重新设置", "PINs did not match. Try again.") }
            } catch { store.error = error.localizedDescription; pin = "" }
        }.navigationBarTitleDisplayMode(.inline)
            .onAppear { if !initialized { initialized = true; step = (try? LedgerSecurity.getSecret("app-pin")) == nil ? 1 : 0 } }
    }
}
struct LockView: View {
    @EnvironmentObject var store: LedgerStore
    var unlock: () -> Void
    @State private var pin = ""
    @State private var status = ""
    @State private var failures = 0
    @State private var blockedUntil: Date?
    @State private var authenticating = false
    @State private var autoPrompted = false
    var hasPIN: Bool { (try? LedgerSecurity.getSecret("app-pin")) != nil }
    var body: some View {
        VStack {
            Spacer()
            if hasPIN {
                PINEntry(title: store.t("解锁人生账本", "Unlock LifeLedger"), subtitle: status.isEmpty ? store.t("输入应用密码", "Enter your app PIN") : status, pin: $pin, disabled: authenticating) { value in
                    if let deadline = blockedUntil, deadline > Date() { pin = ""; status = store.t("请稍后再试", "Please try again shortly"); return }
                    do {
                        if try LedgerSecurity.verifyPIN(value) { pin = ""; unlock() }
                        else { failures += 1; pin = ""; status = store.t("密码不正确", "Incorrect PIN"); if failures >= 5 { blockedUntil = Date().addingTimeInterval(30); status = store.t("请等待 30 秒再试", "Wait 30 seconds before trying again") } }
                    } catch { status = error.localizedDescription; pin = "" }
                }
            } else { Image(systemName: "lock.shield").font(.system(size: 64)).foregroundStyle(Color.ledgerAccent); Text(store.t("人生账本已锁定", "LifeLedger is locked")).font(.title2.weight(.bold)).padding(); Text(status).font(.subheadline).foregroundStyle(.secondary) }
            if store.data.preferences.biometricLock { Button(store.t("使用 Face ID / 设备密码", "Use Face ID / device passcode")) { authenticate() }.buttonStyle(.borderedProminent).disabled(authenticating).padding() }
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background { LedgerBackground() }
            .task { if store.data.preferences.biometricLock && !autoPrompted { autoPrompted = true; authenticate() } }
    }
    func authenticate() {
        guard !authenticating else { return }
        authenticating = true
        Task { do { if try await LedgerSecurity.authenticate(reason: store.t("解锁你的人生账本", "Unlock your LifeLedger")) { unlock() } } catch { status = error.localizedDescription }; authenticating = false }
    }
}
