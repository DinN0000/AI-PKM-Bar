import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var step: Int = 0
    @State private var showFolderPicker = false
    @State private var newProjectName: String = ""
    @State private var projects: [String] = []
    @State private var isStructureReady = false

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Step content
            switch step {
            case 0: welcomeStep
            case 1: apiKeyStep
            case 2: folderStep
            case 3: projectStep
            default: projectStep
            }
        }
        .frame(width: 360, height: 480)
        .animation(.easeInOut(duration: 0.2), value: step)
        .onChange(of: appState.pkmRootPath) { _ in
            isStructureReady = PKMPathManager(root: appState.pkmRootPath).isInitialized()
        }
        .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                appState.pkmRootPath = url.path
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("·‿·")
                .font(.system(size: 32, design: .monospaced))
                .foregroundColor(.primary)

            VStack(spacing: 6) {
                Text("AI-PKM")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("AI가 파일을 PARA 구조로 자동 분류합니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // PARA explanation
            VStack(alignment: .leading, spacing: 8) {
                paraRow(prefix: "P", title: "Project", desc: "진행 중인 프로젝트")
                paraRow(prefix: "A", title: "Area", desc: "지속적으로 관리하는 영역")
                paraRow(prefix: "R", title: "Resource", desc: "참고 자료 및 레퍼런스")
                paraRow(prefix: "A", title: "Archive", desc: "완료되거나 보관할 것")
            }
            .padding(16)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 32)

            Spacer()

            Button(action: { step = 1 }) {
                Text("시작하기")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.primary.opacity(0.85))
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
        .padding()
    }

    private func paraRow(prefix: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Text(prefix)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Step 2: API Key

    private var apiKeyStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("API 키 설정")
                .font(.title3)
                .fontWeight(.semibold)

            Text("파일 분류에 Claude AI를 사용합니다")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // API key guide link
            Button(action: {
                if let url = URL(string: "https://console.anthropic.com/settings/keys") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 4) {
                    Text("API 키가 없다면?")
                        .font(.caption)
                    Text("console.anthropic.com에서 발급")
                        .font(.caption)
                        .underline()
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            APIKeyInputView(showDeleteButton: false)
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("* Claude 구독과 별도로 API 결제 등록이 필요합니다")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("파일당 약 $0.002 (Haiku) / 불확실 시 ~$0.01 (Sonnet)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)

            Spacer()

            HStack {
                Button("이전") { step = 0 }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                Spacer()

                Button(action: { step = 2 }) {
                    Text("다음")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!appState.hasAPIKey)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
        .padding()
    }

    // MARK: - Step 3: Folder Setup

    private var folderStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("PKM 폴더 설정")
                .font(.title3)
                .fontWeight(.semibold)

            Text("파일이 정리될 폴더를 선택하세요")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                    Text(appState.pkmRootPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button("변경") {
                        showFolderPicker = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if isStructureReady {
                    Label("PARA 구조 확인됨", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("PARA 폴더 구조 없음", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Button(action: createFolderStructure) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text("폴더 구조 만들기")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 24)

            Spacer()

            HStack {
                Button("이전") { step = 1 }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                Spacer()

                Button(action: {
                    loadExistingProjects()
                    step = 3
                }) {
                    Text("다음")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!isStructureReady)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
        .padding()
        .onAppear {
            isStructureReady = PKMPathManager(root: appState.pkmRootPath).isInitialized()
        }
    }

    // MARK: - Step 4: Project Setup

    private var projectStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("프로젝트 등록")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 4) {
                Text("최근에 집중하고 있는 작업을 관리할")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("폴더명을 등록하세요.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Inbox와 Project만 직접 관리합니다.")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("Area, Resource, Archive는 AI가 자동 분류합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)

            // Add project input
            HStack(spacing: 8) {
                TextField("프로젝트명", text: $newProjectName)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
                    .onSubmit { addProject() }

                Button(action: addProject) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24)

            // Project list
            if !projects.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(projects, id: \.self) { name in
                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(name)
                                    .font(.subheadline)

                                Spacer()

                                Button(action: { removeProject(name) }) {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(6)
                        }
                    }
                }
                .frame(maxHeight: 120)
                .padding(.horizontal, 24)
            } else {
                Text("등록된 프로젝트 없음")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }

            Spacer()

            HStack {
                Button("이전") { step = 2 }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                Spacer()

                if projects.isEmpty {
                    Button(action: completeOnboarding) {
                        Text("건너뛰기")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                } else {
                    Button(action: completeOnboarding) {
                        Text("완료")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
        .padding()
    }

    // MARK: - Actions

    private func createFolderStructure() {
        let pathManager = PKMPathManager(root: appState.pkmRootPath)
        try? pathManager.initializeStructure()
        isStructureReady = pathManager.isInitialized()
    }

    private func loadExistingProjects() {
        let pathManager = PKMPathManager(root: appState.pkmRootPath)
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: pathManager.projectsPath) else { return }

        projects = entries.filter { name in
            guard !name.hasPrefix("."), !name.hasPrefix("_") else { return false }
            let fullPath = (pathManager.projectsPath as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: fullPath, isDirectory: &isDir) && isDir.boolValue
        }.sorted()
    }

    private func addProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !projects.contains(name) else { return }

        let pathManager = PKMPathManager(root: appState.pkmRootPath)
        let projectDir = (pathManager.projectsPath as NSString).appendingPathComponent(name)
        let fm = FileManager.default

        // Create project folder + index note
        try? fm.createDirectory(atPath: projectDir, withIntermediateDirectories: true)
        let indexPath = (projectDir as NSString).appendingPathComponent("\(name).md")
        if !fm.fileExists(atPath: indexPath) {
            let content = FrontmatterWriter.createIndexNote(
                folderName: name,
                para: .project,
                description: "\(name) 프로젝트"
            )
            try? content.write(toFile: indexPath, atomically: true, encoding: .utf8)
        }

        projects.append(name)
        projects.sort()
        newProjectName = ""
    }

    private func removeProject(_ name: String) {
        let pathManager = PKMPathManager(root: appState.pkmRootPath)
        let projectDir = (pathManager.projectsPath as NSString).appendingPathComponent(name)
        try? FileManager.default.removeItem(atPath: projectDir)
        projects.removeAll { $0 == name }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        appState.currentScreen = .inbox
    }
}
