import Foundation

/// 搜索后端基类
class SearchBackend: SearchProvider {
    let name: String
    let providerType: SearchProviderType
    let supportedTypes: [SearchProviderType]
    let config: SearchProviderConfig
    let session: URLSession
    
    init(config: SearchProviderConfig) {
        self.name = config.name
        self.providerType = config.providerType
        self.config = config
        self.session = URLSession.shared
        self.supportedTypes = [config.providerType]
    }
    
    func search(query: String, options: SearchOptions) async throws -> [SearchResult] {
        fatalError("子类必须实现")
    }
    
    func supports(_ type: SearchProviderType) -> Bool {
        supportedTypes.contains(type)
    }
    
    func buildRequest(url: URL, query: String, options: SearchOptions) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(&request)
        return request
    }
    
    func addAuthHeaders(_ request: inout URLRequest) {
        switch config.authType {
        case .bearer:
            if let key = config.apiKey { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        case .apiKey:
            if let key = config.apiKey { request.setValue(key, forHTTPHeaderField: config.customHeaders?["X-API-Key"] ?? "X-API-Key") }
        case .custom:
            config.customHeaders?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        case .none: break
        }
    }
}

/// Web 搜索后端（示例：使用 Brave Search / SerpAPI 兼容）
class WebSearchBackend: SearchBackend {
    override init(config: SearchProviderConfig) {
        super.init(config: config)
        self.providerType = .web
    }
    
    override func search(query: String, options: SearchOptions) async throws -> [SearchResult] {
        // 示例：使用 Brave Search API 格式
        var components = URLComponents(url: config.baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: String(options.maxResults)),
            URLQueryItem(name: "safesearch", value: options.safeSearch ? "moderate" : "off")
        ]
        if let lang = options.language { components.queryItems?.append(URLQueryItem(name: "lang", value: lang)) }
        if let region = options.region { components.queryItems?.append(URLQueryItem(name: "country", value: region)) }
        
        var request = buildRequest(url: components.url!, query: query, options: options)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "WebSearch", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: nil)
        }
        
        // 解析 Brave Search / SerpAPI 格式
        struct BraveResponse: Codable { let web: WebResults?; let results: [BraveResult]? }
        struct WebResults: Codable { let results: [BraveResult] }
        struct BraveResult: Codable { let title: String; let description: String; let url: String; let age: String? }
        
        if let resp = try? JSONDecoder().decode(BraveResponse.self, from: data),
           let results = resp.web?.results ?? resp.results {
            return results.prefix(config.defaultOptions.maxResults).map { r in
                SearchResult(id: UUID(), title: r.title, snippet: r.description, url: r.url, source: name, timestamp: Date())
            }
        }
        return []
    }
}

/// 新闻搜索后端
class NewsSearchBackend: SearchBackend {
    override init(config: SearchProviderConfig) {
        super.init(config: config)
        self.providerType = .news
    }
    
    override func search(query: String, options: SearchOptions) async throws -> [SearchResult] {
        var components = URLComponents(url: config.baseURL.appendingPathComponent("news"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: String(options.maxResults)),
            URLQueryItem(name: "freshness", value: "week")
        ]
        if let lang = options.language { components.queryItems?.append(URLQueryItem(name: "lang", value: lang)) }
        if let region = options.region { components.queryItems?.append(URLQueryItem(name: "country", value: region)) }
        
        var request = buildRequest(url: components.url!, query: query, options: options)
        request.httpMethod = "GET"
        
        let (data, _) = try await session.data(for: request)
        struct NewsResponse: Codable { let results: [NewsResult] }
        struct NewsResult: Codable { let title: String; let description: String; let url: String; let age: String?; let source: String? }
        
        if let resp = try? JSONDecoder().decode(NewsResponse.self, from: data) {
            return resp.results.prefix(config.defaultOptions.maxResults).map { r in
                SearchResult(id: UUID(), title: r.title, snippet: r.description, url: r.url, source: r.source ?? name, timestamp: Date())
            }
        }
        return []
    }
}

/// 图片搜索后端
class ImageSearchBackend: SearchBackend {
    override init(config: SearchProviderConfig) {
        super.init(config: config)
        self.providerType = .images
    }
    
    override func search(query: String, options: SearchOptions) async throws -> [SearchResult] {
        var components = URLComponents(url: config.baseURL.appendingPathComponent("images"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: String(options.maxResults)),
            URLQueryItem(name: "safesearch", value: options.safeSearch ? "moderate" : "off")
        ]
        if let lang = options.language { components.queryItems?.append(URLQueryItem(name: "lang", value: lang)) }
        
        var request = buildRequest(url: components.url!, query: query, options: options)
        request.httpMethod = "GET"
        
        let (data, _) = try await session.data(for: request)
        struct ImageResponse: Codable { let results: [ImageResult] }
        struct ImageResult: Codable { let title: String; let url: String; let thumbnail: String?; let source: String? }
        
        if let resp = try? JSONDecoder().decode(ImageResponse.self, from: data) {
            return resp.results.prefix(config.defaultOptions.maxResults).map { r in
                SearchResult(id: UUID(), title: r.title, snippet: r.thumbnail ?? r.url, url: r.url, source: r.source ?? name, timestamp: Date())
            }
        }
        return []
    }
}

/// 深度搜索后端
class DeepSearchBackend: SearchBackend {
    override init(config: SearchProviderConfig) {
        super.init(config: config)
        self.providerType = .deep
    }
    
    override func search(query: String, options: SearchOptions) async throws -> [SearchResult] {
        // 深度搜索通常需要更复杂的流程（多轮搜索、总结等），这里简化实现
        var components = URLComponents(url: config.baseURL.appendingPathComponent("deep"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "depth", value: "comprehensive")
        ]
        
        var request = buildRequest(url: components.url!, query: query, options: options)
        request.httpMethod = "GET"
        
        let (data, _) = try await session.data(for: request)
        struct DeepResponse: Codable { let results: [DeepResult] }
        struct DeepResult: Codable { let title: String; let summary: String; let url: String; let sources: [String]? }
        
        if let resp = try? JSONDecoder().decode(DeepResponse.self, from: data) {
            return resp.results.prefix(config.defaultOptions.maxResults).map { r in
                SearchResult(id: UUID(), title: r.title, snippet: r.summary, url: r.url, source: name, timestamp: Date())
            }
        }
        return []
    }
}

/// 自定义搜索后端
class CustomSearchBackend: SearchBackend {
    override init(config: SearchProviderConfig) {
        super.init(config: config)
        self.providerType = .custom
    }
    
    override func search(query: String, options: SearchOptions) async throws -> [SearchResult] {
        // 自定义搜索：用户可配置请求模板
        var components = URLComponents(url: config.baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(options.maxResults))
        ]
        
        var request = buildRequest(url: components.url!, query: query, options: options)
        request.httpMethod = "GET"
        
        let (data, _) = try await session.data(for: request)
        // 尝试通用解析
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let results = json["results"] as? [[String: Any]] {
            return results.prefix(config.defaultOptions.maxResults).compactMap { dict in
                guard let title = dict["title"] as? String,
                      let snippet = dict["snippet"] as? String,
                      let url = dict["url"] as? String else { return nil }
                return SearchResult(id: UUID(), title: title, snippet: snippet, url: url, source: name, timestamp: Date())
            }
        }
        return []
    }
}