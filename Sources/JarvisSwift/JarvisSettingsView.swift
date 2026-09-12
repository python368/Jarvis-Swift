import SwiftUI

struct JarvisSettingsView: View {
    @ObservedObject var theme: JarvisTheme
    @ObservedObject var memoryStore: MemoryStore
    @Environment(\.dismiss) var dismiss
    @State private var showMemoryList = false
    @State private var showClearConfirm = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("外观") {
                    Picker("主题", selection: $theme.appearance) {
                        ForEach(JarvisAppearance.allCases, id: \.self) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text("强调色")
                        Spacer()
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 32))], spacing: 8) {
                            ForEach(JarvisAccentColor.allCases, id: \.self) { item in
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(theme.accent == item ? 1 : 0), lineWidth: 2)
                                    )
                                    .onTapGesture {
                                        theme.accent = item
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                
                Section("模型") {
                    HStack {
                        Text("当前 Provider")
                        Spacer()
                        Text("未配置")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("当前模型")
                        Spacer()
                        Text("未选择")
                            .foregroundStyle(.secondary)
                    }
                    Text("可在后续版本中添加或切换模型 Provider。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("记忆") {
                    Toggle("启用长期记忆", isOn: $memoryStore.isEnabled)
                    Toggle("暂停记忆", isOn: $memoryStore.isPaused)
                    
                    HStack {
                        Text("记忆条目")
                        Spacer()
                        Text("\(memoryStore.memories.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("对话数量")
                        Spacer()
                        Text("\(memoryStore.conversations.count)")
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("查看记忆列表") {
                        showMemoryList = true
                    }
                    
                    Button("清空全部记忆") {
                        showClearConfirm = true
                    }
                    .foregroundStyle(.red)
                }
                
                Section {
                    Button("完成", role: .cancel) {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showMemoryList) {
                MemoryListView(memoryStore: memoryStore)
            }
            .alert("确认清空全部记忆？", isPresented: $showClearConfirm) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) {
                    memoryStore.clearAll()
                }
            } message: {
                Text("将删除所有对话历史和长期记忆，此操作不可撤销。")
            }
        }
    }
}

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
                    Button("完成") {
                        dismiss()
                    }
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

struct JarvisSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        JarvisSettingsView(theme: JarvisTheme(), memoryStore: MemoryStore.shared)
    }
}