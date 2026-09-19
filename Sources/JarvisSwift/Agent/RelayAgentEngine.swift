import Foundation

/// Agent 状态
enum AgentState: Codable, Equatable {
    case idle
    case observing
    case planning
    case acting
    case verifying
    case recovering
    case completed
    case failed(String)
    
    static func == (lhs: AgentState, rhs: AgentState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.observing, .observing), (.planning, .planning), (.acting, .acting), (.verifying, .verifying), (.recovering, .recovering), (.completed, .completed):
            return true
        case (.failed(let lhsErr), .failed(let rhsErr)):
            return lhsErr == rhsErr
        default:
            return false
        }
    }
}

/// Agent 动作
struct AgentAction: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ActionType
    let description: String
    let parameters: [String: String]
    let timestamp: Date
    var status: ActionStatus = .pending
    var result: String?
    var error: String?
    
    init(id: UUID = UUID(), type: ActionType, description: String, parameters: [String: String] = [:], timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.description = description
        self.parameters = parameters
        self.timestamp = timestamp
    }
}

/// 动作类型
enum ActionType: String, Codable, CaseIterable {
    case observe = "observe"
    case click = "click"
    case type = "type"
    case keyPress = "keyPress"
    case scroll = "scroll"
    case openApp = "openApp"
    case closeApp = "closeApp"
    case openFile = "openFile"
    case saveFile = "saveFile"
    case runCommand = "runCommand"
    case search = "search"
    case wait = "wait"
    case custom = "custom"
}

/// 动作状态
enum ActionStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case executing = "executing"
    case completed = "completed"
    case failed = "failed"
    case skipped = "skipped"
}

/// Agent 任务
struct AgentTask: Identifiable, Codable, Equatable {
    let id: UUID
    let goal: String
    var state: AgentState = .idle
    var actions: [AgentAction] = []
    var currentActionIndex: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var context: [String: String] = [:]
    
    init(id: UUID = UUID(), goal: String) {
        self.id = id
        self.goal = goal
    }
    
    var currentAction: AgentAction? {
        guard currentActionIndex < actions.count else { return nil }
        return actions[currentActionIndex]
    }
    
    var isCompleted: Bool { state == .completed }
    var hasFailed: Bool { if case .failed = state { return true }; return false }
}

/// 观察结果
struct Observation: Codable, Equatable {
    let timestamp: Date
    let screenSnapshot: Data? // 屏幕截图
    let activeApp: String?
    let openWindows: [WindowInfo]
    let clipboardContent: String?
    let selectedText: String?
    let systemInfo: SystemInfo
    
    struct WindowInfo: Codable, Equatable {
        let appName: String
        let windowTitle: String
        let bounds: CGRect
        let isActive: Bool
    }
    
    struct SystemInfo: Codable, Equatable {
        let cpuUsage: Double
        let memoryUsage: Double
        let diskSpace: Int64
    }
}

/// Agent 核心引擎
@MainActor
final class AgentEngine: ObservableObject {
    @Published var currentTask: AgentTask?
    @Published var state: AgentState = .idle
    @Published var observations: [Observation] = []
    @Published var errorMessage: String?
    
    private let memoryStore: MemoryStore
    private let providerManager: ProviderManager
    private let searchManager: SearchManager
    private let automation: AutomationLayer
    private var taskContinuation: CheckedContinuation<Void, Never>?
    
    init(memoryStore: MemoryStore, providerManager: ProviderManager, searchManager: SearchManager, automation: AutomationLayer) {
        self.memoryStore = memoryStore
        self.providerManager = providerManager
        self.searchManager = searchManager
        self.automation = automation
    }
    
    /// 启动新任务
    func startTask(goal: String) {
        let task = AgentTask(goal: goal)
        currentTask = task
        state = .observing
        executeTaskLoop()
    }
    
    /// 停止当前任务
    func stopTask() {
        currentTask = nil
        state = .idle
        taskContinuation?.resume()
        taskContinuation = nil
    }
    
    /// 核心循环：Observe → Plan → Act → Verify → Recover
    private func executeTaskLoop() {
        Task { [weak self] in
            guard let self = self else { return }
            var task = self.currentTask
            guard task != nil else { return }
            while let currentTask = task, !currentTask.isCompleted, !currentTask.hasFailed {
                do {
                    // 1. Observe
                    self.state = .observing
                    let observation = try await self.observe()
                    self.observations.append(observation)
                    
                    // 2. Plan
                    self.state = .planning
                    let plan = try await self.plan(goal: currentTask.goal, observation: try await self.observe(), history: currentTask.actions)
                    task?.actions = plan
                    task?.currentActionIndex = 0
                    
                    // 3. Act + Verify 循环
                    for (index, action) in plan.enumerated() {
                        guard self.currentTask?.id == task?.id else { break }
                        task?.currentActionIndex = index
                        
                        self.state = .acting
                        let result = try await self.act(action: action)
                        task?.actions[index].status = .completed
                        task?.actions[index].result = result
                        
                        self.state = .verifying
                        let verified = try await self.verify(action: action, expectedResult: result)
                        if !verified {
                            self.state = .recovering
                            let recovered = try await self.recover(action: action, error: "验证失败")
                            if !recovered {
                                throw NSError(domain: "AgentEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "恢复失败"])
                            }
                        }
                    }
                    
                    self.state = .completed
                    task?.state = .completed
                    } catch {
                    self.state = .failed(error.localizedDescription)
                    if let t = self.currentTask {
                        t.state = .failed(error.localizedDescription)
                    }
                }
            }
            self.taskContinuation?.resume()
        }
    }
    
    // MARK: - Observe
    private func observe() async throws -> Observation {
        // 实际应调用 AutomationLayer 捕获屏幕、窗口、应用状态
        let snapshot = try? await automation.captureScreen()
        let windows = await automation.getOpenWindows()
        let activeApp = await automation.getActiveApplication()
        let clipboard = await automation.getClipboard()
        let selected = await automation.getSelectedText()
        
        return Observation(
            timestamp: Date(),
            screenSnapshot: snapshot,
            activeApp: activeApp,
            openWindows: windows,
            clipboardContent: clipboard,
            selectedText: selected,
            systemInfo: Observation.SystemInfo(cpuUsage: 0, memoryUsage: 0, diskSpace: 0)
        )
    }
    
    // MARK: - Plan
    private func plan(goal: String, observation: Observation, history: [AgentAction]) async throws -> [AgentAction] {
        // 调用模型生成计划
        guard let backend = providerManager.selectedBackend else {
            throw NSError(domain: "AgentEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "未配置模型 Provider"])
        }
        
        let systemPrompt = """
        You are Relay, an AI agent that controls macOS. Generate a sequence of actions to achieve the user's goal.
        Available action types: \(ActionType.allCases.map { $0.rawValue }.joined(separator: ", "))
        Current observation: Active app: \(observation.activeApp ?? "none"), Windows: \(observation.openWindows.map { "\($0.appName): \($0.windowTitle)" }.joined(separator: ", "))
        History: \(history.map { "\($0.type.rawValue): \($0.description)" }.joined(separator: "; "))
        Goal: \(goal)
        Return JSON array of actions with: type, description, parameters.
        """
        
        let messages = [
            Message(role: .system, content: systemPrompt),
            Message(role: .user, content: goal)
        ]
        
        var plan: [AgentAction] = []
        for try await event in try await backend.chat(messages: messages, attachments: [], tools: nil, options: ChatOptions()) {
            if case .token(let token) = event {
                // 解析流式输出的 JSON
            }
        }
        
        // 简化：返回示例计划
        return [
            AgentAction(type: .observe, description: "观察当前屏幕状态"),
            AgentAction(type: .openApp, description: "打开目标应用", parameters: ["appName": "Finder"]),
            AgentAction(type: .click, description: "点击目标按钮", parameters: ["x": "100", "y": "200"])
        ]
    }
    
    // MARK: - Act
    private func act(action: AgentAction) async throws -> String {
        switch action.type {
        case .observe:
            let obs = try await observe()
            return "观察完成: \(obs.activeApp ?? "无活动应用")"
        case .click:
            let x = Double(action.parameters["x"] ?? "0") ?? 0
            let y = Double(action.parameters["y"] ?? "0") ?? 0
            try await automation.click(x: x, y: y)
            return "点击完成 (\(x), \(y))"
        case .type:
            let text = action.parameters["text"] ?? ""
            try await automation.type(text: text)
            return "输入完成: \(text)"
        case .keyPress:
            let key = action.parameters["key"] ?? ""
            try await automation.pressKey(key)
            return "按键完成: \(key)"
        case .scroll:
            let dx = Double(action.parameters["dx"] ?? "0") ?? 0
            let dy = Double(action.parameters["dy"] ?? "0") ?? 0
            try await automation.scroll(dx: dx, dy: dy)
            return "滚动完成"
        case .openApp:
            let app = action.parameters["appName"] ?? ""
            try await automation.openApplication(named: app)
            return "打开应用: \(app)"
        case .closeApp:
            let app = action.parameters["appName"] ?? ""
            try await automation.closeApplication(named: app)
            return "关闭应用: \(app)"
        case .openFile:
            let path = action.parameters["path"] ?? ""
            try await automation.openFile(at: path)
            return "打开文件: \(path)"
        case .saveFile:
            let path = action.parameters["path"] ?? ""
            let content = action.parameters["content"] ?? ""
            try await automation.saveFile(at: path, content: content)
            return "保存文件: \(path)"
        case .runCommand:
            let cmd = action.parameters["command"] ?? ""
            let output = try await automation.runShellCommand(cmd)
            return "命令执行完成: \(output)"
        case .search:
            let query = action.parameters["query"] ?? ""
            let results = try await searchManager.search(query: query)
            return "搜索完成，找到 \(results.count) 个结果"
        case .wait:
            let seconds = Double(action.parameters["seconds"] ?? "1") ?? 1
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return "等待完成"
        case .custom:
            return "自定义动作执行"
        }
    }
    
    // MARK: - Verify
    private func verify(action: AgentAction, expectedResult: String) async throws -> Bool {
        // 简单验证：检查动作是否返回错误
        return !expectedResult.contains("失败") && !expectedResult.contains("错误")
    }
    
    // MARK: - Recover
    private func recover(action: AgentAction, error: String) async throws -> Bool {
        // 简单恢复：重试或跳过
        print("🔄 恢复动作: \(action.description), 错误: \(error)")
        // 这里可以实现重试逻辑、替代方案等
        return false // 简化：不自动恢复
    }
}