import Foundation
import Darwin

struct PreparedBackup {
    var state: LedgerData
    var files: [String: Data]
    var isAndroid: Bool
}
struct IOSBackup: Codable {
    var platform = "LifeLedger-iOS"
    var data: LedgerData
}

enum BackupService {
    static func make(state: LedgerData, root: URL, password: String) throws -> Data {
        var files = ["backup.json": try LedgerCodec.encode(IOSBackup(data: state))]
        for path in LedgerStore.referencedMedia(state) {
            guard ZipArchive.safePath(path) else { throw LedgerError.invalidBackup }
            files[path] = try Data(contentsOf: root.appendingPathComponent(path))
        }
        let zip = try ZipArchive.pack(files)
        return password.isEmpty ? zip : try LedgerSecurity.encryptBackup(zip, password: password)
    }
    static func prepare(bytes: Data, password: String) throws -> PreparedBackup {
        let plain = bytes.starts(with: LedgerSecurity.backupMagic) ? try LedgerSecurity.decryptBackup(bytes, password: password) : bytes
        var files = try ZipArchive.unpack(plain)
        guard let json = files["backup.json"] else { throw LedgerError.invalidBackup }
        let state: LedgerData
        let android: Bool
        if let object = try JSONSerialization.jsonObject(with: json) as? [String: Any], object["platform"] as? String == "LifeLedger-iOS" {
            state = try LedgerCodec.decode(IOSBackup.self, from: json).data
            android = false
        } else {
            let converted = try androidState(json, files: files)
            state = converted.0
            for (old, new) in converted.1 { files[new] = files[old] }
            android = true
        }
        try LedgerStore.validate(state)
        for path in LedgerStore.referencedMedia(state) { guard files[path] != nil else { throw LedgerError.missingMedia } }
        return PreparedBackup(state: state, files: files, isAndroid: android)
    }
    private static func androidState(_ json: Data, files: [String: Data]) throws -> (LedgerData, [String: String]) {
        guard let obj = try JSONSerialization.jsonObject(with: json) as? [String: Any],
              let items = obj["achievements"] as? [[String: Any]],
              let notes = obj["notes"] as? [[String: Any]], let media = obj["media"] as? [[String: Any]] else { throw LedgerError.invalidBackup }
        if let version = obj["version"] as? Int, version != 1 { throw LedgerError.unsupportedVersion }
        var state = LedgerData(); state.onboarded = true
        var achievementMap: [Int: UUID] = [:], noteMap: [Int: UUID] = [:], copied: [String: String] = [:]
        func date(_ value: Any?) -> Date? { (value as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) } }
        func mapPath(_ value: String?) throws -> String? {
            guard let value, !value.isEmpty else { return nil }
            guard ZipArchive.safePath(value), let _ = files[value] else { throw LedgerError.missingMedia }
            if let existing = copied[value] { return existing }
            let new = "media/" + value.replacingOccurrences(of: "/", with: "_")
            copied[value] = new
            return new
        }
        for obj in items {
            guard let id = obj["id"] as? Int, let title = obj["title"] as? String, achievementMap[id] == nil else { throw LedgerError.invalidBackup }
            var item = Achievement(title: title, detail: obj["description"] as? String ?? "", icon: obj["iconEmoji"] as? String ?? "🏆", category: obj["category"] as? String ?? "生活", presetID: obj["presetId"] as? Int)
            item.createdAt = date(obj["createdDate"]) ?? Date()
            if obj["isCompleted"] as? Bool == true { item.completedAt = date(obj["completedDate"]) ?? item.createdAt }
            if item.icon.hasPrefix("icons/") { item.icon = try mapPath(item.icon)! }
            achievementMap[id] = item.id
            state.achievements.append(item)
            if let completed = item.completedAt { state.points.append(PointEntry(amount: 50, kind: "achievement", sourceID: item.id, title: item.title, createdAt: completed)) }
        }
        for obj in notes {
            guard let id = obj["id"] as? Int, let owner = obj["achievementId"] as? Int, let uuid = achievementMap[owner], noteMap[id] == nil else { throw LedgerError.invalidBackup }
            var note = Note(achievementID: uuid, text: obj["content"] as? String ?? "")
            note.createdAt = date(obj["createdDate"]) ?? Date(); note.updatedAt = date(obj["updatedDate"]) ?? note.createdAt
            noteMap[id] = note.id; state.notes.append(note)
        }
        for obj in media {
            guard let noteID = obj["noteId"] as? Int, let uuid = noteMap[noteID], let index = state.notes.firstIndex(where: { $0.id == uuid }),
                  let path = try mapPath(obj["filePath"] as? String) else { throw LedgerError.invalidBackup }
            let video = try mapPath(obj["motionVideoPath"] as? String)
            let type = (obj["fileType"] as? String ?? "").lowercased()
            let kind = video != nil ? "live" : (type.contains("video") || ["mp4", "mov", "m4v"].contains(URL(fileURLWithPath: path).pathExtension.lowercased()) ? "video" : "image")
            state.notes[index].attachments.append(Attachment(path: path, kind: kind, pairedVideo: video))
        }
        if let profile = obj["profile"] as? [String: Any] {
            state.profile.nickname = profile["nickname"] as? String ?? ""
            state.profile.signature = profile["signature"] as? String ?? ""
            if let path = try mapPath(profile["avatar"] as? String) { state.profile.avatar = path }
            else if let preset = profile["avatarPreset"] as? String { state.profile.avatar = ["SUNRISE": "🌄", "WAVE": "🌊", "MOUNTAIN": "⛰️", "LEAF": "🍃", "MOON": "🌙", "CLOUD": "☁️", "SPARKLE": "✨", "PETAL": "🌸"][preset] ?? "🌄" }
            state.profile.gender = (profile["gender"] as? String ?? "").lowercased()
            state.profile.mbti = profile["mbti"] as? String ?? ""
        }
        state.startedAt = state.achievements.map(\.createdAt).min() ?? Date()
        return (state, copied)
    }
}

extension LedgerStore {
    func exportBackup(password: String) async throws -> URL {
        let state = data, root = root
        let bytes = try await Task.detached(priority: .userInitiated) { try BackupService.make(state: state, root: root, password: password) }.value
        let formatter = DateFormatter(); formatter.dateFormat = "yyyyMMdd_HHmmss"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lifeledger_backup_\(formatter.string(from: Date())).zip")
        try bytes.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
    func restore(_ backup: PreparedBackup) throws {
        try Self.validate(backup.state)
        var state = backup.state
        state.preferences.biometricLock = false
        state.preferences.reminder = false
        state.preferences.encryptLocalData = data.preferences.encryptLocalData
        let staging = root.deletingLastPathComponent().appendingPathComponent("restore-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: staging.appendingPathComponent("media"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        for path in Self.referencedMedia(state) {
            guard let bytes = backup.files[path] else { throw LedgerError.missingMedia }
            try bytes.write(to: staging.appendingPathComponent(path), options: [.atomic, .completeFileProtection])
        }
        let plain = try LedgerCodec.encode(state)
        let bytes = state.preferences.encryptLocalData ? try LedgerSecurity.encryptLocal(plain) : plain
        try bytes.write(to: staging.appendingPathComponent("ledger.json"), options: [.atomic, .completeFileProtection])
        // Same-volume directory exchange is atomic, including across process interruption.
        guard renamex_np(staging.path, root.path, UInt32(RENAME_SWAP)) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        data = state; loadFailed = false
        Task { await ReminderService.cancel() }
    }
}
