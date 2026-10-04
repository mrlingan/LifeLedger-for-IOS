import Foundation
import SwiftUI
import AudioToolbox

@MainActor
final class LedgerStore: ObservableObject {
    @Published var data = LedgerData()
    @Published var error: String?
    @Published var loadFailed = false
    let root: URL
    private var soundID: SystemSoundID = 0
    var stats: LifeStats { LifeStats(achievements: data.achievements) }
    var balance: Int { data.points.reduce(0) { $0 + $1.amount } }
    var zh: Bool { data.preferences.language == "zh" || (data.preferences.language == "system" && (Locale.preferredLanguages.first ?? "en").hasPrefix("zh")) }
    var locale: Locale { Locale(identifier: zh ? "zh_Hans_CN" : "en_US") }
    var name: String { data.profile.nickname.isEmpty ? t("人生玩家", "Life explorer") : data.profile.nickname }
    var categories: [String] {
        let extra = Set(data.achievements.map(\.category)).subtracting(Catalog.categories).sorted()
        return (Catalog.categories + extra).sorted { a, b in
            let fav = data.preferences.favoriteCategories
            return (fav.contains(a) ? 0 : 1) < (fav.contains(b) ? 0 : 1)
        }
    }
    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(ProcessInfo.processInfo.arguments.contains("--uitesting") ? "LifeLedger-UITests" : "LifeLedger", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.root.appendingPathComponent("media"), withIntermediateDirectories: true)
            let file = self.root.appendingPathComponent("ledger.json")
            if FileManager.default.fileExists(atPath: file.path) {
                let saved = try Data(contentsOf: file)
                let bytes = saved.starts(with: LedgerSecurity.localMagic) ? try LedgerSecurity.decryptLocal(saved) : saved
                let loaded = try LedgerCodec.decode(LedgerData.self, from: bytes)
                try Self.validate(loaded)
                data = loaded
            }
        } catch { loadFailed = true; self.error = error.localizedDescription }
        if let url = Bundle.main.url(forResource: "complete", withExtension: "wav") { AudioServicesCreateSystemSoundID(url as CFURL, &soundID) }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            data = LedgerData()
            loadFailed = false
        }
        #endif
    }
    func t(_ chinese: String, _ english: String) -> String { zh ? chinese : english }
    func category(_ value: String) -> String {
        zh ? value : (Catalog.categoryEnglish[value] ?? ["数码": "Digital", "学习": "Learning"][value] ?? value)
    }
    func presetText(_ preset: Preset, _ field: String) -> String {
        let fallback = field == "t" ? preset.title : field == "d" ? preset.desc : preset.story
        return zh ? fallback : Catalog.english[String(preset.id)]?[field] ?? fallback
    }
    func title(_ achievement: Achievement) -> String {
        if let id = achievement.presetID, let preset = Catalog.presets.first(where: { $0.id == id }), achievement.title == preset.title { return presetText(preset, "t") }
        return achievement.title
    }
    func detail(_ achievement: Achievement) -> String {
        if let id = achievement.presetID, let preset = Catalog.presets.first(where: { $0.id == id }), achievement.detail == preset.desc { return presetText(preset, "d") }
        return achievement.detail
    }
    func rewardTitle(_ reward: Reward) -> String {
        if !zh, let i = reward.catalogIndex, Reward.english.indices.contains(i) { return Reward.english[i] }
        return reward.title
    }
    func date(_ date: Date, full: Bool = false) -> String {
        let formatter = DateFormatter(); formatter.locale = locale
        formatter.dateFormat = full ? (zh ? "yyyy年M月d日" : "MMM d, yyyy") : (zh ? "M月d日 EEEE" : "EEEE, MMM d")
        return formatter.string(from: date)
    }
    func mediaURL(_ path: String) -> URL { root.appendingPathComponent(path) }
    func notes(for id: UUID) -> [Note] { data.notes.filter { $0.achievementID == id }.sorted { $0.createdAt > $1.createdAt } }
    func record(for preset: Preset) -> Achievement? { data.achievements.first { $0.presetID == preset.id } }
    @discardableResult
    func change(_ mutation: (inout LedgerData) throws -> Void) -> Bool {
        guard !loadFailed else { return false }
        var next = data
        do {
            try mutation(&next)
            try Self.validate(next)
            try persist(next)
            data = next
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    private func persist(_ value: LedgerData) throws {
        let plain = try LedgerCodec.encode(value)
        let bytes = value.preferences.encryptLocalData ? try LedgerSecurity.encryptLocal(plain) : plain
        try bytes.write(to: root.appendingPathComponent("ledger.json"), options: [.atomic, .completeFileProtection])
    }
    func onboarding(includePresets: Bool) {
        change {
            guard !$0.onboarded else { return }
            $0.onboarded = true
            if includePresets { $0.achievements = Catalog.presets.map(Self.achievement) }
        }
    }
    static func achievement(_ preset: Preset) -> Achievement {
        Achievement(title: preset.title, detail: preset.desc, icon: preset.icon, category: preset.category, presetID: preset.id)
    }
    @discardableResult
    func save(_ achievement: Achievement) -> Bool {
        change {
            guard !achievement.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LedgerError.invalidInput }
            if let index = $0.achievements.firstIndex(where: { $0.id == achievement.id }) {
                // Completion is a separate operation; editing never silently changes the ledger.
                var edited = achievement; edited.completedAt = $0.achievements[index].completedAt
                $0.achievements[index] = edited
            } else {
                guard !($0.achievements.contains { $0.presetID != nil && $0.presetID == achievement.presetID }) else { throw LedgerError.invalidInput }
                var new = achievement; new.completedAt = nil
                $0.achievements.append(new)
            }
        }
    }
    func complete(_ id: UUID, date: Date? = Date()) {
        let success = change { state in
            guard let i = state.achievements.firstIndex(where: { $0.id == id }) else { return }
            let old = state.achievements[i]
            if old.isCompleted == (date != nil) {
                state.achievements[i].completedAt = date
                return
            }
            state.achievements[i].completedAt = date
            state.points.append(PointEntry(amount: date == nil ? -50 : 50, kind: date == nil ? "achievement_reversal" : "achievement", sourceID: id, title: old.title, createdAt: date ?? Date()))
        }
        if success, date != nil { feedback() }
    }
    func deleteAchievement(_ id: UUID) {
        let media = data.notes.filter { $0.achievementID == id }.flatMap(\.attachments)
        if change({ state in
            if let item = state.achievements.first(where: { $0.id == id }), item.isCompleted {
                state.points.append(PointEntry(amount: -50, kind: "achievement_reversal", sourceID: id, title: item.title))
            }
            state.notes.removeAll { $0.achievementID == id }
            state.achievements.removeAll { $0.id == id }
        }) { removeMedia(media) }
    }
    @discardableResult
    func saveNote(_ note: Note) -> Bool {
        let old = data.notes.first { $0.id == note.id }
        let success = change {
            guard $0.achievements.contains(where: { $0.id == note.achievementID }), !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !note.attachments.isEmpty else { throw LedgerError.invalidInput }
            if let i = $0.notes.firstIndex(where: { $0.id == note.id }) { $0.notes[i] = note }
            else { $0.notes.append(note) }
        }
        if success, let old { removeMedia(old.attachments.filter { !note.attachments.contains($0) }) }
        return success
    }
    func deleteNote(_ note: Note) {
        if change({ $0.notes.removeAll { $0.id == note.id } }) { removeMedia(note.attachments) }
    }
    func removeMedia(_ attachments: [Attachment]) {
        let referenced = Self.referencedMedia(data)
        for item in attachments {
            for path in [item.path, item.pairedVideo].compactMap({ $0 }) where !referenced.contains(path) {
                try? FileManager.default.removeItem(at: mediaURL(path))
            }
        }
    }
    func feedback() {
        if data.preferences.haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        if data.preferences.sound, soundID != 0 { AudioServicesPlaySystemSound(soundID) }
    }
    func completeTask(_ id: UUID) {
        if change({ state in
            guard let index = state.tasks.firstIndex(where: { $0.id == id }), state.tasks[index].completedAt == nil else { return }
            state.tasks[index].completedAt = Date()
            let task = state.tasks[index]
            state.points.append(PointEntry(amount: task.reward, kind: "daily_task", sourceID: id, title: task.title))
        }) { feedback() }
    }
    func redeem(_ reward: Reward) {
        if change({ state in
            guard state.rewards.contains(where: { $0.id == reward.id }), state.points.reduce(0, { $0 + $1.amount }) >= reward.price else { throw LedgerError.insufficientPoints }
            let redemption = Redemption(rewardID: reward.id, title: rewardTitle(reward), icon: reward.icon, price: reward.price)
            state.redemptions.append(redemption)
            state.points.append(PointEntry(amount: -reward.price, kind: "reward_redeem", sourceID: redemption.id, title: redemption.title))
        }) { feedback() }
    }
    func refund(_ id: UUID) {
        change { state in
            guard let i = state.redemptions.firstIndex(where: { $0.id == id }), state.redemptions[i].refundedAt == nil else { return }
            state.redemptions[i].refundedAt = Date()
            let item = state.redemptions[i]
            state.points.append(PointEntry(amount: item.price, kind: "reward_refund", sourceID: id, title: item.title))
        }
    }
    nonisolated static func validate(_ state: LedgerData) throws {
        guard state.version == 1 else { throw LedgerError.unsupportedVersion }
        func unique(_ ids: [UUID]) -> Bool { Set(ids).count == ids.count }
        let achievementIDs = Set(state.achievements.map(\.id)), goalIDs = Set(state.goals.map(\.id))
        guard unique(state.achievements.map(\.id)), unique(state.notes.map(\.id)), unique(state.tasks.map(\.id)), unique(state.goals.map(\.id)), unique(state.points.map(\.id)), unique(state.rewards.map(\.id)), unique(state.redemptions.map(\.id)),
              state.notes.allSatisfy({ achievementIDs.contains($0.achievementID) }), state.tasks.allSatisfy({ goalIDs.contains($0.goalID) }),
              state.rewards.allSatisfy({ (1...1_000_000).contains($0.price) }), state.tasks.allSatisfy({ (0...10000).contains($0.reward) }),
              state.points.allSatisfy({ (-1_000_000...1_000_000).contains($0.amount) }),
              state.preferences.homeOrder.count == HomeSection.allCases.count,
              Set(state.preferences.homeOrder) == Set(HomeSection.allCases), (0...1).contains(state.preferences.backgroundOpacity),
              (0..<24).contains(state.preferences.reminderHour), (0..<60).contains(state.preferences.reminderMinute) else { throw LedgerError.invalidBackup }
        let presets = state.achievements.compactMap(\.presetID)
        guard Set(presets).count == presets.count, presets.allSatisfy({ id in Catalog.presets.contains { $0.id == id } }) else { throw LedgerError.invalidBackup }
        for path in referencedMedia(state) { guard ZipArchive.safePath(path), path.hasPrefix("media/") else { throw LedgerError.invalidBackup } }
    }
    nonisolated static func referencedMedia(_ state: LedgerData) -> Set<String> {
        var paths = state.notes.flatMap(\.attachments).flatMap { [$0.path, $0.pairedVideo].compactMap { $0 } }
        paths += state.achievements.compactMap { $0.icon.hasPrefix("media/") ? $0.icon : nil }
        paths += [state.preferences.homeImage, state.preferences.backgroundImage].compactMap { $0 }
        if state.profile.avatar.hasPrefix("media/") { paths.append(state.profile.avatar) }
        return Set(paths)
    }
}
