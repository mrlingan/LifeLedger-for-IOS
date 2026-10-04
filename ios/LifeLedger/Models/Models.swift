import Foundation

struct Preset: Codable, Identifiable {
    let id: Int
    let title: String
    let desc: String
    let rate: Double
    let category: String
    let rarity: String
    let story: String
    var tier: Rarity { Rarity(rate: rate) }
    var icon: String { Catalog.icon(for: category) }
}

enum Rarity: Int, CaseIterable {
    case bronze, silver, gold, platinum, legendary
    init(rate: Double) {
        self = rate > 50 ? .bronze : rate > 20 ? .silver : rate > 10 ? .gold : rate > 5 ? .platinum : .legendary
    }
    var zh: String { ["青铜", "白银", "黄金", "白金", "传奇"][rawValue] }
    var en: String { ["Bronze", "Silver", "Gold", "Platinum", "Legendary"][rawValue] }
}

enum Catalog {
    static let presets: [Preset] = {
        guard let url = Bundle.main.url(forResource: "preset_achievements", withExtension: "json"),
              let data = try? Data(contentsOf: url), let result = try? JSONDecoder().decode([Preset].self, from: data) else {
            preconditionFailure("Missing or invalid bundled achievement catalog")
        }
        return result
    }()
    static let english: [String: [String: String]] = {
        guard let url = Bundle.main.url(forResource: "preset_en", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: [String: String]].self, from: data)) ?? [:]
    }()
    static let categories = ["成长", "生活", "旅行", "学业", "情感", "娱乐", "社交", "兴趣", "技能", "职业", "家庭", "新手村", "健康", "财务"]
    static let categoryEnglish = ["成长": "Growth", "生活": "Life", "旅行": "Travel", "学业": "Education", "情感": "Love", "娱乐": "Entertainment", "社交": "Social", "兴趣": "Hobbies", "技能": "Skills", "职业": "Career", "家庭": "Family", "新手村": "Beginnings", "健康": "Health", "财务": "Finance"]
    static func icon(for category: String) -> String {
        ["成长": "🌱", "生活": "🏡", "旅行": "🌏", "学业": "🎓", "情感": "💛", "娱乐": "🎮", "社交": "🤝", "兴趣": "🎨", "技能": "🛠️", "职业": "💼", "家庭": "👨‍👩‍👧", "新手村": "✨", "健康": "🏃", "财务": "💰"][category] ?? "🏆"
    }
}

struct Achievement: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var detail = ""
    var icon = "🏆"
    var category = "生活"
    var presetID: Int?
    var createdAt = Date()
    var completedAt: Date?
    var isCompleted: Bool { completedAt != nil }
}

struct Attachment: Codable, Identifiable, Equatable {
    var id = UUID()
    var path: String
    var kind: String // image, video, live
    var pairedVideo: String?
}

struct Note: Codable, Identifiable, Equatable {
    var id = UUID()
    var achievementID: UUID
    var text: String
    var createdAt = Date()
    var updatedAt = Date()
    var attachments: [Attachment] = []
}

struct PointEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var amount: Int
    var kind: String
    var sourceID: UUID
    var title: String
    var createdAt = Date()
}

struct Goal: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var detail = ""
    var start = Date()
    var due: Date
    var paused = false
}

struct GoalTask: Codable, Identifiable, Equatable {
    var id = UUID()
    var goalID: UUID
    var title: String
    var scheduledAt = Date()
    var reward = 10
    var completedAt: Date?
}

struct Reward: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var detail = ""
    var icon: String
    var category: String
    var price: Int
    var catalogIndex: Int?
    static let defaults: [Reward] = [
        .init(title: "买一杯喜欢的咖啡", icon: "☕", category: "生活", price: 100, catalogIndex: 0),
        .init(title: "玩一晚上游戏", icon: "🎮", category: "娱乐", price: 500, catalogIndex: 1),
        .init(title: "吃一顿想吃很久的东西", icon: "🍜", category: "生活", price: 1000, catalogIndex: 2),
        .init(title: "去一次短途旅行", icon: "✈️", category: "旅行", price: 3000, catalogIndex: 3),
        .init(title: "买一副新耳机", icon: "🎧", category: "数码", price: 5000, catalogIndex: 4),
        .init(title: "升级一台电脑", icon: "💻", category: "学习", price: 10000, catalogIndex: 5)
    ]
    static let english = ["A coffee you actually like", "A whole evening of gaming", "That meal you've been craving", "A short trip somewhere new", "A new pair of headphones", "Upgrade your computer"]
}

struct Redemption: Codable, Identifiable, Equatable {
    var id = UUID()
    var rewardID: UUID
    var title: String
    var icon: String
    var price: Int
    var createdAt = Date()
    var refundedAt: Date?
}

struct Profile: Codable, Equatable {
    var nickname = ""
    var signature = ""
    var avatar = "🌄"
    var gender = ""
    var mbti = ""
}

enum HomeSection: String, Codable, CaseIterable, Identifiable {
    case progress, shortcuts, statistics, categories, recent, start, image
    var id: String { rawValue }
    var zh: String { ["progress": "人生进度", "shortcuts": "快捷入口", "statistics": "核心数据", "categories": "分类进度", "recent": "最近解锁", "start": "记录起点", "image": "自定义图片"][rawValue]! }
    var en: String { ["progress": "Life progress", "shortcuts": "Shortcuts", "statistics": "Statistics", "categories": "Categories", "recent": "Recent unlocks", "start": "Your beginning", "image": "Custom image"][rawValue]! }
}

struct Preferences: Codable, Equatable {
    var theme = "system"
    var language = "system"
    var confirmCompletion = true
    var defaultIcon = "🏆"
    var favoriteCategories: [String] = []
    var homeOrder = HomeSection.allCases
    var homeEnabled: [HomeSection] = [.progress, .shortcuts, .statistics, .categories]
    var homeImage: String?
    var backgroundImage: String?
    var backgroundOpacity = 0.2
    var haptics = true
    var sound = true
    var reminder = false
    var reminderHour = 20
    var reminderMinute = 0
    var biometricLock = false
    var encryptLocalData = false
}

struct LedgerData: Codable, Equatable {
    var version = 1
    var onboarded = false
    var startedAt = Date()
    var achievements: [Achievement] = []
    var notes: [Note] = []
    var points: [PointEntry] = []
    var goals: [Goal] = []
    var tasks: [GoalTask] = []
    var rewards = Reward.defaults
    var redemptions: [Redemption] = []
    var profile = Profile()
    var preferences = Preferences()
}

struct LifeStats {
    let achievements: [Achievement]
    var completed: [Achievement] { achievements.filter(\.isCompleted) }
    var level: Int { 1 + completed.count / 5 }
    var step: Int { completed.count % 5 }
    var toNext: Int { 5 - step }
    var progress: Double { achievements.isEmpty ? 0 : Double(completed.count) / Double(achievements.count) }
    var unlocked: Set<Int> { Set(completed.compactMap(\.presetID)) }
    var recordedDays: Int { Set(completed.compactMap(\.completedAt).map { Calendar.current.startOfDay(for: $0) }).count }
    func streak(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(completed.compactMap(\.completedAt).map { calendar.startOfDay(for: $0) })
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) { cursor = calendar.date(byAdding: .day, value: -1, to: cursor)! }
        var result = 0
        while days.contains(cursor) {
            result += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return result
    }
}

enum LedgerError: LocalizedError {
    case invalidBackup, unsupportedVersion, missingMedia, insufficientPoints, invalidInput, keychain(Int32), invalidPassword
    var errorDescription: String? {
        switch self {
        case .invalidBackup: return "备份文件无效 / Invalid backup file"
        case .unsupportedVersion: return "此备份版本尚不支持 / Unsupported backup version"
        case .missingMedia: return "备份中的媒体不完整 / Missing media in backup"
        case .insufficientPoints: return "积分不足 / Not enough XP"
        case .invalidInput: return "请检查输入内容 / Please check your input"
        case .keychain(let code): return "钥匙串错误 / Keychain error: \(code)"
        case .invalidPassword: return "口令错误或文件已损坏 / Incorrect password or damaged file"
        }
    }
}

enum LedgerCodec {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(type, from: data)
    }
}
