import Foundation
import Combine

@MainActor
final class MemoryStore: ObservableObject {
    // MARK: - Published UI State
    
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var memories: [MemoryEntry] = []
    @Published var isEnabled: Bool = true
    @Published var isPaused: Bool = false
    
    // MARK: - 内部状态
    
    private var activeConversationID: UUID?
    private var index: RetrievalIndex
    private let storeURL: URL
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    
    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? Self.defaultStoreURL()
        self.index = RetrievalIndex()
        load()
        $isEnabled
            .sink { [weak self] _ in self?.persist() }
            .store(in: &cancellables)
        $isPaused
            .sink { [weak self] _ in self?.persist() }
            .store(in: &cancellables)
    }
    
    static func defaultStoreURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support
            .appendingPathComponent("Jarvis", isDirectory: true)
            .appendingPathComponent("MemoryStore.json")
    }
    
    // MARK: - 对话管理
    
    func startNewConversation(title: String = "新对话") -> UUID {
        let id = UUID()
        let conversation = Conversation(id: id, title: title, messages: [], createdAt: Date(), updatedAt: Date())
        conversations.append(conversation)
        activeConversationID = id
        persist()
        return id
    }
    
    func addMessage(_ message: Message) {
        if activeConversationID == nil {
            _ = startNewConversation()
        }
        guard let id = activeConversationID,
              let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[idx].messages.append(message)
        conversations[idx].updatedAt = Date()
        if isEnabled, !isPaused {
            index.add(IndexedMemory(id: message.id, content: message.text, metadata: .conversation))
        }
        persist()
    }
    
    func deleteConversation(id: UUID) {
        conversations.removeAll { $0.id == id }
        if activeConversationID == id {
            activeConversationID = nil
        }
        memories = memories.filter { $0.sourceConversationID != id }
        index = buildIndex()
        persist()
    }
    
    // MARK: - 记忆管理
    
    func addMemory(content: String, category: MemoryCategory = .other, importance: Double = 0.5, tags: [String] = [], sourceConversationID: UUID? = nil) {
        guard isEnabled, !isPaused else { return }
        let entry = MemoryEntry(
            id: UUID(),
            content: content,
            category: category,
            createdAt: Date(),
            updatedAt: Date(),
            importance: importance,
            tags: tags,
            sourceConversationID: sourceConversationID
        )
        memories.append(entry)
        index.add(IndexedMemory(id: entry.id, content: content, metadata: .memory))
        persist()
    }
    
    func deleteMemory(id: UUID) {
        memories.removeAll { $0.id == id }
        index = buildIndex()
        persist()
    }
    
    func clearAll() {
        conversations = []
        memories = []
        activeConversationID = nil
        index = RetrievalIndex()
        persist()
    }
    
    func pause(_ paused: Bool) {
        isPaused = paused
    }
    
    // MARK: - 检索
    
    func retrieve(query: String, limit: Int = 5) -> [RetrievalResult] {
        guard isEnabled else { return [] }
        let allItems = buildIndexedItems()
        return index.retrieve(query: query, limit: limit, from: allItems)
    }
    
    // MARK: - 持久化
    
    private func load() {
        if FileManager.default.fileExists(atPath: storeURL.path) {
            do {
                let data = try Data(contentsOf: storeURL)
                let decoded = try JSONDecoder().decode(StoredMemoryData.self, from: data)
                conversations = decoded.conversations
                memories = decoded.memories
                activeConversationID = decoded.activeConversationID
                index = buildIndex()
            } catch {
                print("⚠️ 记忆存储加载失败: \(error)")
                reset()
            }
        } else {
            createDirectoryIfNeeded()
        }
    }
    
    private func persist() {
        createDirectoryIfNeeded()
        let data = StoredMemoryData(
            conversations: conversations,
            memories: memories,
            activeConversationID: activeConversationID
        )
        do {
            let json = try JSONEncoder().encode(data)
            try json.write(to: storeURL)
        } catch {
            print("⚠️ 记忆存储持久化失败: \(error)")
        }
    }
    
    private func createDirectoryIfNeeded() {
        storeURL.deletingLastPathComponent().createDirectoryIfNeeded()
    }
    
    private func reset() {
        conversations = []
        memories = []
        activeConversationID = nil
        index = RetrievalIndex()
    }
    
    // MARK: - 索引
    
    private func buildIndex() -> RetrievalIndex {
        var idx = RetrievalIndex()
        for mem in memories {
            idx.add(IndexedMemory(id: mem.id, content: mem.content, metadata: .memory))
        }
        for conv in conversations {
            for msg in conv.messages {
                idx.add(IndexedMemory(id: msg.id, content: msg.text, metadata: .conversation))
            }
        }
        return idx
    }
    
    private func buildIndexedItems() -> [IndexedMemory] {
        var items: [IndexedMemory] = []
        for mem in memories {
            items.append(IndexedMemory(id: mem.id, content: mem.content, metadata: .memory))
        }
        for conv in conversations {
            for msg in conv.messages {
                items.append(IndexedMemory(id: msg.id, content: msg.text, metadata: .conversation))
            }
        }
        return items
    }
    
    // MARK: - 持久化结构（嵌套在类内部）
    
    private struct StoredMemoryData: Codable {
        var conversations: [Conversation]
        var memories: [MemoryEntry]
        var activeConversationID: UUID?
    }
    
    // MARK: - 单例
    
    static let shared = MemoryStore()
    
    // MARK: - 存储大小估算
    
    var estimatedStorageSize: Int64 {
        let conversationsData = (try? JSONEncoder().encode(conversations))?.count ?? 0
        let memoriesData = (try? JSONEncoder().encode(memories))?.count ?? 0
        return Int64(conversationsData + memoriesData)
    }
    
    // MARK: - 导出数据（用于备份/迁移）
    
    func exportData() -> Data? {
        let data = StoredMemoryData(
            conversations: conversations,
            memories: memories,
            activeConversationID: activeConversationID
        )
        return try? JSONEncoder().encode(data)
    }
    
    func importData(_ data: Data) {
        do {
            let decoded = try JSONDecoder().decode(StoredMemoryData.self, from: data)
            conversations = decoded.conversations
            memories = decoded.memories
            activeConversationID = decoded.activeConversationID
            index = buildIndex()
            persist()
        } catch {
            print("⚠️ 记忆导入失败: \(error)")
        }
    }
}