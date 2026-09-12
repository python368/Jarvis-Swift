import SwiftUI

struct ContentView: View {
    @StateObject private var theme = JarvisTheme()
    @ObservedObject private var memoryStore = MemoryStore.shared
    @State private var inputText: String = ""
    @State private var messages: [Message] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                chatView
                JarvisComposer(text: $inputText, onSend: sendMessage, accentColor: theme.accent.color)
            }
            .navigationTitle("Jarvis")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                JarvisSettingsView(theme: theme, memoryStore: memoryStore)
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .environmentObject(theme)
    }
    
    private var chatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onChange(of: messages.count) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    @State private var showSettings = false
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let userMessage = Message(id: UUID(), text: text, isUser: true)
        messages.append(userMessage)
        memoryStore.addMessage(userMessage)
        
        inputText = ""
        
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            let reply = "好的，我正在处理：「\(text)」。"
            let jarvisMessage = Message(id: UUID(), text: reply, isUser: false)
            withAnimation {
                messages.append(jarvisMessage)
                memoryStore.addMessage(jarvisMessage)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}