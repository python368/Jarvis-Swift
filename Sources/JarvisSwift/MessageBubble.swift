import SwiftUI

struct MessageBubble: View {
    let message: Message
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 40)
                bubble(user: true)
                AvatarView(isUser: true)
            } else {
                AvatarView(isUser: false)
                bubble(user: false)
                Spacer(minLength: 40)
            }
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.8)),
            removal: .scale(scale: 0.9).combined(with: .opacity).animation(.easeIn(duration: 0.15))
        ))
    }
    
    @ViewBuilder
    private func bubble(user: Bool) -> some View {
        VStack(alignment: user ? .trailing : .leading, spacing: 4) {
            // 消息内容
            Text(message.text)
                .font(.body)
                .foregroundStyle(user ? .white : Color.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    UnevenRoundedRectangle(
                        cornerRadii: RectangleCornerRadii(
                            topLeading: user ? 20 : 4,
                            topTrailing: user ? 4 : 20,
                            bottomLeading: user ? 20 : 20,
                            bottomTrailing: user ? 20 : 4
                        )
                    )
                    .fill(user ? bubbleColor : assistantBubbleColor)
                    .shadow(color: Color.black.opacity(user ? 0.15 : 0.08), radius: user ? 12 : 8, x: 0, y: user ? 4 : 2)
                )
            
            // 时间戳
            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(Color.secondary.opacity(0.7))
                .padding(.horizontal, 4)
        }
    }
    
    private var bubbleColor: Color {
        colorScheme == .dark ? Color(red: 0.0, green: 0.48, blue: 1.0) : Color(red: 0.0, green: 0.35, blue: 0.85)
    }
    
    private var assistantBubbleColor: Color {
        colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.95)
    }
}

struct AvatarView: View {
    let isUser: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isUser ? Color(red: 0.0, green: 0.48, blue: 1.0) : Color.gray.opacity(0.3))
                .frame(width: 32, height: 32)
            
            Image(systemName: isUser ? "person.fill" : "arrow.uturn.forward")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isUser ? .white : .gray)
        }
    }
}

struct MessageBubble_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            MessageBubble(message: Message(id: UUID(), text: "Hello, Relay! 这是一个测试消息，包含多行内容来测试气泡的自适应高度和宽度。", isUser: false))
            MessageBubble(message: Message(id: UUID(), text: "I want to clean my desktop.", isUser: true))
            MessageBubble(message: Message(id: UUID(), text: "短消息", isUser: false))
            MessageBubble(message: Message(id: UUID(), text: "这是一条很长的用户消息，用来测试用户气泡在右侧对齐以及长文本的换行处理是否正确工作。", isUser: true))
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}