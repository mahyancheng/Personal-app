import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("baseURL") private var baseURL = ""
    @AppStorage("apiKey") private var apiKey = ""
    @AppStorage("model") private var model = "gpt-4o"

    var body: some View {
        NavigationStack {
            Form {
                Section("Endpoint") {
                    TextField("Base URL (https://your-sub2api-host)", text: $baseURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("API key", text: $apiKey)
                    TextField("Model (e.g. gpt-4o)", text: $model)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Text("""
                    Forge sends OpenAI-compatible POST requests to \
                    `<Base URL>/v1/chat/completions`. Point it at your sub2api \
                    gateway, or at the official OpenAI/Anthropic API — the app \
                    doesn't care which, as long as it speaks that format.
                    """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
