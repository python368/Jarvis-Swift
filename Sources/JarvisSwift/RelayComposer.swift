import SwiftUI

struct RelayComposer: View {
    @Binding var text: String
    let onSend: () -> Void
    var accentColor: Color
    var isProcessing: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isHovering = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 输入框
            ZStack(alignment: .trailing) {
                TextField("告诉 Relay 你的目标…", text: $text, axis: .vertical)
                    .textFieldStyle(ComposerTextFieldStyle(
                        isFocused: $isFocused,
                        isHovering: $isHovering,
                        themeColors: ComposerThemeColors(
                            background: colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.98),
                            border: colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06),
                            focusRing: accentColor.opacity(0.4),
                            placeholder: Color.secondary
                        )
                    ))
                    .lineLimit(1...6)
                    .submitLabel(.send)
                    .onSubmit(onSend)
                    .disabled(isProcessing)
                
                // 字符计数/处理中指示
                if isProcessing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("思考中…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 8)
                }
            }
            
            // 发送按钮
            Button(action: onSend) {
                Image(systemName: isProcessing ? "hourglass" : "paperplane.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(canSend && !isProcessing ? accentColor : Color.secondary.opacity(0.3))
                            .shadow(color: canSend && !isProcessing ? accentColor.opacity(0.4) : .clear, radius: 8, x: 0, y: 2)
                    )
                    .scaleEffect(buttonScale)
            }
            .disabled(!canSend || isProcessing)
            .buttonStyle(ComposerButtonStyle(
                pressScale: 0.92,
                hoverScale: 1.05
            ))
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ComposerBackground(themeColors: ComposerThemeColors(
                background: Color(NSColor.windowBackgroundColor).opacity(0.9),
                border: Color.primary.opacity(0.06),
                focusRing: accentColor.opacity(0.4),
                placeholder: Color.secondary
            ), isFocused: isFocused, isHovering: isHovering)
        )
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    @State private var buttonScale: CGFloat = 1.0
}

// MARK: - 样式组件

struct ComposerThemeColors {
    let background: Color
    let border: Color
    let focusRing: Color
    let placeholder: Color
}

struct ComposerTextFieldStyle: TextFieldStyle {
    var isFocused: FocusState<Bool>.Binding
    @Binding var isHovering: Bool
    let themeColors: ComposerThemeColors
    
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .font(.body)
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(themeColors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isFocused.wrappedValue ? themeColors.focusRing : (isHovering ? themeColors.border.opacity(0.5) : themeColors.border), lineWidth: isFocused.wrappedValue ? 2 : 1)
                    )
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
            }
            .focused(isFocused)
            .textSelection(.enabled)
    }
}

struct ComposerBackground: View {
    let themeColors: ComposerThemeColors
    let isFocused: Bool
    let isHovering: Bool
    
    var body: some View {
        UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: 20,
                topTrailing: 20,
                bottomLeading: 20,
                bottomTrailing: 20
            )
        )
        .fill(
            LinearGradient(
                colors: [
                    themeColors.background,
                    themeColors.background.opacity(0.95)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(
                    topLeading: 20,
                    topTrailing: 20,
                    bottomLeading: 20,
                    bottomTrailing: 20
                )
            )
            .stroke(
                isFocused ? themeColors.focusRing : (isHovering ? themeColors.border.opacity(0.6) : themeColors.border),
                lineWidth: isFocused ? 2 : 1
            )
        )
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 16, x: 0, y: 8
        )
        .shadow(
            color: Color.black.opacity(0.04),
            radius: 4, x: 0, y: 2
        )
    }
}

struct ComposerButtonStyle: ButtonStyle {
    let pressScale: CGFloat
    let hoverScale: CGFloat
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressScale : hoverScale)
            .animation(.spring(response: 0.12, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Preview
struct RelayComposer_Previews: PreviewProvider {
    static var previews: some View {
        @State var text = ""
        VStack {
            RelayComposer(text: $text, onSend: {}, accentColor: .blue, isProcessing: false)
            RelayComposer(text: $text, onSend: {}, accentColor: .purple, isProcessing: true)
        }
        .padding()
        .frame(width: 500)
    }
}