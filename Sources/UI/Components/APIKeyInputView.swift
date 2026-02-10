import SwiftUI

/// Reusable API key input component used in Onboarding and Settings
struct APIKeyInputView: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKeyInput: String = ""
    @State private var showingAPIKey: Bool = false
    @State private var saveMessage: String = ""

    /// Whether to show the delete button when a key exists
    var showDeleteButton: Bool = true
    /// Called after a successful save
    var onSaved: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Claude API Key")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                if showingAPIKey {
                    TextField("sk-ant-...", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                } else {
                    SecureField("sk-ant-...", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                }

                Button(action: { showingAPIKey.toggle() }) {
                    Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
            }

            HStack {
                Button("저장") {
                    if apiKeyInput.hasPrefix("sk-ant-") {
                        let saved = KeychainService.saveAPIKey(apiKeyInput)
                        saveMessage = saved ? "저장 완료" : "저장 실패"
                        appState.hasAPIKey = saved
                        if saved { onSaved?() }
                    } else {
                        saveMessage = "유효한 API 키를 입력하세요"
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                if showDeleteButton && appState.hasAPIKey {
                    Button("삭제") {
                        KeychainService.deleteAPIKey()
                        apiKeyInput = ""
                        appState.hasAPIKey = false
                        saveMessage = "삭제됨"
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if !saveMessage.isEmpty {
                    Text(saveMessage)
                        .font(.caption)
                        .foregroundColor(saveMessage == "저장 완료" ? .green : .orange)
                }
            }

            if appState.hasAPIKey {
                Label("API 키 저장됨 (Keychain)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .onAppear {
            if appState.hasAPIKey {
                apiKeyInput = "••••••••"
            }
        }
    }
}
