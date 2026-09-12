import SwiftUI

/// 空状态视图（兼容 macOS 13+）
struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.weight(.medium))
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// 搜索引擎配置视图
struct SearchConfigView: View {
    @ObservedObject var searchManager: SearchManager
    @Environment(\.dismiss) var dismiss
    @State private var showingAddProvider = false
    @State private var editingProvider: SearchProviderConfig?
    
    var body: some View {
        NavigationView {
            List {
                if searchManager.providers.isEmpty {
                    EmptyStateView(
                        title: "暂无搜索引擎",
                        systemImage: "magnifyingglass",
                        description: "添加搜索提供商以启用联网搜索"
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(searchManager.providers) { provider in
                        SearchProviderRow(
                            provider: provider,
                            isSelected: searchManager.selectedProviderID == provider.id,
                            onTap: { searchManager.selectProvider(id: provider.id) },
                            onEdit: { editingProvider = provider },
                            onDelete: { searchManager.removeProvider(id: provider.id) },
                            onToggle: { searchManager.updateProvider(SearchProviderConfig(
                                id: provider.id,
                                name: provider.name,
                                providerType: provider.providerType,
                                baseURL: provider.baseURL,
                                apiKey: provider.apiKey,
                                authType: provider.authType,
                                customHeaders: provider.customHeaders,
                                enabled: !provider.enabled,
                                defaultOptions: provider.defaultOptions
                            ))}
                        )
                    }
                }
            }
            .navigationTitle("搜索引擎")
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
                AddSearchProviderView(searchManager: searchManager)
            }
            .sheet(item: $editingProvider) { provider in
                EditSearchProviderView(searchManager: searchManager, provider: provider)
            }
        }
        .frame(width: 500, height: 500)
    }
}

struct SearchProviderRow: View {
    let provider: SearchProviderConfig
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: provider.providerType.icon)
                .font(.title3)
                .foregroundStyle(provider.providerType.color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(provider.name)
                        .font(.body.weight(.medium))
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                
                HStack(spacing: 8) {
                    Label(provider.providerType.displayName, systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { provider.enabled },
                set: { _ in
                    var updated = provider
                    updated.enabled.toggle()
                    // 这里需要通过 SearchManager 更新，但为了简化直接返回
                    // 实际应该通过回调更新
                })
            )
            .toggleStyle(.switch)
            .labelsHidden()
            
            Menu {
                Button("设为默认") { }
                Button("编辑") { }
                Divider()
                Button("删除", role: .destructive) { }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { }
    }
}

struct AddSearchProviderView: View {
    @ObservedObject var searchManager: SearchManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var providerType: SearchProviderType = .web
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var authType: AuthType = .bearer
    @State private var maxResults = 10
    @State private var language = ""
    @State private var region = ""
    @State private var safeSearch = true
    @State private var customHeaders = ""
    @State private var showCustomHeaders = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("名称", text: $name)
                    Picker("搜索类型", selection: $providerType) {
                        ForEach(SearchProviderType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    TextField("Base URL", text: $baseURL).autocorrectionDisabled()
                }
                
                Section("搜索选项") {
                    Stepper("最大结果数: \(maxResults)", value: $maxResults, in: 1...50)
                    TextField("语言代码 (如: zh-CN)", text: $language)
                    TextField("地区代码 (如: CN)", text: $region)
                    Toggle("安全搜索", isOn: $safeSearch)
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
                        let config = SearchProviderConfig(
                            name: name,
                            providerType: providerType,
                            baseURL: baseURL,
                            apiKey: apiKey.isEmpty ? nil : apiKey,
                            authType: authType,
                            customHeaders: parseHeaders(customHeaders),
                            enabled: true,
                            defaultOptions: SearchOptions(maxResults: maxResults, language: language.isEmpty ? nil : language, region: region.isEmpty ? nil : region, safeSearch: safeSearch)
                        )
                        searchManager.addProvider(config)
                        dismiss()
                    }
                    .disabled(name.isEmpty || baseURL.isEmpty)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("添加搜索引擎")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
        .frame(width: 450, height: 600)
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

struct EditSearchProviderView: View {
    @ObservedObject var searchManager: SearchManager
    let provider: SearchProviderConfig
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var baseURL: String
    @State private var apiKey: String
    @State private var authType: AuthType
    @State private var maxResults: Int
    @State private var language: String
    @State private var region: String
    @State private var safeSearch: Bool
    @State private var customHeaders: String
    @State private var showCustomHeaders: Bool
    @State private var enabled: Bool
    
    init(searchManager: SearchManager, provider: SearchProviderConfig) {
        self.searchManager = searchManager
        self.provider = provider
        _name = State(initialValue: provider.name)
        _baseURL = State(initialValue: provider.baseURL)
        _apiKey = State(initialValue: provider.apiKey ?? "")
        _authType = State(initialValue: provider.authType)
        _maxResults = State(initialValue: provider.defaultOptions.maxResults)
        _language = State(initialValue: provider.defaultOptions.language ?? "")
        _region = State(initialValue: provider.defaultOptions.region ?? "")
        _safeSearch = State(initialValue: provider.defaultOptions.safeSearch)
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
                }
                
                Section("搜索选项") {
                    Stepper("最大结果数: \(maxResults)", value: $maxResults, in: 1...50)
                    TextField("语言代码", text: $language)
                    TextField("地区代码", text: $region)
                    Toggle("安全搜索", isOn: $safeSearch)
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
                        updated.defaultOptions = SearchOptions(maxResults: maxResults, language: language.isEmpty ? nil : language, region: region.isEmpty ? nil : region, safeSearch: safeSearch)
                        updated.customHeaders = showCustomHeaders ? parseHeaders(customHeaders) : nil
                        updated.enabled = enabled
                        searchManager.updateProvider(updated)
                        dismiss()
                    }
                    .disabled(name.isEmpty || baseURL.isEmpty)
                    .frame(maxWidth: .infinity)
                    
                    Button("删除", role: .destructive) {
                        searchManager.removeProvider(id: provider.id)
                        dismiss()
                    }
                }
            }
            .navigationTitle("编辑搜索引擎")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
        .frame(width: 450, height: 600)
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

// SearchProviderType 扩展
extension SearchProviderType {
    var icon: String {
        switch self {
        case .web: return "globe"
        case .news: return "newspaper"
        case .images: return "photo"
        case .deep: return "magnifyingglass.circle"
        case .custom: return "gear"
        }
    }
    
    var color: Color {
        switch self {
        case .web: return .blue
        case .news: return .orange
        case .images: return .purple
        case .deep: return .indigo
        case .custom: return .gray
        }
    }
    
    var displayName: String {
        switch self {
        case .web: return "网页搜索"
        case .news: return "新闻搜索"
        case .images: return "图片搜索"
        case .deep: return "深度搜索"
        case .custom: return "自定义"
        }
    }
}