import SwiftUI

struct ContentView: View {
    @State private var prompt: String = ""
    @State private var html: String = UIHTML.welcome
    @State private var isLoading = false
    @State private var showSettings = false

    private let client = LLMClient()

    var body: some View {
        VStack(spacing: 0) {
            WebView(html: html)
                .ignoresSafeArea(edges: .top)
            inputBar
        }
        .background(.black)
        .overlay(alignment: .top) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            TextField("Describe a screen or tool…", text: $prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .submitLabel(.go)
                .onSubmit(run)

            Button(action: run) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(canSend ? Color.accentColor : .secondary)
            }
            .disabled(!canSend)
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !isLoading && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func run() {
        let request = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty else { return }
        isLoading = true

        Task {
            let context = "Today is \(Date().formatted(date: .complete, time: .shortened))."
            do {
                let result = try await client.generateHTML(prompt: request, context: context)
                await MainActor.run {
                    html = result
                    prompt = ""
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    html = UIHTML.error(error.localizedDescription)
                    isLoading = false
                }
            }
        }
    }
}
