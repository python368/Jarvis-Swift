import SwiftUI
import Combine

enum JarvisAccentColor: String, CaseIterable, Codable {
    case blue, purple, green, orange, red, pink, yellow, system

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .pink: return .pink
        case .yellow: return .yellow
        case .system: return .accentColor
        }
    }

    var label: String {
        rawValue.capitalized
    }
}

enum JarvisAppearance: String, CaseIterable, Codable {
    case system, light, dark

    var label: String {
        rawValue.capitalized
    }
}

final class JarvisTheme: ObservableObject {
    @Published var accent: JarvisAccentColor = .blue
    @Published var appearance: JarvisAppearance = .system

    private var cancellables = Set<AnyCancellable>()

    init() {
        accent = JarvisDefaults.accent
        appearance = JarvisDefaults.appearance

        $accent
            .sink { [weak self] value in
                self?.applyAccent(value)
                JarvisDefaults.accent = value
            }
            .store(in: &cancellables)

        $appearance
            .sink { [weak self] value in
                self?.applyAppearance(value)
                JarvisDefaults.appearance = value
            }
            .store(in: &cancellables)
    }

    private func applyAccent(_ value: JarvisAccentColor) {
        // 强调色由视图层直接使用，避免修改系统级设置。
    }

    private func applyAppearance(_ value: JarvisAppearance) {
        switch value {
        case .system:
            NSApplication.shared.appearance = nil
        case .light:
            NSApplication.shared.appearance = NSAppearance(name: .aqua)
        case .dark:
            NSApplication.shared.appearance = NSAppearance(name: .darkAqua)
        }
    }
}

extension Color {
    static let cardBackground = Color(NSColor.controlBackgroundColor)
    static let elevatedBackground = Color(NSColor.windowBackgroundColor)
    static let secondaryText = Color(NSColor.secondaryLabelColor)
    static let jarvisAccentColor = Color(NSColor.controlAccentColor)
}

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

extension Color {
    func toNSColor() -> NSColor {
        return NSColor(self)
    }
}

extension Color {
    func toOptionalNSColor() -> NSColor? {
        guard let components = self.components else { return nil }
        return NSColor(
            red: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha
        )
    }
}

extension Color {
    var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        NSColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
}

struct JarvisTheme_Previews: PreviewProvider {
    static var previews: some View {
        Text("Theme")
    }
}