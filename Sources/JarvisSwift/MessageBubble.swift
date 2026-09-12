import SwiftUI

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            Text(message.text)
                .font(.body)
                .foregroundStyle(message.isUser ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    UnevenRoundedRectangle(
                        cornerRadii: RectangleCornerRadii(
                            topTrailing: message.isUser ? 18 : 4,
                            bottomTrailing: message.isUser ? 4 : 18,
                            topLeading: message.isUser ? 4 : 18,
                            bottomLeading: message.isUser ? 18 : 4
                        )
                    )
                    .fill(message.isUser ? Color.accentColor : Color.cardBackground)
                )
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            if !message.isUser { Spacer() }
        }
    }
}

struct MessageBubble_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            MessageBubble(message: Message(id: UUID(), text: "Hello, Jarvis!", isUser: false))
            MessageBubble(message: Message(id: UUID(), text: "I want to clean my desktop.", isUser: true))
        }
        .padding()
    }
}