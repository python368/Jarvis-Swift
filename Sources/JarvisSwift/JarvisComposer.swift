import SwiftUI

struct JarvisComposer: View {
    @Binding var text: String
    let onSend: () -> Void
    var accentColor: Color = .accentColor

    var body: some View {
        HStack(spacing: 12) {
            TextField("告诉 Jarvis 你的目标…", text: $text)
                .textFieldStyle(JarvisRoundedTextFieldStyle())
                .lineLimit(1...6)
                .submitLabel(.send)
                .onSubmit(onSend)

            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(canSend ? accentColor : Color.secondary.opacity(0.3))
                    )
            }
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.2), value: canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(
                    topTrailing: 22,
                    bottomTrailing: 22,
                    topLeading: 22,
                    bottomLeading: 22
                )
            )
            .fill(Color.cardBackground)
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct JarvisRoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                UnevenRoundedRectangle(
                    cornerRadii: RectangleCornerRadii(
                        topTrailing: 12,
                        bottomTrailing: 12,
                        topLeading: 12,
                        bottomLeading: 12
                    )
                )
                .fill(Color(NSColor.textBackgroundColor))
                .overlay(
                    UnevenRoundedRectangle(
                        cornerRadii: RectangleCornerRadii(
                            topTrailing: 12,
                            bottomTrailing: 12,
                            topLeading: 12,
                            bottomLeading: 12
                        )
                    )
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            )
    }
}

struct JarvisComposer_Previews: PreviewProvider {
    static var previews: some View {
        @State var text = ""
        JarvisComposer(text: $text, onSend: {})
            .padding()
    }
}