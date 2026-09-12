import Foundation

/// 记忆分类
enum MemoryCategory: String, Codable, CaseIterable {
    case userPreference = "userPreference"
    case projectDecision = "projectDecision"
    case importantFact = "importantFact"
    case longTermTask = "longTermTask"
    case conversation = "conversation"
    case other = "other"
}

/// 对话记录
struct Conversation: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [Message]

    init(id: UUID = UUID(), title: String = "新对话", createdAt: Date = Date(), updatedAt: Date = Date(), messages: [Message] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

/// 长期记忆条目
struct MemoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    var category: MemoryCategory
    var createdAt: Date
    var updatedAt: Date
    var importance: Double
    var tags: [String]
    var sourceConversationID: UUID?

    init(id: UUID = UUID(), content: String, category: MemoryCategory = .other, createdAt: Date = Date(), updatedAt: Date = Date(), importance: Double = 0.5, tags: [String] = [], sourceConversationID: UUID? = nil) {
        self.id = id
        self.content = content
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.importance = importance
        self.tags = tags
        self.sourceConversationID = sourceConversationID
    }
}

/// 检索结果
struct RetrievalResult: Identifiable, Equatable {
    let id: UUID
    let content: String
    let score: Double
    let source: MemorySource

    enum MemorySource: String, Codable, Equatable {
        case memory = "memory"
        case conversation = "conversation"
    }
}

/// 用于检索索引的内部结构
struct IndexedMemory: Equatable {
    let id: UUID
    let content: String
    let tokens: Set<String>
    let ngrams: Set<String>
    let metadata: RetrievalResult.MemorySource

    init(id: UUID, content: String, metadata: RetrievalResult.MemorySource) {
        self.id = id
        self.content = content
        self.metadata = metadata
        let lower = content.lowercased()
        self.tokens = Set(tokenize(lower))
        self.ngrams = Set(ngrams(from: lower, length: 3))
    }

    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        let regex = try? NSRegularExpression(pattern: "[\\p{Alphabetic}]+|\\p{Nd}+")
        let range = NSRange(location: 0, length: text.utf16.count)
        regex?.enumerateMatches(in: text, range: range) { result, _, _ in
            guard let result = result else { return }
            let nsRange = result.range
            if let swiftRange = Range(nsRange, in: text) {
                tokens.append(String(text[swiftRange]).lowercased())
            }
        }
        return tokens
    }

    private static func ngrams(from text: String, length: Int) -> [String] {
        guard text.count >= length else { return [] }
        var result: [String] = []
        let chars = Array(text)
        for i in 0...(chars.count - length) {
            result.append(String(chars[i..<i + length]))
        }
        return result
    }
}
