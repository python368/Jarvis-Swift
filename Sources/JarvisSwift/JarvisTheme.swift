import SwiftUI
import Combine

/// Jarvis 强调色（符合 README：蓝/紫/绿/橙/红/粉/黄/系统/自定义）
enum JarvisAccentColor: String, CaseIterable, Codable {
    case blue, purple, green, orange, red, pink, yellow, system, custom
    
    var color: Color {
        switch self {
        case .blue: return Color(red: 0.0, green: 0.48, blue: 1.0)      // iOS/macOS 标准蓝
        case .purple: return Color(red: 0.69, green: 0.32, blue: 0.87)   // iOS/macOS 标准紫
        case .green: return Color(red: 0.20, green: 0.78, blue: 0.35)    // iOS/macOS 标准绿
        case .orange: return Color(red: 1.0, green: 0.58, blue: 0.0)     // iOS/macOS 标准橙
        case .red: return Color(red: 1.0, green: 0.23, blue: 0.19)       // iOS/macOS 标准红
        case .pink: return Color(red: 1.0, green: 0.18, blue: 0.33)      // iOS/macOS 标准粉
        case .yellow: return Color(red: 1.0, green: 0.8, blue: 0.0)      // iOS/macOS 标准黄
        case .system: return Color.accentColor
        case .custom: return Color.accentColor // 由 customColor 决定
        }
    }
    
    var label: String {
        switch self {
        case .blue: return "蓝色"
        case .purple: return "紫色"
        case .green: return "绿色"
        case .orange: return "橙色"
        case .red: return "红色"
        case .pink: return "粉色"
        case .yellow: return "黄色"
        case .system: return "跟随系统"
        case .custom: return "自定义"
        }
    }
    
    var isCustom: Bool { self == .custom }
}

/// 外观模式（符合 README：跟随系统/浅色/深色）
enum JarvisAppearance: String, CaseIterable, Codable {
    case system, light, dark
    
    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

/// 动效偏好（符合 README：支持减少动态效果）
enum MotionPreference: String, CaseIterable, Codable {
    case standard = "standard"
    case reduced = "reduced"
    
    var label: String {
        switch self {
        case .standard: return "标准"
        case .reduced: return "减少动态效果"
        }
    }
}

/// Jarvis 主题系统（符合 README：Liquid Glass / 现代系统材质 + 语义化颜色 + 动效层级）
final class JarvisTheme: ObservableObject {
    @Published var accent: JarvisAccentColor = .blue
    @Published var customAccentColor: Color = .blue
    @Published var appearance: JarvisAppearance = .system
    @Published var motion: MotionPreference = .standard
    @Published var reduceTransparency: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 从 UserDefaults 恢复
        accent = JarvisDefaults.accent
        if let data = UserDefaults.standard.data(forKey: "jarvis.customAccentColor"),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            customAccentColor = Color(color)
        }
        appearance = JarvisDefaults.appearance
        motion = MotionPreference(rawValue: UserDefaults.standard.string(forKey: "jarvis.motion") ?? "standard") ?? .standard
        reduceTransparency = UserDefaults.standard.bool(forKey: "jarvis.reduceTransparency")
        
        // 监听变化并持久化
        $accent.sink { [weak self] v in self?.applyAccent(v); JarvisDefaults.accent = v }.store(in: &cancellables)
        $customAccentColor.sink { [weak self] v in
            if let nsColor = NSColor(v) {
                try? UserDefaults.standard.set(NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false), forKey: "jarvis.customAccentColor")
            }
        }.store(in: &cancellables)
        $appearance.sink { [weak self] v in self?.applyAppearance(v); JarvisDefaults.appearance = v }.store(in: &cancellables)
        $motion.sink { v in UserDefaults.standard.set(v.rawValue, forKey: "jarvis.motion") }.store(in: &cancellables)
        $reduceTransparency.sink { v in UserDefaults.standard.set(v, forKey: "jarvis.reduceTransparency") }.store(in: &cancellables)
        
        // 初始应用
        applyAppearance(appearance)
    }
    
    /// 当前有效的强调色
    var effectiveAccentColor: Color {
        accent == .custom ? customAccentColor : accent.color
    }
    
    /// 语义化颜色系统（符合 README：Button/Hover/Focus/Glass/Glow/Selection/Agent State 统一驱动）
    var semanticColors: SemanticColors {
        SemanticColors(accent: effectiveAccentColor, appearance: appearance, reduceTransparency: reduceTransparency)
    }
    
    /// 动画配置（符合 README：Motion Hierarchy 4 层级 + 减少动态效果支持）
    var animationConfig: AnimationConfig {
        AnimationConfig(motion: motion)
    }
    
    private func applyAccent(_ value: JarvisAccentColor) {
        // 强调色由 semanticColors 驱动，不修改系统级设置
    }
    
    private func applyAppearance(_ value: JarvisAppearance) {
        switch value {
        case .system: NSApplication.shared.appearance = nil
        case .light:  NSApplication.shared.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

/// 语义化颜色系统
struct SemanticColors {
    let accent: Color
    let appearance: JarvisAppearance
    let reduceTransparency: Bool
    
    // 基础材质（符合 Liquid Glass：半透明玻璃材质 + 清晰空间层级）
    var glassBackground: Color {
        reduceTransparency ?
        (appearance == .dark ? Color(white: 0.15, opacity: 1.0) : Color(white: 0.95, opacity: 1.0)) :
        (appearance == .dark ? Color(white: 0.1, opacity: 0.8) : Color(white: 1.0, opacity: 0.8))
    }
    
    var glassBorder: Color {
        appearance == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }
    
    var elevatedGlass: Color {
        reduceTransparency ?
        (appearance == .dark ? Color(white: 0.18, opacity: 1.0) : Color(white: 0.98, opacity: 1.0)) :
        (appearance == .dark ? Color(white: 0.12, opacity: 0.85) : Color(white: 1.0, opacity: 0.85))
    }
    
    // 强调色驱动的语义色
    var primaryButton: Color { accent }
    var primaryButtonHover: Color { accent.opacity(0.85) }
    var primaryButtonPressed: Color { accent.opacity(0.7) }
    var focusRing: Color { accent.opacity(0.5) }
    var glassTint: Color { accent.opacity(0.15) }
    var glow: Color { accent.opacity(0.4) }
    var selection: Color { accent.opacity(0.2) }
    var agentThinking: Color { accent.opacity(0.6) }
    var agentExecuting: Color { accent }
    var agentCompleted: Color { .green }
    var agentFailed: Color { .red }
    
    // 文本层级
    var primaryText: Color { appearance == .dark ? .white : .black }
    var secondaryText: Color { appearance == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.7) }
    var tertiaryText: Color { appearance == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5) }
    
    // 背景层级
    var background: Color { appearance == .dark ? Color(white: 0.08) : Color(white: 0.97) }
    var surface: Color { appearance == .dark ? Color(white: 0.12) : Color(white: 0.98) }
    var card: Color { appearance == .dark ? Color(white: 0.15) : Color(white: 1.0) }
    var elevated: Color { appearance == .dark ? Color(white: 0.18) : Color(white: 1.0) }
    
    // 分隔线
    var divider: Color { appearance == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06) }
}

/// 动画配置（符合 README：Motion Hierarchy 4 层级）
struct AnimationConfig {
    let motion: MotionPreference
    
    // Layer 1: 即时反馈（按钮、Hover、点击）< 100ms
    var instant: Animation { motion == .reduced ? .none : .spring(response: 0.15, dampingFraction: 0.8) }
    var instantFast: Animation { motion == .reduced ? .none : .spring(response: 0.08, dampingFraction: 0.7) }
    
    // Layer 2: 状态变化（启动、任务开始/完成）200-300ms
    var stateChange: Animation { motion == .reduced ? .none : .spring(response: 0.25, dampingFraction: 0.85) }
    var stateChangeSlow: Animation { motion == .reduced ? .none : .spring(response: 0.35, dampingFraction: 0.9) }
    
    // Layer 3: 环境动画（玻璃、背景、Agent 状态）400-600ms
    var ambient: Animation { motion == .reduced ? .none : .easeInOut(duration: 0.5) }
    var ambientSlow: Animation { motion == .reduced ? .none : .easeInOut(duration: 0.8) }
    
    // Layer 4: 静态内容（文字、设置、列表）无动画或极快
    var staticContent: Animation { .none }
    var listInsertion: Animation { motion == .reduced ? .none : .spring(response: 0.3, dampingFraction: 0.8) }
    var listRemoval: Animation { motion == .reduced ? .none : .spring(response: 0.2, dampingFraction: 0.7) }
    
    // 交互反馈
    var pressScale: CGFloat { motion == .reduced ? 1.0 : 0.96 }
    var hoverScale: CGFloat { motion == .reduced ? 1.0 : 1.02 }
    var hoverLift: CGFloat { motion == .reduced ? 0 : 2 }
    
    // 环境动画参数
    var glassShimmerDuration: Double { motion == .reduced ? 0 : 3.0 }
    var agentPulseDuration: Double { motion == .reduced ? 0 : 1.5 }
    var backgroundBreathDuration: Double { motion == .reduced ? 0 : 8.0 }
}

/// UserDefaults 持久化
struct JarvisDefaults {
    static var accent: JarvisAccentColor {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "jarvis.accent"),
                  let value = JarvisAccentColor(rawValue: raw) else { return .blue }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "jarvis.accent") }
    }
    
    static var appearance: JarvisAppearance {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "jarvis.appearance"),
                  let value = JarvisAppearance(rawValue: raw) else { return .system }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "jarvis.appearance") }
    }
}

/// Color 扩展：NSColor 桥接（用于持久化）
extension Color {
    func toNSColor() -> NSColor { NSColor(self) }
}

struct JarvisTheme_Previews: PreviewProvider {
    static var previews: some View {
        Text("Theme")
    }
}