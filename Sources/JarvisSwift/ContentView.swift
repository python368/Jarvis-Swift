import SwiftUI

struct ContentView: View {
    @StateObject private var theme = JarvisTheme()
    @StateObject private var memoryStore = MemoryStore.shared
    @StateObject private var providerManager = ProviderManager()
    @StateObject private var searchManager = SearchManager()
    @StateObject private var automation = AutomationLayer()
    @StateObject private var agentEngine = AgentEngine(
        memoryStore: MemoryStore.shared,
        providerManager: ProviderManager(),
        searchManager: SearchManager(),
        automation: AutomationLayer()
    )
    
    @State private var inputText: String = ""
    @State private var messages: [Message] = []
    @State private var showSettings = false
    @State private var showProviderSheet = false
    @State private var showSearchSheet = false
    @State private var showAgentPanel = false
    @State private var agentGoal: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景层（Layer 4 静态背景 + Layer 3 环境呼吸动画）
                theme.semanticColors.background
                    .ignoresSafeArea()
                    .overlay(
                        BreathingBackground(theme: theme)
                            .opacity(theme.animationConfig.motion == .reduced ? 0 : 0.3)
                    )
                
                VStack(spacing: 0) {
                    // 顶部状态栏
                    TopStatusBar(
                        theme: theme,
                        agentState: agentEngine.state,
                        provider: providerManager.selectedProvider,
                        memoryCount: memoryStore.memories.count,
                        onProviderTap: { showProviderSheet = true },
                        onSearchTap: { showSearchSheet = true },
                        onAgentTap: { showAgentPanel = true }
                    )
                    
                    // 聊天区域
                    ChatView(
                        messages: $messages,
                        theme: theme,
                        memoryStore: memoryStore,
                        agentEngine: agentEngine
                    )
                    
                    // 底部输入栏
                    JarvisComposer(
                        text: $inputText,
                        onSend: sendMessage,
                        accentColor: theme.semanticColors.accent,
                        isProcessing: agentEngine.state == .acting || agentEngine.state == .planning
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showSettings = true } label: { Label("设置", systemImage: "slider.horizontal.3") }
                        Button { showProviderSheet = true } label: { Label("模型提供商", systemImage: "cpu") }
                        Button { showSearchSheet = true } label: { Label("搜索引擎", systemImage: "magnifyingglass") }
                        Divider()
                        Button { showAgentPanel = true } label: { Label("Agent 面板", systemImage: "brain") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundStyle(theme.semanticColors.primaryText)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                JarvisSettingsView(theme: theme, memoryStore: memoryStore, providerManager: providerManager, searchManager: searchManager)
            }
            .sheet(isPresented: $showProviderSheet) {
                ProviderConfigView(providerManager: providerManager)
            }
            .sheet(isPresented: $showSearchSheet) {
                SearchConfigView(searchManager: searchManager)
            }
            .sheet(isPresented: $showAgentPanel) {
                AgentPanelView(agentEngine: agentEngine, goal: $agentGoal)
            }
        }
        .frame(minWidth: 520, minHeight: 400)
        .environmentObject(theme)
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let userMessage = Message(id: UUID(), text: text, isUser: true)
        messages.append(userMessage)
        memoryStore.addMessage(userMessage)
        
        inputText = ""
        
        // 简单回复（后续接入 AgentEngine）
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            let reply = "好的，我正在处理：「\(text)」。"
            let jarvisMessage = Message(id: UUID(), text: reply, isUser: false)
            withAnimation(theme.animationConfig.stateChange) {
                messages.append(jarvisMessage)
                memoryStore.addMessage(jarvisMessage)
            }
        }
    }
}

// MARK: - 子视图

/// 呼吸背景动画（Layer 3 环境动画）
struct BreathingBackground: View {
    @ObservedObject var theme: JarvisTheme
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<3) { i in
                Circle()
                    .fill(theme.semanticColors.accent.opacity(0.03))
                    .frame(width: geo.size.width * 0.8, height: geo.size.height * 0.8)
                    .blur(radius: 80)
                    .scaleEffect(1 + 0.15 * sin(phase + CGFloat(i) * 2.0))
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: theme.animationConfig.backgroundBreathDuration).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}

/// 顶部状态栏
struct TopStatusBar: View {
    @ObservedObject var theme: JarvisTheme
    let agentState: AgentState
    let provider: ProviderConfig?
    let memoryCount: Int
    let onProviderTap: () -> Void
    let onSearchTap: () -> Void
    let onAgentTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Logo / 标题
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(theme.semanticColors.accent)
                    .symbolEffect(.pulse, options: .repeating, value: theme.animationConfig.motion != .reduced)
                Text("Jarvis")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.semanticColors.primaryText)
            }
            
            Divider().frame(height: 24)
            
            // Provider 状态
            Button(action: onProviderTap) {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .foregroundStyle(theme.semanticColors.accent)
                    Text(provider?.name ?? "未配置模型")
                        .font(.caption)
                        .foregroundStyle(theme.semanticColors.secondaryText)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(theme.semanticColors.glassBackground)
                        .overlay(Capsule().stroke(theme.semanticColors.glassBorder, lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            
            Divider().frame(height: 24)
            
            // 记忆计数
            HStack(spacing: 4) {
                Image(systemName: "brain")
                    .font(.caption)
                    .foregroundStyle(theme.semanticColors.accent)
                Text("\(memoryStore.memories.count) 记忆")
                    .font(.caption)
                    .foregroundStyle(theme.semanticColors.tertiaryText)
            }
            
            Spacer()
            
            // Agent 状态指示器
            AgentStateIndicator(state: agentState, theme: theme)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            theme.semanticColors.glassBackground
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(theme.semanticColors.divider),
                    alignment: .bottom
                )
        )
    }
}

/// Agent 状态指示器
struct AgentStateIndicator: View {
    let state: AgentState
    @ObservedObject var theme: JarvisTheme
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(stateColor.opacity(0.5), lineWidth: 2)
                        .scaleEffect(pulseScale)
                        .opacity(pulseOpacity)
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: theme.animationConfig.agentPulseDuration).repeatForever(autoreverses: true)) {
                        pulseScale = 2.0
                        pulseOpacity = 0
                    }
                }
            
            Text(stateText)
                .font(.caption.monospaced())
                .foregroundStyle(theme.semanticColors.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(stateColor.opacity(0.15))
        )
    }
    
    @State private var pulseScale: CGFloat = 1
    @State private var pulseOpacity: Double = 1
    
    var stateColor: Color {
        switch state {
        case .idle: return theme.semanticColors.tertiaryText
        case .observing: return .blue
        case .planning: return .purple
        case .acting: return theme.semanticColors.accent
        case .verifying: return .orange
        case .recovering: return .red
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    var stateText: String {
        switch state {
        case .idle: return "就绪"
        case .observing: return "观察中"
        case .planning: return "规划中"
        case .acting: return "执行中"
        case .verifying: return "验证中"
        case .recovering: return "恢复中"
        case .completed: return "完成"
        case .failed: return "失败"
        }
    }
}

/// 聊天视图
struct ChatView: View {
    @Binding var messages: [Message]
    @ObservedObject var theme: JarvisTheme
    let memoryStore: MemoryStore
    let agentEngine: AgentEngine
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if messages.isEmpty {
                        EmptyStateView(theme: theme)
                            .id("empty")
                    } else {
                        ForEach(messages) { message in
                            MessageBubble(message: message, theme: theme)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity).animation(theme.animationConfig.listInsertion),
                                    removal: .scale(scale: 0.9).combined(with: .opacity).animation(theme.animationConfig.listRemoval)
                                ))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) { _ in
                withAnimation(theme.animationConfig.stateChange) {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

/// 空状态视图
struct EmptyStateView: View {
    @ObservedObject var theme: JarvisTheme
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(colors: [theme.semanticColors.accent, theme.semanticColors.accent.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .symbolEffect(.pulse, options: .repeating, value: theme.animationConfig.motion != .reduced)
            
            VStack(spacing: 8) {
                Text("你好，我是 Jarvis")
                    .font(.title.weight(.medium))
                    .foregroundStyle(theme.semanticColors.primaryText)
                Text("告诉我你的目标，剩下的交给我")
                    .font(.body)
                    .foregroundStyle(theme.semanticColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                ExampleChip(text: "把桌面整理一下", theme: theme)
                ExampleChip(text: "打开 Final Cut，导入刚才的视频", theme: theme)
                ExampleChip(text: "帮我搜索最新的 AI 论文", theme: theme)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct ExampleChip: View {
    let text: String
    @ObservedObject var theme: JarvisTheme
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(theme.semanticColors.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(theme.semanticColors.glassBackground)
                    .overlay(Capsule().stroke(theme.semanticColors.glassBorder, lineWidth: 1))
            )
    }
}

/// Agent 面板
struct AgentPanelView: View {
    @ObservedObject var agentEngine: AgentEngine
    @Binding var goal: String
    @Environment(\.dismiss) var dismiss
    @State private var isRunning = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "brain")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                
                Text("Agent 任务")
                    .font(.title2.weight(.semibold))
                
                Text("描述你的目标，Jarvis 将自动规划并执行")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextField("例如：把桌面整理一下", text: $goal)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                Button(isRunning ? "执行中..." : "开始执行") {
                    isRunning = true
                    agentEngine.startTask(goal: goal)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isRunning = false
                        dismiss()
                    }
                }
                .disabled(goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRunning)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                if let task = agentEngine.currentTask {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("执行计划")
                            .font(.headline)
                        ForEach(task.actions) { action in
                            HStack {
                                Image(systemName: action.status == .completed ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(action.status == .completed ? .green : .secondary)
                                Text(action.description)
                                    .font(.caption)
                                Spacer()
                                if action.status == .executing {
                                    ProgressView().controlSize(.mini)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Agent 面板")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .frame(width: 400, height: 500)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}