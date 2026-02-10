import Foundation
import CryptoKit

/// Reorganizes an existing ARA subfolder:
/// Scan → Extract → AI Classify → Compare/Process
struct FolderReorganizer {
    let pkmRoot: String
    let category: PARACategory
    let subfolder: String
    let onProgress: ((Double, String) -> Void)?

    private var pathManager: PKMPathManager {
        PKMPathManager(root: pkmRoot)
    }

    struct Result {
        var processed: [ProcessedFileResult]
        var needsConfirmation: [PendingConfirmation]
        var total: Int
    }

    func process() async throws -> Result {
        let folderPath = (pathManager.paraPath(for: category) as NSString)
            .appendingPathComponent(subfolder)

        // Scan files (exclude index note and _Assets/)
        let files = scanFolder(at: folderPath)

        guard !files.isEmpty else {
            return Result(processed: [], needsConfirmation: [], total: 0)
        }

        onProgress?(0.05, "\(files.count)개 파일 발견")

        // Deduplicate first
        let (uniqueFiles, dupResults) = deduplicateFiles(files, in: folderPath)
        var processed = dupResults

        onProgress?(0.1, "중복 검사 완료")

        guard !uniqueFiles.isEmpty else {
            onProgress?(1.0, "완료!")
            return Result(processed: processed, needsConfirmation: [], total: files.count)
        }

        // Build context
        let contextBuilder = ProjectContextBuilder(pkmRoot: pkmRoot)
        let projectContext = contextBuilder.buildProjectContext()
        let subfolderContext = contextBuilder.buildSubfolderContext()
        let projectNames = contextBuilder.extractProjectNames(from: projectContext)

        onProgress?(0.15, "프로젝트 컨텍스트 로드 완료")

        // Extract content
        var inputs: [ClassifyInput] = []
        for (i, filePath) in uniqueFiles.enumerated() {
            let progress = 0.15 + Double(i) / Double(uniqueFiles.count) * 0.15
            let fileName = (filePath as NSString).lastPathComponent
            onProgress?(progress, "\(fileName) 내용 추출 중...")

            let content = extractContent(from: filePath)
            inputs.append(ClassifyInput(
                filePath: filePath,
                content: content,
                fileName: fileName
            ))
        }

        onProgress?(0.3, "AI 분류 시작...")

        // Classify with AI
        let classifier = Classifier()
        let classifications = try await classifier.classifyFiles(
            inputs,
            projectContext: projectContext,
            subfolderContext: subfolderContext,
            projectNames: projectNames,
            onProgress: { [onProgress] progress, status in
                let mappedProgress = 0.3 + progress * 0.4
                onProgress?(mappedProgress, status)
            }
        )

        // Compare and process
        var needsConfirmation: [PendingConfirmation] = []

        for (i, classification) in classifications.enumerated() {
            let progress = 0.7 + Double(i) / Double(classifications.count) * 0.25
            let input = inputs[i]
            onProgress?(progress, "\(input.fileName) 처리 중...")

            let currentCategory = category
            let currentFolder = subfolder

            let targetFolder = classification.targetFolder
            let targetCategory = classification.para

            let locationMatches = targetCategory == currentCategory && targetFolder == currentFolder

            if locationMatches {
                // Location correct — update frontmatter/tags with AI values (preserve created only)
                let result = updateFrontmatter(
                    at: input.filePath,
                    classification: classification
                )
                processed.append(result)
            } else {
                // Location wrong — ask user to confirm move
                needsConfirmation.append(PendingConfirmation(
                    fileName: input.fileName,
                    filePath: input.filePath,
                    content: String(input.content.prefix(500)),
                    options: generateOptions(for: classification, projectNames: projectNames),
                    reason: .misclassified
                ))
            }
        }

        onProgress?(0.95, "완료 정리 중...")

        NotificationService.sendProcessingComplete(
            classified: processed.filter(\.isSuccess).count,
            total: files.count,
            failed: 0
        )

        onProgress?(1.0, "완료!")

        return Result(
            processed: processed,
            needsConfirmation: needsConfirmation,
            total: files.count
        )
    }

    // MARK: - Scan

    /// Scan folder for files, excluding index note and _Assets/
    private func scanFolder(at dirPath: String) -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: dirPath) else { return [] }
        let indexNoteName = "\(subfolder).md"

        return entries.compactMap { name -> String? in
            // Skip hidden files, _-prefixed, index note
            guard !name.hasPrefix("."), !name.hasPrefix("_") else { return nil }
            guard name != indexNoteName else { return nil }

            let fullPath = (dirPath as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { return nil }
            // Skip directories (like nested _Assets)
            guard !isDir.boolValue else { return nil }
            return fullPath
        }.sorted()
    }

    // MARK: - Deduplication

    /// Find and remove duplicate files within the folder (SHA256 body comparison)
    private func deduplicateFiles(_ files: [String], in dirPath: String) -> ([String], [ProcessedFileResult]) {
        var seen: [String: String] = [:] // hash → first file path
        var unique: [String] = []
        var results: [ProcessedFileResult] = []

        for filePath in files {
            let hash = fileBodyHash(filePath)
            if let existingPath = seen[hash] {
                // Duplicate — merge tags and delete
                mergeTagsFromFile(source: filePath, into: existingPath)
                try? FileManager.default.removeItem(atPath: filePath)
                results.append(ProcessedFileResult(
                    fileName: (filePath as NSString).lastPathComponent,
                    para: category,
                    targetPath: existingPath,
                    tags: [],
                    status: .deduplicated("중복 — 태그 병합 후 삭제됨")
                ))
            } else {
                seen[hash] = filePath
                unique.append(filePath)
            }
        }

        return (unique, results)
    }

    /// Compute SHA256 hash of file body (ignoring frontmatter for .md files)
    private func fileBodyHash(_ filePath: String) -> String {
        if filePath.hasSuffix(".md"),
           let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
            let body = stripFrontmatter(content)
            let hash = SHA256.hash(data: Data(body.utf8))
            return hash.map { String(format: "%02x", $0) }.joined()
        }
        if let data = FileManager.default.contents(atPath: filePath) {
            let hash = SHA256.hash(data: data)
            return hash.map { String(format: "%02x", $0) }.joined()
        }
        return UUID().uuidString // fallback: treat as unique
    }

    private func stripFrontmatter(_ text: String) -> String {
        var body = text
        if body.hasPrefix("---") {
            if let endRange = body.range(of: "---", range: body.index(body.startIndex, offsetBy: 3)..<body.endIndex) {
                body = String(body[endRange.upperBound...])
            }
        }
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Merge tags from source file into target file's frontmatter
    private func mergeTagsFromFile(source sourcePath: String, into targetPath: String) {
        guard let sourceContent = try? String(contentsOfFile: sourcePath, encoding: .utf8),
              let targetContent = try? String(contentsOfFile: targetPath, encoding: .utf8) else { return }

        let (sourceFM, _) = Frontmatter.parse(markdown: sourceContent)
        let (targetFM, targetBody) = Frontmatter.parse(markdown: targetContent)

        let mergedTags = Array(Set(targetFM.tags + sourceFM.tags)).sorted()
        guard mergedTags != targetFM.tags.sorted() else { return }

        var updated = targetFM
        updated.tags = mergedTags
        let result = updated.stringify() + "\n" + targetBody
        try? result.write(toFile: targetPath, atomically: true, encoding: .utf8)
    }

    // MARK: - Frontmatter Update

    /// Update frontmatter with AI values, preserving only `created`
    private func updateFrontmatter(
        at filePath: String,
        classification: ClassifyResult
    ) -> ProcessedFileResult {
        let fileName = (filePath as NSString).lastPathComponent

        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return ProcessedFileResult(
                fileName: fileName,
                para: classification.para,
                targetPath: filePath,
                tags: classification.tags,
                status: .error("파일 읽기 실패")
            )
        }

        let (existing, body) = Frontmatter.parse(markdown: content)

        // Build new frontmatter — AI values override everything except `created`
        var newFM = Frontmatter(
            para: classification.para,
            tags: classification.tags,
            created: existing.created ?? Frontmatter.today(),
            status: .active,
            summary: classification.summary,
            source: existing.source ?? .import,
            project: classification.project,
            file: existing.file
        )

        // Preserve created from existing
        if let created = existing.created {
            newFM.created = created
        }

        let updatedContent = newFM.stringify() + "\n" + body
        do {
            try updatedContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            return ProcessedFileResult(
                fileName: fileName,
                para: classification.para,
                targetPath: filePath,
                tags: classification.tags,
                status: .error("쓰기 실패: \(error.localizedDescription)")
            )
        }

        return ProcessedFileResult(
            fileName: fileName,
            para: classification.para,
            targetPath: filePath,
            tags: classification.tags
        )
    }

    // MARK: - Content Extraction

    private func extractContent(from filePath: String) -> String {
        if BinaryExtractor.isBinaryFile(filePath) {
            let result = BinaryExtractor.extract(at: filePath)
            return result.text ?? "[바이너리 파일: \(result.file?.name ?? "unknown")]"
        }

        if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
            return String(content.prefix(5000))
        }

        return "[읽기 실패: \((filePath as NSString).lastPathComponent)]"
    }

    // MARK: - Options

    private func generateOptions(for base: ClassifyResult, projectNames: [String]) -> [ClassifyResult] {
        var options: [ClassifyResult] = [base]

        for cat in PARACategory.allCases where cat != base.para {
            options.append(ClassifyResult(
                para: cat,
                tags: base.tags,
                summary: base.summary,
                targetFolder: base.targetFolder,
                project: cat == .project ? projectNames.first : nil,
                confidence: 0.5
            ))
        }

        return options
    }
}
