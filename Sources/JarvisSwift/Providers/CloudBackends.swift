import Foundation

/// OpenAI 兼容后端基类
class OpenAICompatibleBackend: ModelBackend {
    let name: String
    var providerType: ProviderType
    let supportedCapabilities: [Capability]
    private let config: ProviderConfig
    private let session: URLSession
    
    init(config: ProviderConfig) {
        self.name = config.name
        self.providerType = config.providerType
        self.config = config
        self.supportedCapabilities = [.chat, .toolCalling, .streaming]
        self.session = URLSession.shared
    }
    
    func models() async throws -> [Model] {
        let url = config.baseURL.appendingPathComponent("models")
        var request = URLRequest(url: url)
        addAuthHeaders(&request)
        let (data, _) = try await session.data(for: request)
        // 解析 OpenAI 格式模型列表
        struct ModelsResponse: Codable { let data: [ModelData] }
        struct ModelData: Codable { let id: String; let object: String }
        let resp = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return resp.data.map { Model(id: $0.id, name: $0.id, provider: config.name, capabilities: supportedCapabilities, contextWindow: nil, maxTokens: nil) }
    }
    
    func chat(
        messages: [Message],
        attachments: [Attachment],
        tools: [Tool]?,
        options: ChatOptions
    ) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        let url = config.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建请求体
        var body: [String: Any] = [
            "model": config.defaultModel ?? "gpt-3.5-turbo",
            "messages": messages.map { msg in
                var m: [String: Any] = ["role": msg.role.rawValue, "content": msg.content]
                if let toolCalls = msg.toolCalls { m["tool_calls"] = toolCalls.map { ["id": $0.id, "type": "function", "function": ["name": $0.name, "arguments": $0.arguments]] } }
                if let toolCallId = msg.toolCallId { m["tool_call_id"] = toolCallId }
                return m
            },
            "temperature": options.temperature ?? 0.7,
            "top_p": options.topP ?? 1.0,
            "stream": options.stream
        ]
        if let maxTokens = options.maxTokens { body["max_tokens"] = maxTokens }
        if let stop = options.stop { body["stop"] = stop }
        if let tools = tools, !tools.isEmpty { body["tools"] = tools.map { t in ["type": "function", "function": ["name": t.name, "description": t.description, "parameters": t.parameters]] } }
        if let systemPrompt = options.systemPrompt {
            body["messages"] = [["role": "system", "content": systemPrompt]] + (body["messages"] as! [[String: Any]])
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (asyncBytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "ModelBackend", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: nil)
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                var buffer = ""
                for try await byte in asyncBytes {
                    buffer.append(Character(UnicodeScalar(byte)))
                    let lines = buffer.components(separatedBy: "\n")
                    buffer = lines.last ?? ""
                    for line in lines.dropLast() {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("data: "), let data = trimmed.dropFirst(6).data(using: .utf8) {
                            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let delta = choices.first?["delta"] as? [String: Any] {
                                if let content = delta["content"] as? String, !content.isEmpty {
                                    continuation.yield(.token(content))
                                }
                                if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                                    for tc in toolCalls {
                                        if let funcDict = tc["function"] as? [String: String],
                                           let name = funcDict["name"], let args = funcDict["arguments"] {
                                            continuation.yield(.toolCall(ToolCall(id: tc["id"] as? String ?? UUID().uuidString, name: name, arguments: args)))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                continuation.yield(.complete(Response(id: UUID().uuidString, model: config.defaultModel ?? "", content: "", toolCalls: nil, usage: nil, finishReason: "stop")))
                continuation.finish()
            }
        }
    }
    
    func supports(_ capability: Capability) -> Bool {
        supportedCapabilities.contains(capability)
    }
    
    private func addAuthHeaders(_ request: inout URLRequest) {
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

/// Google (Gemini) 后端
class GoogleBackend: ModelBackend {
    let name: String
    let providerType: ProviderType = .google
    let supportedCapabilities: [Capability] = [.chat, .vision, .streaming]
    private let config: ProviderConfig
    private let session: URLSession
    
    init(config: ProviderConfig) {
        self.name = config.name
        self.config = config
        self.session = URLSession.shared
    }
    
    func models() async throws -> [Model] {
        // Google 通过 generateContent 列出模型，这里返回默认
        return [Model(id: "gemini-pro", name: "Gemini Pro", provider: name, capabilities: supportedCapabilities, contextWindow: 32768, maxTokens: 8192)]
    }
    
    func chat(messages: [Message], attachments: [Attachment], tools: [Tool]?, options: ChatOptions) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        // 简化实现，实际需适配 Gemini API
        return AsyncThrowingStream { continuation in
            continuation.yield(.complete(Response(id: UUID().uuidString, model: "gemini-pro", content: "[Google backend placeholder]", toolCalls: nil, usage: nil, finishReason: "stop")))
            continuation.finish()
        }
    }
    
    func supports(_ capability: Capability) -> Bool { supportedCapabilities.contains(capability) }
}

/// Anthropic (Claude) 后端
class AnthropicBackend: ModelBackend {
    let name: String
    let providerType: ProviderType = .anthropic
    let supportedCapabilities: [Capability] = [.chat, .toolCalling, .streaming]
    private let config: ProviderConfig
    private let session: URLSession
    
    init(config: ProviderConfig) {
        self.name = config.name
        self.config = config
        self.session = URLSession.shared
    }
    
    func models() async throws -> [Model] {
        return [Model(id: "claude-3-opus", name: "Claude 3 Opus", provider: name, capabilities: supportedCapabilities, contextWindow: 200000, maxTokens: 4096)]
    }
    
    func chat(messages: [Message], attachments: [Attachment], tools: [Tool]?, options: ChatOptions) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        // Anthropic API 实现省略
        return AsyncThrowingStream { continuation in
            continuation.yield(.complete(Response(id: UUID().uuidString, model: "claude-3-opus", content: "[Anthropic backend placeholder]", toolCalls: nil, usage: nil, finishReason: "stop")))
            continuation.finish()
        }
    }
    
    func supports(_ capability: Capability) -> Bool { supportedCapabilities.contains(capability) }
}

/// Groq 后端（OpenAI 兼容）
class GroqBackend: OpenAICompatibleBackend {
    override init(config: ProviderConfig) {
        super.init(config: config)
        self.providerType = .groq
    }
}

/// DeepSeek 后端（OpenAI 兼容）
class DeepSeekBackend: OpenAICompatibleBackend {
    override init(config: ProviderConfig) {
        super.init(config: config)
        self.providerType = .deepseek
    }
}