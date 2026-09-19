import SwiftUI

/// Provider 配置视图
struct RelayProviderConfigView: View {
    @ObservedObject var providerManager: ProviderManager
    @Environment(\.dismiss) var dismiss
    @State private var showingAddProvider = false
    @State private var editingProvider: ProviderConfig?
    
    var body: some View {
        NavigationView {
            List {
                if providerManager.providers.isEmpty {
                    EmptyStateView(
                        title: "暂无模型提供商",
                        systemImage: "cpu",
                        description: "添加你的第一个 AI 模型提供商"
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(providerManager.providers) { provider in
                        ProviderRow(
                            provider: provider,
                            isSelected: providerManager.selectedProviderID == provider.id,
                            onTap: { providerManager.selectProvider(id: provider.id) },
                            onEdit: { editingProvider = provider },
                            onDelete: { providerManager.removeProvider(id: provider.id) },
                            onToggle: { providerManager.updateProvider(ProviderConfig(
                                id: provider.id,
                                name: provider.name,
                                providerType: provider.providerType,
                                baseURL: provider.baseURL,
                                apiKey: provider.apiKey,
                                authType: provider.authType,
                                customHeaders: provider.customHeaders,
                                enabled: !provider.enabled,
                                defaultModel: provider.defaultModel,
                                customModels: provider.customModels
                            ))}
                        )
                    }
                }
            }
            .navigationTitle("模型提供商")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddProvider = true } label: {
                        Label("添加", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProvider) {
                AddProviderView(providerManager: providerManager)
            }
            .sheet(item: $editingProvider) { provider in
                EditProviderView(providerManager: providerManager, provider: provider)
            }
        }
        .frame(width: 500, height: 500)
    }
}

struct ProviderRow: View {
    let provider: ProviderConfig
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void
    @State private var showMenu = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: provider.providerType.icon)
                .font(.title3)
                .foregroundStyle(provider.providerType.color)
                .frame(width: 36, height: 36)
                .background(provider.providerType.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(provider.name)
                        .font(.body.weight(.medium))
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                    if !provider.enabled {
                        Text("已禁用")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 10) {
                    Label(provider.providerType.displayName, systemImage: "tag")
                    if let model = provider.defaultModel {
                        Label(model, systemImage: "cpu")
                    }
                    if provider.providerType.isLocal {
                        Label("本地", systemImage: "desktopcomputer")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { provider.enabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            
            Menu {
                Button("设为默认", action: onTap)
                Button("编辑", action: onEdit)
                Divider()
                Button("删除", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isSelected { onTap() }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : .clear)
        )
    }
}

struct AddProviderView: View {
    @ObservedObject var providerManager: ProviderManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var providerType: ProviderType = .openai
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var authType: AuthType = .bearer
    @State private var defaultModel = ""
    @State private var customHeaders = ""
    @State private var showCustomHeaders = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("名称", text: $name)
                    Picker("提供商类型", selection: $providerType) {
                        ForEach(ProviderType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    TextField("Base URL", text: $baseURL).autocorrectionDisabled()
                    
                    TextField("默认模型 (可选)", text: $defaultModel)
                }
                
                Section("认证") {
                    Picker("认证方式", selection: $authType) {
                        ForEach(AuthType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if authType != .none {
                        SecureField("API Key", text: $apiKey)
                    }
                    
                    Toggle("自定义请求头", isOn: $showCustomHeaders)
                    if showCustomHeaders {
                        TextEditor(text: $customHeaders)
                            .frame(height: 80)
                            .font(.system(.caption, design: .monospaced))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                    }
                }
                
                Section {
                    Button("添加") {
                        let config = ProviderConfig(
                            name: name,
                            providerType: providerType,
                            baseURL: baseURL,
                            apiKey: apiKey.isEmpty ? nil : apiKey,
                            authType: authType,
                            customHeaders: showCustomHeaders ? parseHeaders(customHeaders) : nil,
                            enabled: true,
                            defaultModel: defaultModel.isEmpty ? nil : defaultModel
                        )
                        providerManager.addProvider(config)
                        dismiss()
                    }
                    .disabled(name.isEmpty || baseURL.isEmpty || (authType != .none && apiKey.isEmpty))
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("添加提供商")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .frame(width: 450, height: 550)
    }
    
    private func parseHeaders(_ text: String) -> [String: String] {
        var dict: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 { dict[parts[0]] = parts[1] }
        }
        return dict
    }
}

struct EditProviderView: View {
    @ObservedObject var providerManager: ProviderManager
    let provider: ProviderConfig
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var baseURL: String
    @State private var apiKey: String
    @State private var authType: AuthType
    @State private var defaultModel: String
    @State private var customHeaders: String
    @State private var showCustomHeaders: Bool
    @State private var enabled: Bool
    
    init(providerManager: ProviderManager, provider: ProviderConfig) {
        self.providerManager = providerManager
        self.provider = provider
        _name = State(initialValue: provider.name)
        _baseURL = State(initialValue: provider.baseURL)
        _apiKey = State(initialValue: provider.apiKey ?? "")
        _authType = State(initialValue: provider.authType)
        _defaultModel = State(initialValue: provider.defaultModel ?? "")
        _customHeaders = State(initialValue: provider.customHeaders?.map { "\($0.key): \($0.value)" }.joined(separator: "\n") ?? "")
        _showCustomHeaders = State(initialValue: provider.customHeaders != nil)
        _enabled = State(initialValue: provider.enabled)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("名称", text: $name)
                    Text("类型: \(provider.providerType.displayName)").font(.caption).foregroundStyle(.secondary)
                    TextField("Base URL", text: $baseURL).autocorrectionDisabled()
                    TextField("默认模型 (可选)", text: $defaultModel)
                }
                
                Section("认证") {
                    Picker("认证方式", selection: $authType) {
                        ForEach(AuthType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if authType != .none {
                        SecureField("API Key (留空保持不变)", text: $apiKey)
                    }
                    
                    Toggle("自定义请求头", isOn: $showCustomHeaders)
                    if showCustomHeaders {
                        TextEditor(text: $customHeaders)
                            .frame(height: 80)
                            .font(.system(.caption, design: .monospaced))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                    }
                }
                
                Section {
                    Toggle("启用", isOn: $enabled)
                    Button("保存") {
                        var updated = provider
                        updated.name = name
                        updated.baseURL = baseURL
                        updated.apiKey = apiKey.isEmpty ? provider.apiKey : apiKey
                        updated.authType = authType
                        updated.defaultModel = defaultModel.isEmpty ? nil : defaultModel
                        updated.customHeaders = showCustomHeaders ? parseHeaders(customHeaders) : nil
                        updated.enabled = enabled
                        providerManager.updateProvider(updated)
                        dismiss()
                    }
                    .disabled(name.isEmpty || baseURL.isEmpty)
                    .frame(maxWidth: .infinity)
                    
                    Button("删除", role: .destructive) {
                        providerManager.removeProvider(id: provider.id)
                        dismiss()
                    }
                }
            }
            .navigationTitle("编辑提供商")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .frame(width: 450, height: 550)
    }
    
    private func parseHeaders(_ text: String) -> [String: String] {
        var dict: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 { dict[parts[0]] = parts[1] }
        }
        return dict
    }
}

// ProviderType 扩展
extension ProviderType {
    var icon: String {
        switch self {
        case .openai: return "brain"
        case .google: return "sparkles"
        case .groq: return "bolt"
        case .deepseek: return "magnifyingglass"
        case .anthropic: return "quote.bubble"
        case .openaiCompatible: return "link"
        case .custom: return "gear"
        case .mlx: return "cpu"
        case .llamaCpp: return "terminal"
        case .ollama: return "server.rack"
        case .lmStudio: return "macwindow"
        case .mlc: return "microchip"
        case .localOther: return "desktopcomputer"
        }
    }
    
    var color: Color {
        switch self {
        case .openai: return .green
        case .google: return .blue
        case .groq: return .orange
        case .deepseek: return .purple
        case .anthropic: return .orange
        case .openaiCompatible: return .cyan
        case .custom: return .gray
        case .mlx: return .mint
        case .llamaCpp: return .brown
        case .ollama: return .indigo
        case .lmStudio: return .teal
        case .mlc: return .pink
        case .localOther: return .gray
        }
    }
    
    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .google: return "Google (Gemini)"
        case .groq: return "Groq"
        case .deepseek: return "DeepSeek"
        case .anthropic: return "Anthropic (Claude)"
        case .openaiCompatible: return "OpenAI 兼容"
        case .custom: return "自定义"
        case .mlx: return "MLX"
        case .llamaCpp: return "llama.cpp"
        case .ollama: return "Ollama"
        case .lmStudio: return "LM Studio"
        case .mlc: return "MLC"
        case .localOther: return "其他本地"
        }
    }
    
    var isLocal: Bool {
        switch self {
        case .mlx, .llamaCpp, .ollama, .lmStudio, .mlc, .localOther: return true
        default: return false
        }
    }
}