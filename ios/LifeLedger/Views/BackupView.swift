import SwiftUI
import UniformTypeIdentifiers

struct ShareFile: Identifiable { var url: URL; var id: URL { url } }
struct BackupView: View {
    @EnvironmentObject var store: LedgerStore
    @State private var password = ""
    @State private var confirmation = ""
    @State private var importer = false
    @State private var source: URL?
    @State private var importPassword = ""
    @State private var prepared: PreparedBackup?
    @State private var confirmRestore = false
    @State private var busy = false
    @State private var status = ""
    @State private var shared: ShareFile?
    @State private var lastExport: URL?
    @State private var cloudDocument: BackupDocument?
    @State private var cloudExporter = false
    var body: some View {
        Form {
            Section {
                SecureField(store.t("备份口令（留空为普通 ZIP）", "Backup password (optional)"), text: $password).textContentType(.newPassword)
                if !password.isEmpty { SecureField(store.t("再次输入口令", "Confirm password"), text: $confirmation) }
                Button { export(toCloud: false) } label: { Label(store.t("导出 ZIP 备份", "Export ZIP backup"), systemImage: "square.and.arrow.up") }.disabled(busy || store.loadFailed || (!password.isEmpty && password != confirmation)).accessibilityIdentifier("exportBackup")
                Button { export(toCloud: true) } label: {
                    Label(store.t("备份到 iCloud Drive", "Back up to iCloud Drive"), systemImage: "icloud.and.arrow.up")
                }.disabled(busy || store.loadFailed || (!password.isEmpty && password != confirmation)).accessibilityIdentifier("backupToICloud")
            } header: { Text(store.t("导出完整备份", "Export a full backup")) } footer: { VStack(alignment: .leading, spacing: 8) { Text(store.t("包含成就、笔记、原始媒体、个人资料、设置、积分流水、目标、任务和商城。应用密码和设备密钥不导出。", "Includes achievements, notes, original media, profile, settings, XP ledger, goals, tasks and rewards. App PINs and device keys are excluded.")); Text(store.t("备份到 iCloud Drive 时，在系统保存面板中选择 iCloud Drive 文件夹。保存后由 iCloud 同步；请先在系统设置中启用 iCloud Drive。", "To back up to iCloud Drive, choose an iCloud Drive folder in the system save dialog. iCloud syncs the saved file. Enable iCloud Drive in system Settings first.")) } }
            Section {
                Button { importer = true } label: { Label(store.t("选择备份文件", "Choose backup file"), systemImage: "square.and.arrow.down") }.disabled(busy)
                if let source {
                    Text(source.lastPathComponent).font(.caption).foregroundStyle(.secondary)
                    SecureField(store.t("如果备份已加密，输入口令", "Password for encrypted backup"), text: $importPassword)
                    Button(store.t("验证备份", "Verify backup")) { verify(source) }.disabled(busy)
                }
            } header: { Text(store.t("恢复备份", "Restore a backup")) } footer: { Text(store.t("可导入 iOS 备份或 Android ZIP / 加密备份。先验证内容，再确认覆盖。Android 备份不含成长和商城数据，将按已完成成就重建积分。", "Import iOS or Android ZIP / encrypted backups. Contents are verified before you confirm replacement. Android backups omit growth and rewards; XP is rebuilt from completed achievements.")) }
            if busy { ProgressView(store.t("正在处理…", "Working…")) }
            if !status.isEmpty { Text(status).foregroundStyle(.secondary) }
        }.navigationTitle(store.t("备份与恢复", "Backup & restore")).navigationBarTitleDisplayMode(.inline)
            .fileImporter(isPresented: $importer, allowedContentTypes: [.zip, .data], allowsMultipleSelection: false) { result in
                do { source = try result.get().first; importPassword = ""; status = "" } catch { store.error = error.localizedDescription }
            }
            .sheet(item: $shared, onDismiss: cleanupExport) { item in ActivitySheet(url: item.url) }
            .fileExporter(isPresented: $cloudExporter, document: cloudDocument, contentTypes: [.zip], defaultFilename: lastExport?.lastPathComponent) { result in
                switch result {
                case .success:
                    status = store.t("备份已保存到所选文件夹。若选择了 iCloud Drive，系统会自动同步。", "Backup saved to the selected folder. If you chose iCloud Drive, the system will sync it.")
                case .failure(let error): store.error = error.localizedDescription
                }
                cleanupExport()
            } onCancellation: { cleanupExport() }
            .alert(store.t("覆盖当前账本？", "Replace your current ledger?"), isPresented: $confirmRestore) {
                Button(store.t("确认恢复", "Restore"), role: .destructive) {
                    guard let backup = prepared else { return }
                    do { try store.restore(backup); status = store.t("备份已恢复", "Backup restored"); prepared = nil; source = nil; importPassword = "" }
                    catch { store.error = error.localizedDescription }
                }
                Button(store.t("取消", "Cancel"), role: .cancel) { prepared = nil }
            } message: {
                if let backup = prepared { Text(store.t("已验证 \(backup.state.achievements.count) 条成就、\(backup.state.notes.count) 条笔记。恢复将替换当前全部记录。", "Verified \(backup.state.achievements.count) achievements and \(backup.state.notes.count) notes. Restoring replaces all current records.") + (backup.isAndroid ? store.t("\nAndroid 的积分按已完成成就重建。", "\nAndroid XP will be rebuilt from completed achievements.") : "")) }
            }
    }
    func export(toCloud: Bool) {
        busy = true
        status = ""
        let passphrase = password
        Task {
            do {
                let url = try await store.exportBackup(password: passphrase)
                lastExport = url
                if toCloud {
                    cloudDocument = BackupDocument(bytes: try Data(contentsOf: url))
                    cloudExporter = true
                } else { shared = ShareFile(url: url) }
                password = ""; confirmation = ""
            } catch { store.error = error.localizedDescription }
            busy = false
        }
    }
    func cleanupExport() {
        cloudDocument = nil
        if let url = lastExport { try? FileManager.default.removeItem(at: url); lastExport = nil }
    }
    func verify(_ url: URL) {
        busy = true
        let password = importPassword
        Task {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                prepared = try await Task.detached(priority: .userInitiated) { try BackupService.prepare(bytes: Data(contentsOf: url), password: password) }.value
                confirmRestore = true
            } catch { store.error = error.localizedDescription }
            busy = false
        }
    }
}
struct ActivitySheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

/// The native file exporter can save the same ZIP in any enabled Files provider.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }
    var bytes: Data
    init(bytes: Data) { self.bytes = bytes }
    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.bytes = bytes
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: bytes) }
}
