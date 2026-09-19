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

struct RelaySettingsView: View {
    @ObservedObject var theme: RelayTheme
    @ObservedObject var memoryStore: MemoryStore
    @ObservedObject var providerManager: ProviderManager
    @ObservedObject var searchManager: SearchManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showMemoryList = false
    @State private var showClearConfirm = false
    @State private var showExportSheet = false
    @State private var exportData: Data?
    @State private var showImportPicker = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Tab 1: 外观与个性化
                AppearanceSettingsView(theme: theme)
                    .tabItem { Label("外观", systemImage: "paintbrush") }
                    .tag(0)
                
                // Tab 2: 模型提供商
                ProviderSettingsView(providerManager: providerManager)
                    .tabItem { Label("模型", systemImage: "cpu") }
                    .tag(1)
                
                // Tab 3: 搜索引擎
                SearchSettingsView(searchManager: searchManager)
                    .tabItem { Label("搜索", systemImage: "magnifyingglass") }
                    .tag(2)
                
                // Tab 4: 记忆管理
                MemorySettingsView(memoryStore: memoryStore)
                    .tabItem { Label("记忆", systemImage: "brain") }
                    .tag(3)
                
                // Tab 5: 隐私与数据
                PrivacyDataView(memoryStore: memoryStore)
                    .tabItem { Label("隐私", systemImage: "lock.shield") }
                    .tag(4)
                
                // Tab 6: 关于
                AboutView()
                    .tabItem { Label("关于", systemImage: "info.circle") }
                    .tag(5)
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .frame(width: 600, height: 550)
    }
}

// MARK: - 外观设置
struct AppearanceSettingsView: View {
    @ObservedObject var theme: RelayTheme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Form {
            Section("主题模式") {
                Picker("外观", selection: $theme.appearance) {
                    ForEach(RelayAppearance.allCases, id: \.self) { item in
                        Label(item.label, systemImage: item.icon).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("强调色") {
                VStack(alignment: .leading, spacing: 12) {
                    // 预设色
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 12) {
                        ForEach(RelayAccentColor.allCases.filter { !$0.isCustom }, id: \.self) { accent in
                            AccentColorPicker(accent: accent, selected: theme.accent, customColor: theme.customAccentColor) {
                                theme.accent = accent
                                if accent.isCustom {
                                    theme.customAccentColor = accent.color
                                }
                            }
                        }
                    }
                    
                    // 自定义色
                    if theme.accent.isCustom {
                        ColorPicker("自定义颜色", selection: $theme.customAccentColor, supportsOpacity: false)
                            .padding(.top, 8)
                    }
                }
            }
            
            Section("动效与透明度") {
                Picker("动效模式", selection: $theme.motion) {
                    ForEach(MotionPreference.allCases, id: \.self) { item in
                        Label(item.label, systemImage: item.icon).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                
                Toggle("减少透明度", isOn: $theme.reduceTransparency)
            }
            
            Section("实时预览") {
                ThemePreviewCard(theme: theme)
            }
        }
    }
}

// MARK: - 模型提供商设置
struct ProviderSettingsView: View {
    @ObservedObject var providerManager: ProviderManager
    @State private var showingAddProvider = false
    @State private var editingProvider: ProviderConfig?
    
    var body: some View {
        Form {
            Section {
                if providerManager.providers.isEmpty {
                    EmptyStateView(
                        title: "暂无模型提供商",
                        systemImage: "cpu",
                        description: "添加 AI 模型提供商以启用 AI 对话功能"
                    )
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ForEach(providerManager.providers) { provider in
                        ProviderSettingsRow(
                            provider: provider,
                            isSelected: providerManager.selectedProviderID == provider.id,
                            onSelect: { providerManager.selectProvider(id: provider.id) },
                            onEdit: { editingProvider = provider },
                            onDelete: { providerManager.removeProvider(id: provider.id) },
                            onToggle: { providerManager.updateProvider(ProviderConfig(
                                id: provider.id, name: provider.name, providerType: provider.providerType,
                                baseURL: provider.baseURL, apiKey: provider.apiKey, authType: provider.authType,
                                customHeaders: provider.customHeaders, enabled: !provider.enabled,
                                defaultModel: provider.defaultModel, customModels: provider.customModels
                            ))}
                        )
                    }
                }
            } header: {
                HStack {
                    Text("已配置提供商")
                    Spacer()
                    Button { showingAddProvider = true } label: { Label("添加", systemImage: "plus") }
                }
            }
            
            Section("默认模型配置") {
                if let provider = providerManager.selectedProvider {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: provider.providerType.icon)
                                .foregroundStyle(provider.providerType.color)
                            Text(provider.name)
                                .font(.headline)
                            if let model = provider.defaultModel {
                                Text(model).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        
                        if provider.providerType.isLocal {
                            Text("本地模型运行在你的设备上，数据不出本机")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text("云端模型：你的 API Key 直接调用指定 Endpoint，不经过任何中转")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("请先添加并选择一个提供商")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { editingProvider != nil },
            set: { if !$0 { editingProvider = nil } }
        )) {
            if let provider = editingProvider {
                EditProviderView(providerManager: ProviderManager(), provider: provider)
            }
        }
    }
}

struct ProviderSettingsRow: View {
    let provider: ProviderConfig
    let isSelected: Bool
    let onSelect: () -> Void
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
                Button("设为默认", action: onSelect)
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
            if !isSelected { onSelect() }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : .clear)
        )
    }
}

// MARK: - 搜索设置
struct SearchSettingsView: View {
    @ObservedObject var searchManager: SearchManager
    @State private var showingAddProvider = false
    @State private var editingProvider: SearchProviderConfig?
    
    var body: some View {
        Form {
            Section {
if searchManager.providers.isEmpty {
                    EmptyStateView(
                        title: "暂无搜索引擎",
                        systemImage: "magnifyingglass",
                        description: "添加搜索提供商以启用联网搜索"
                    )
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ForEach(searchManager.providers) { provider in
                        SearchProviderSettingsRow(
                            provider: provider,
                            isSelected: searchManager.selectedProviderID == provider.id,
                            onSelect: { searchManager.selectProvider(id: provider.id) },
                            onEdit: { editingProvider = provider },
                            onDelete: { searchManager.removeProvider(id: provider.id) },
                            onToggle: { searchManager.updateProvider(SearchProviderConfig(
                                id: provider.id, name: provider.name, providerType: provider.providerType,
                                baseURL: provider.baseURL, apiKey: provider.apiKey, authType: provider.authType,
                                customHeaders: provider.customHeaders, enabled: !provider.enabled,
                                defaultOptions: provider.defaultOptions
                            ))}
                        )
                    }
                }
            } header: {
                HStack {
                    Text("已配置搜索引擎")
                    Spacer()
                    Button { showingAddProvider = true } label: { Label("添加", systemImage: "plus") }
                }
            }
            
            Section("当前默认引擎") {
                if let provider = searchManager.selectedProvider {
                    HStack {
                        Image(systemName: provider.providerType.icon)
                            .foregroundStyle(provider.providerType.color)
                        VStack(alignment: .leading) {
                            Text(provider.name).font(.headline)
                            Text("\(provider.providerType.displayName) · 最多 \(provider.defaultOptions.maxResults) 条")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("请先添加并选择一个搜索引擎")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { editingProvider != nil },
            set: { if !$0 { editingProvider = nil } }
        )) {
            if let provider = editingProvider {
                EditSearchProviderView(searchManager: SearchManager(), provider: provider)
            }
        }
    }
}

struct SearchProviderSettingsRow: View {
    let provider: SearchProviderConfig
    let isSelected: Bool
    let onSelect: () -> Void
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
                    Label("最多 \(provider.defaultOptions.maxResults) 条", systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { provider.enabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            
            Menu {
                Button("设为默认", action: onSelect)
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
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isSelected { onSelect() }
        }
    }
}

// MARK: - 记忆管理
struct MemorySettingsView: View {
    @ObservedObject var memoryStore: MemoryStore
    @State private var showMemoryList = false
    @State private var showClearConfirm = false
    @State private var showExportSheet = false
    @State private var exportData: Data?
    @State private var showImportPicker = false
    
    var body: some View {
        Form {
            Section("记忆开关") {
                Toggle("启用长期记忆", isOn: $memoryStore.isEnabled)
                Toggle("暂停记忆记录", isOn: $memoryStore.isPaused)
                    .help("暂停后不再记录新的长期记忆，但当前对话仍可正常进行")
            }
            
            Section("统计信息") {
                HStack {
                    Text("长期记忆条目")
                    Spacer()
                    Text("\(memoryStore.memories.count)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("历史对话数量")
                    Spacer()
                    Text("\(memoryStore.conversations.count)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("存储大小")
                    Spacer()
                    Text(formatBytes(memoryStore.estimatedStorageSize))
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("管理操作") {
                Button("查看记忆列表") { showMemoryList = true }
                Button("导出记忆数据") { exportMemory() }
                Button("导入记忆数据") { showImportPicker = true }
                Button("清空全部记忆", role: .destructive) { showClearConfirm = true }
            }
            
            Section("说明") {
                Text("记忆独立于模型：更换模型、Provider、本地/云端切换，记忆始终保留。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("关闭记忆后：不使用全局长期记忆、不注入跨对话记忆，但当前对话仍正常工作。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showMemoryList) {
            MemoryListView(memoryStore: memoryStore)
        }
        .alert("确认清空全部记忆？", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) { memoryStore.clearAll() }
        } message: {
            Text("将删除所有对话历史和长期记忆，此操作不可撤销。")
        }
        .fileExporter(isPresented: $showExportSheet, document: MemoryExportDocument(data: exportData ?? Data()), contentType: .json, defaultFilename: "RelayMemory_\(Date().formatted(date: .numeric, time: .omitted)).json") { _ in }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first,
               let data = try? Data(contentsOf: url) {
                MemoryStore.shared.importData(data)
            }
        }
        .alert("确认清空全部记忆？", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) { memoryStore.clearAll() }
        } message: {
            Text("将删除所有对话历史和长期记忆，此操作不可撤销。")
        }
    }
    
    private func exportMemory() {
        if let data = memoryStore.exportData() {
            exportData = data
            showExportSheet = true
        }
    }
    
    // 格式化字节数
    private func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(bytes)
        var unitIndex = 0
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        return String(format: "%.1f %@", size, units[unitIndex])
    }
}

// MARK: - 隐私与数据
struct PrivacyDataView: View {
    @ObservedObject var memoryStore: MemoryStore
    @State private var showExportSheet = false
    @State private var exportData: Data?
    @State private var showImportPicker = false
    @State private var showClearAllConfirm = false
    
    var body: some View {
        Form {
            Section("隐私原则") {
                VStack(alignment: .leading, spacing: 12) {
                    PrivacyPrincipleRow(icon: "cpu", title: "本地优先", desc: "能本地处理就优先本地处理，不偷偷上传数据")
                    PrivacyPrincipleRow(icon: "folder", title: "最小权限", desc: "只读取必要文件，只截取必要窗口")
                    PrivacyPrincipleRow(icon: "network", title: "透明传输", desc: "明确告知哪些数据发送到外部 Provider")
                    PrivacyPrincipleRow(icon: "trash", title: "用户控制", desc: "可随时清理、导出、删除自己的所有数据")
                }
                .padding(.vertical, 8)
            }
            
            Section("数据导出") {
                Button("导出所有数据 (JSON)") { exportAllData() }
                Button("导入数据 (JSON)") { showImportPicker = true }
            }
            
            Section("危险操作") {
                Button("清空所有数据", role: .destructive) { showClearAllConfirm = true }
            }
            
            Section("说明") {
                Text("Relay 尊重你的设备和数据。你的 API Key 直接调用你指定的 Provider，不经过任何中转。本地模型完全运行在你的设备上。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("记忆属于你和 Relay 数据层，不属于任何模型。模型可以换，记忆不能跟着模型一起消失。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .fileExporter(isPresented: $showExportSheet, document: MemoryExportDocument(data: exportData ?? Data()), contentType: .json, defaultFilename: "RelayAllData_\(Date().formatted(date: .numeric, time: .omitted)).json") { _ in }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first,
               let data = try? Data(contentsOf: url) {
                MemoryStore.shared.importData(data)
            }
        }
        .alert("确认清空所有数据？", isPresented: $showClearAllConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                MemoryStore.shared.clearAll()
            }
        } message: {
            Text("将删除所有对话历史、长期记忆、Provider 配置和搜索配置，此操作不可撤销。")
        }
    }
    
    private func exportAllData() {
        // 导出所有数据
    }
}

struct PrivacyPrincipleRow: View {
    let icon: String
    let title: String
    let desc: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 关于页面
struct AboutView: View {
    var body: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    
                    Text("Relay")
                        .font(.title.weight(.bold))
                    Text("版本 0.1.0 (Alpha)")
                        .foregroundStyle(.secondary)
                    
                    Text("一个原生 macOS、开源、模型自由、面向普通用户的 AI Computer Agent。")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            
            Section("核心理念") {
                VStack(alignment: .leading, spacing: 12) {
                    AboutRow(icon: "lightbulb", title: "用户给意图，不给步骤", desc: "你说目标，Relay 负责寻路并完成")
                    AboutRow(icon: "graduationcap", title: "零学习成本", desc: "像普通 Mac App 一样简单，无需懂 Agent、API、Token")
                    AboutRow(icon: "repeat", title: "Observe → Plan → Act → Verify → Recover", desc: "失败不等于任务失败，自动重试换路")
                    AboutRow(icon: "lock", title: "用户拥有最终控制权", desc: "高风险操作需确认，模型/Provider/记忆全由用户决定")
                    AboutRow(icon: "arrow.triangle.2.circlepath", title: "模型自由", desc: "OpenAI/Google/本地/自建/任意兼容后端，不做模型警察")
                    AboutRow(icon: "nosign", title: "不卖模型、不做代理、不做中转", desc: "你的 Key 直连你的 Provider，纯客户端 + Agent Runtime")
                }
            }
            
            Section("技术栈") {
                AboutRow(icon: "swift", title: "Swift / SwiftUI", desc: "原生 macOS 开发")
                AboutRow(icon: "cpu", title: "ScreenCaptureKit + Accessibility + CGEvent", desc: "屏幕观察与操作自动化")
                AboutRow(icon: "cylinder", title: "SwiftData / JSON", desc: "本地持久化存储")
                AboutRow(icon: "network", title: "URLSession + async/await", desc: "现代并发网络层")
            }
            
            Section("开源协议") {
                Link("GitHub 仓库", destination: URL(string: "https://github.com/python368/Relay")!)
                Text("GPL-3.0-only License")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct AboutRow: View {
    let icon: String
    let title: String
    let desc: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 辅助视图组件

struct AccentColorPicker: View {
    let accent: RelayAccentColor
    let selected: RelayAccentColor
    let customColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(accent == .custom ? Color.clear : accent.color)
                    .frame(width: 36, height: 36)
                if accent == .custom {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.3), lineWidth: 2)
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if selected == accent {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 3)
                        .frame(width: 42, height: 42)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct ThemePreviewCard: View {
    @ObservedObject var theme: RelayTheme
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("预览").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
            }
            
            VStack(spacing: 8) {
                // 卡片预览
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle().fill(theme.semanticColors.accent).frame(width: 8, height: 8)
                        Text("Relay 主题预览").font(.caption.weight(.medium))
                        Spacer()
                        Circle().fill(theme.semanticColors.accent).frame(width: 10, height: 10)
                    }
                    Divider()
                    Text("这是主题预览卡片，展示当前配色在卡片、按钮、输入框上的效果。")
                        .font(.caption)
                        .foregroundStyle(theme.semanticColors.secondaryText)
                    
                    HStack(spacing: 8) {
                        Button("主按钮") {}
                            .buttonStyle(PreviewButtonStyle(theme: theme, style: .primary))
                        Button("次要") {}
                            .buttonStyle(PreviewButtonStyle(theme: theme, style: .secondary))
                        Button("幽灵") {}
                            .buttonStyle(PreviewButtonStyle(theme: theme, style: .ghost))
                    }
                }
                .padding()
                .background(theme.semanticColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.semanticColors.divider, lineWidth: 1)
                )
            }
            .padding(.vertical, 8)
        }
    }
}

struct PreviewButtonStyle: ButtonStyle {
    let theme: RelayTheme
    let style: PreviewStyle
    
    enum PreviewStyle { case primary, secondary, ghost }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(backgroundColor(configuration.isPressed))
            )
            .foregroundStyle(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.12, dampingFraction: 0.7), value: configuration.isPressed)
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return theme.semanticColors.accent
        case .ghost: return theme.semanticColors.primaryText
        }
    }
    
    private func backgroundColor(_ pressed: Bool) -> Color {
        let base: Color
        switch style {
        case .primary: base = theme.semanticColors.accent
        case .secondary: base = theme.semanticColors.accent.opacity(0.15)
        case .ghost: base = Color.clear
        }
        return pressed ? base.opacity(0.7) : base
    }
}
    
    // MARK: - 记忆列表视图
    struct MemoryListView: View {
    @ObservedObject var memoryStore: MemoryStore
    @Environment(\.dismiss) var dismiss
    @State private var selectedMemory: MemoryEntry?
    @State private var showDeleteConfirm = false
    @State private var memoryToDelete: MemoryEntry?
    
    var body: some View {
        NavigationView {
            List {
                Section("长期记忆 (\(memoryStore.memories.count))") {
                    if memoryStore.memories.isEmpty {
                        Text("暂无长期记忆")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(memoryStore.memories.sorted { $0.createdAt > $1.createdAt }) { memory in
                            MemoryRow(memory: memory)
                                .onTapGesture {
                                    selectedMemory = memory
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        memoryToDelete = memory
                                        showDeleteConfirm = true
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                
                Section("历史对话 (\(memoryStore.conversations.count))") {
                    if memoryStore.conversations.isEmpty {
                        Text("暂无历史对话")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(memoryStore.conversations.sorted { $0.updatedAt > $1.updatedAt }) { conv in
                            ConversationRow(conversation: conv)
                        }
                    }
                }
            }
            .navigationTitle("记忆管理")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(item: $selectedMemory) { memory in
                MemoryDetailView(memory: memory, memoryStore: memoryStore)
            }
            .alert("删除这条记忆？", isPresented: $showDeleteConfirm, presenting: memoryToDelete) { memory in
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    memoryStore.deleteMemory(id: memory.id)
                }
            } message: { memory in
                Text("确定要删除这条记忆吗？\n\n\(memory.content.prefix(100))...")
            }
        }
    }
}

struct MemoryRow: View {
    let memory: MemoryEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(memory.category.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(4)
                Spacer()
                Text(memory.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(memory.content)
                .lineLimit(2)
                .font(.body)
            HStack {
                Text("重要性: \(Int(memory.importance * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !memory.tags.isEmpty {
                    Text(memory.tags.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(conversation.title)
                    .font(.body)
                    .lineLimit(1)
                Spacer()
                Text(conversation.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(conversation.messages.count) 条消息")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct MemoryDetailView: View {
    let memory: MemoryEntry
    @ObservedObject var memoryStore: MemoryStore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("内容") {
                    Text(memory.content)
                        .textSelection(.enabled)
                }
                
                Section("元数据") {
                    HStack {
                        Text("分类")
                        Spacer()
                        Text(memory.category.rawValue)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("重要性")
                        Spacer()
                        Text("\(Int(memory.importance * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("创建时间")
                        Spacer()
                        Text(memory.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("更新时间")
                        Spacer()
                        Text(memory.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                    if !memory.tags.isEmpty {
                        HStack {
                            Text("标签")
                            Spacer()
                            Text(memory.tags.joined(separator: ", "))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let sourceID = memory.sourceConversationID {
                        HStack {
                            Text("来源对话")
                            Spacer()
                            Text(sourceID.uuidString.prefix(8) + "...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section {
                    Button("删除", role: .destructive) {
                        memoryStore.deleteMemory(id: memory.id)
                        dismiss()
                    }
                }
            }
            .navigationTitle("记忆详情")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

struct RelaySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        RelaySettingsView(
            theme: RelayTheme(),
            memoryStore: MemoryStore.shared,
            providerManager: ProviderManager(),
            searchManager: SearchManager()
        )
    }
}