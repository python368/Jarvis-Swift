import Foundation

/// 搜索结果
struct SearchResult: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let snippet: String
    let url: String
    let source: String
    let timestamp: Date
}

/// 搜索选项
struct SearchOptions: Codable, Equatable {
    let maxResults: Int
    let language: String?
    let region: String?
    let safeSearch: Bool
    
    init(maxResults: Int = 10, language: String? = nil, region: String? = nil, safeSearch: Bool = true) {
        self.maxResults = maxResults
        self.language = language
        self.region = region
        self.safeSearch = safeSearch
    }
}

/// 搜索 Provider 类型
enum SearchProviderType: String, Codable, CaseIterable {
    case web = "web"
    case news = "news"
    case images = "images"
    case deep = "deep"
    case custom = "custom"
}

/// 搜索 Provider 配置
struct SearchProviderConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var providerType: SearchProviderType
    var baseURL: String
    var apiKey: String?
    var authType: AuthType
    var customHeaders: [String: String]?
    var enabled: Bool
    var defaultOptions: SearchOptions
    
    init(id: UUID = UUID(), name: String, providerType: SearchProviderType, baseURL: String, apiKey: String? = nil, authType: AuthType = .bearer, customHeaders: [String: String]? = nil, enabled: Bool = true, defaultOptions: SearchOptions = SearchOptions()) {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.authType = authType
        self.customHeaders = customHeaders
        self.enabled = enabled
        self.defaultOptions = defaultOptions
    }
}

/// 搜索 Provider 协议
protocol SearchProvider: AnyObject {
    var name: String { get }
    var providerType: SearchProviderType { get }
    var supportedTypes: [SearchProviderType] { get }
    
    func search(query: String, options: SearchOptions) async throws -> [SearchResult]
    func supports(_ type: SearchProviderType) -> Bool
}

/// 搜索 Provider 管理器
@MainActor
final class SearchManager: ObservableObject {
    @Published var providers: [SearchProviderConfig] = []
    @Published var selectedProviderID: UUID?
    
    private let storeURL: URL
    private var backends: [UUID: SearchProvider] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? Self.defaultStoreURL()
        load()
        $providers.sink { [weak self] _ in self?.persist() }.store(in: &cancellables)
    }
    
    static func defaultStoreURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("Jarvis", isDirectory: true).appendingPathComponent("SearchProviders.json")
    }
    
    var selectedProvider: SearchProviderConfig? {
        selectedProviderID.flatMap { providers.first { $0.id == $0 } }
    }
    
    var selectedBackend: SearchProvider? {
        selectedProviderID.flatMap { backends[$0] }
    }
    
    func addProvider(_ config: SearchProviderConfig) {
        providers.append(config)
        selectedProviderID = config.id
        createBackend(for: config)
    }
    
    func updateProvider(_ config: SearchProviderConfig) {
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
    
    func createBackend(for config: SearchProviderConfig) {
        guard config.enabled else { backends[config.id] = nil; return }
        let backend: SearchProvider
        switch config.providerType {
        case .web:
            backend = WebSearchBackend(config: config)
        case .news:
            backend = NewsSearchBackend(config: config)
        case .images:
            backend = ImageSearchBackend(config: config)
        case .deep:
            backend = DeepSearchBackend(config: config)
        case .custom:
            backend = CustomSearchBackend(config: config)
        }
        backends[config.id] = backend
    }
    
    func search(query: String, options: SearchOptions? = nil) async throws -> [SearchResult] {
        guard let backend = selectedBackend else {
            throw NSError(domain: "SearchManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未选择搜索 Provider"])
        }
        return try await backend.search(query: query, options: options ?? selectedProvider?.defaultOptions ?? SearchOptions())
    }
    
    private func load() {
        if FileManager.default.fileExists(atPath: storeURL.path) {
            do {
                let data = try Data(contentsOf: storeURL)
                let decoded = try JSONDecoder().decode([SearchProviderConfig].self, from: data)
                providers = decoded
                for config in providers where config.enabled {
                    createBackend(for: config)
                }
                selectedProviderID = providers.first { $0.enabled }?.id
            } catch {
                print("⚠️ SearchProvider 加载失败: \(error)")
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
            print("⚠️ SearchProvider 持久化失败: \(error)")
        }
    }
    
    private func createDirectoryIfNeeded() {
        storeURL.deletingLastPathComponent().createDirectoryIfNeeded()
    }
}