import Foundation
import Combine

/// 统一的模型能力
enum Capability: String, Codable, CaseIterable {
    case chat = "chat"
    case vision = "vision"
    case audio = "audio"
    case toolCalling = "toolCalling"
    case streaming = "streaming"
}

/// 统一消息角色
enum MessageRole: String, Codable, CaseIterable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
    case tool = "tool"
}

/// 统一附件
struct Attachment: Identifiable, Codable, Equatable {
    let id: UUID
    let type: String // image, audio, file
    let mimeType: String?
    let data: Data
    let url: URL?
    
    init(id: UUID = UUID(), type: String, mimeType: String? = nil, data: Data, url: URL? = nil) {
        self.id = id
        self.type = type
        self.mimeType = mimeType
        self.data = data
        self.url = url
    }
}

/// 统一模型信息
struct Model: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let provider: String
    let capabilities: [Capability]
    let contextWindow: Int?
    let maxTokens: Int?
}

/// 工具定义
struct Tool: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let parameters: ToolParameters
}

/// 工具参数 Schema
struct ToolParameters: Codable, Equatable {
    let type: String // "object"
    let properties: [String: ToolProperty]
    let required: [String]?
}

/// 工具属性
struct ToolProperty: Codable, Equatable {
    let type: String
    let description: String?
    let enumValues: [String]?
    let items: [ToolProperty]?
    
    enum CodingKeys: String, CodingKey {
        case type, description, items
        case enumValues = "enum"
    }
}

/// 工具调用
struct ToolCall: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let arguments: String // JSON string
}

/// 统一事件流
enum StreamEvent: Codable, Equatable {
    case token(String)
    case toolCall(ToolCall)
    case complete(Response)
    case error(String)
}

/// 统一响应
struct Response: Codable, Equatable {
    let id: String
    let model: String
    let content: String
    let toolCalls: [ToolCall]?
    let usage: Usage?
    let finishReason: String?
}

/// Token 使用统计
struct Usage: Codable, Equatable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

/// 统一模型后端协议
protocol ModelBackend: AnyObject {
    var name: String { get }
    var providerType: ProviderType { get }
    var supportedCapabilities: [Capability] { get }
    
    func models() async throws -> [Model]
    func chat(
        messages: [Message],
        attachments: [Attachment],
        tools: [Tool]?,
        options: ChatOptions
    ) async throws -> AsyncThrowingStream<StreamEvent, Error>
    func supports(_ capability: Capability) -> Bool
}

/// 聊天选项
struct ChatOptions: Codable, Equatable {
    let temperature: Double?
    let topP: Double?
    let maxTokens: Int?
    let stop: [String]?
    let stream: Bool
    let systemPrompt: String?
    
    init(temperature: Double? = 0.7, topP: Double? = 1.0, maxTokens: Int? = nil, stop: [String]? = nil, stream: Bool = true, systemPrompt: String? = nil) {
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.stop = stop
        self.stream = stream
        self.systemPrompt = systemPrompt
    }
}

/// Provider 类型
enum ProviderType: String, Codable, CaseIterable {
    case openai = "openai"
    case google = "google"
    case groq = "groq"
    case deepseek = "deepseek"
    case anthropic = "anthropic"
    case openaiCompatible = "openaiCompatible"
    case custom = "custom"
    case mlx = "mlx"
    case llamaCpp = "llamaCpp"
    case ollama = "ollama"
    case lmStudio = "lmStudio"
    case mlc = "mlc"
    case localOther = "localOther"
}

/// Provider 配置（可持久化）
struct ProviderConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var providerType: ProviderType
    var baseURL: String
    var apiKey: String?
    var authType: AuthType
    var customHeaders: [String: String]?
    var enabled: Bool
    var defaultModel: String?
    var customModels: [Model]?
    
    init(id: UUID = UUID(), name: String, providerType: ProviderType, baseURL: String, apiKey: String? = nil, authType: AuthType = .bearer, customHeaders: [String: String]? = nil, enabled: Bool = true, defaultModel: String? = nil, customModels: [Model]? = nil) {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.authType = authType
        self.customHeaders = customHeaders
        self.enabled = enabled
        self.defaultModel = defaultModel
        self.customModels = customModels
    }
}

/// 认证类型
enum AuthType: String, Codable, CaseIterable {
    case bearer = "Bearer"
    case apiKey = "ApiKey"
    case custom = "Custom"
    case none = "None"
}

/// Provider 管理器
@MainActor
final class ProviderManager: ObservableObject {
    @Published var providers: [ProviderConfig] = []
    @Published var selectedProviderID: UUID?
    
    private let storeURL: URL
    private var backends: [UUID: ModelBackend] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? Self.defaultStoreURL()
        load()
        $providers.sink { [weak self] _ in self?.persist() }.store(in: &cancellables)
    }
    
    static func defaultStoreURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("Relay", isDirectory: true).appendingPathComponent("Providers.json")
    }
    
    var selectedProvider: ProviderConfig? {
        selectedProviderID.flatMap { id in providers.first { $0.id == id } }
    }
    
    var selectedBackend: ModelBackend? {
        selectedProviderID.flatMap { backends[$0] }
    }
    
    func addProvider(_ config: ProviderConfig) {
        providers.append(config)
        selectedProviderID = config.id
        createBackend(for: config)
    }
    
    func updateProvider(_ config: ProviderConfig) {
        if let idx = providers.firstIndex(where: { $0.id == config.id }) {
            providers[idx] = config
            backends[config.id] = nil
            if config.enabled { createBackend(for: config) }
        }
    }
    
    func removeProvider(id: UUID) {
        providers.removeAll { $0.id == id }
        backends.removeValue(forKey: id)
        if selectedProviderID == id { selectedProviderID = providers.first?.id }
    }
    
    func selectProvider(id: UUID) {
        selectedProviderID = id
    }
    
    func createBackend(for config: ProviderConfig) {
        guard config.enabled else { backends[config.id] = nil; return }
        let backend: ModelBackend
        switch config.providerType {
        case .openai, .groq, .deepseek, .openaiCompatible, .custom:
            backend = OpenAICompatibleBackend(config: config)
        case .google:
            backend = GoogleBackend(config: config)
        case .anthropic:
            backend = AnthropicBackend(config: config)
        case .mlx:
            backend = MLXBackend(config: config)
        case .llamaCpp:
            backend = LlamaCppBackend(config: config)
        case .ollama:
            backend = OllamaBackend(config: config)
        case .lmStudio:
            backend = LMStudioBackend(config: config)
        case .mlc:
            backend = MLCBackend(config: config)
        case .localOther:
            backend = LocalOtherBackend(config: config)
        }
        backends[config.id] = backend
    }
    
    func getBackend(for providerID: UUID) -> ModelBackend? {
        if let backend = backends[providerID] { return backend }
        if let config = providers.first(where: { $0.id == providerID }) {
            createBackend(for: config)
            return backends[providerID]
        }
        return nil
    }
    
    private func load() {
        if FileManager.default.fileExists(atPath: storeURL.path) {
            do {
                let data = try Data(contentsOf: storeURL)
                let decoded = try JSONDecoder().decode([ProviderConfig].self, from: data)
                providers = decoded
                for config in providers where config.enabled {
                    createBackend(for: config)
                }
                selectedProviderID = providers.first { $0.enabled }?.id
            } catch {
                print("⚠️ Provider 加载失败: \(error)")
            }
        } else {
            createDirectoryIfNeeded()
        }
    }
    
    private func persist() {
        createDirectoryIfNeeded()
        do {
            let json = try JSONEncoder().encode(providers)
            try json.write(to: storeURL)
        } catch {
            print("⚠️ Provider 持久化失败: \(error)")
        }
    }
    
    private func createDirectoryIfNeeded() {
        let dir = storeURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}