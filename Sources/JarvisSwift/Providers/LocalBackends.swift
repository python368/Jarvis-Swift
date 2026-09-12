import Foundation

/// 本地后端基类
class LocalBackend: ModelBackend {
    let name: String
    let providerType: ProviderType
    let supportedCapabilities: [Capability]
    let config: ProviderConfig
    let session: URLSession
    
    init(config: ProviderConfig) {
        self.name = config.name
        self.providerType = config.providerType
        self.config = config
        self.session = URLSession.shared
        self.supportedCapabilities = [.chat, .streaming]
    }
    
    func models() async throws -> [Model] {
        let url = config.baseURL.appendingPathComponent("models")
        var request = URLRequest(url: url)
        let (data, _) = try await session.data(for: request)
        // 尝试解析 OpenAI 兼容格式
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataArray = json["data"] as? [[String: Any]] {
            return dataArray.compactMap { dict in
                guard let id = dict["id"] as? String else { return nil }
                return Model(id: id, name: id, provider: name, capabilities: supportedCapabilities, contextWindow: nil, maxTokens: nil)
            }
        }
        // 兜底
        return config.customModels ?? []
    }
    
    func chat(messages: [Message], attachments: [Attachment], tools: [Tool]?, options: ChatOptions) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        let url = config.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "model": config.defaultModel ?? "local-model",
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
        request.httpMethod = "POST"
        
        let (asyncBytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "LocalBackend", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: nil)
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
                continuation.yield(.complete(Response(id: UUID().uuidString, model: config.defaultModel ?? "local", content: "", toolCalls: nil, usage: nil, finishReason: "stop")))
                continuation.finish()
            }
        }
    }
    
    func supports(_ capability: Capability) -> Bool {
        supportedCapabilities.contains(capability)
    }
}

/// MLX 后端
class MLXBackend: LocalBackend {
    override init(config: ProviderConfig) {
        super.init(config: config)
        self.providerType = .mlx
    }
}

/// llama.cpp 后端
class LlamaCppBackend: LocalBackend {
    override init(config: ProviderConfig) {
        super.init(config: config)
        self.providerType = .llamaCpp
    }
}

/// Ollama 后端
class OllamaBackend: LocalBackend {
    override init(config: ProviderConfig) {
        super.init(config: config)
        self.providerType = .ollama
    }
    
    override func models() async throws -> [Model] {
        let url = config.baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        let (data, _) = try await session.data(for: request)
        struct OllamaTags: Codable { let models: [OllamaModel] }
        struct OllamaModel: Codable { let name: String; let size: Int64?; let digest: String? }
        if let tags = try? JSONDecoder().decode(OllamaTags.self, from: data) {
            return tags.models.map { Model(id: $0.name, name: $0.name, provider: name, capabilities: supportedCapabilities, contextWindow: nil, maxTokens: nil) }
        }
        return config.customModels ?? []
    }
    
    override func chat(messages: [Message], attachments: [Attachment], tools: [Tool]?, options: ChatOptions) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        // Ollama 使用 /api/chat 端点
        let url = config.baseURL.appendingPathComponent("api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "model": config.defaultModel ?? "llama2",
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "stream": options.stream,
            "options": ["temperature": options.temperature ?? 0.7, "top_p": options.topP ?? 1.0]
        ]
        if let maxTokens = options.maxTokens { body["options"] = (body["options"] as? [String: Any] ?? [:]).merging(["num_predict": maxTokens]) { $1 } }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.httpMethod = "POST"
        
        let (asyncBytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "OllamaBackend", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: nil)
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                var buffer = ""
                for try await byte in asyncBytes {
                    buffer.append(Character(UnicodeScalar(byte)))
                    let lines = buffer.components(separatedBy: "\n")
                    buffer = lines.last ?? ""
                    for line in lines.dropLast() {
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let message = json["message"] as? [String: Any],
                           let content = message["content"] as? String, !content.isEmpty {
                            continuation.yield(.token(content))
                        }
                    }
                }
                continuation.yield(.complete(Response(id: UUID().uuidString, model: config.defaultModel ?? "ollama", content: "", toolCalls: nil, usage: nil, finishReason: "stop")))
                continuation.finish()
            }
        }
    }
}

/// LM Studio 后端
class LMStudioBackend: LocalBackend {
    override init(config: ProviderConfig) {
        super.init(config: config)
        self.providerType = .lmStudio
    }
}

/// MLC 后端
class MLCBackend: LocalBackend {
    override init(config: ProviderConfig) {
        super.init(config: config)
        self.providerType = .mlc
    }
}

/// 其他本地后端
class LocalOtherBackend: LocalBackend {
    override init(config: ProviderConfig) {
        super.init(config: config)
        self.providerType = .localOther
    }
}